import '../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enums.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import 'base_repository.dart';

class CategoryRepository extends BaseRepository {
  Stream<List<ProductCategory>> watchAll(String wsId) {
    return sub(wsId, Collections.categories)
        .where('archived', isEqualTo: false)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(ProductCategory.fromDoc).toList());
  }

  Future<List<ProductCategory>> list(String wsId) async {
    final snap = await sub(wsId, Collections.categories)
        .where('archived', isEqualTo: false)
        .orderBy('name')
        .get();
    return snap.docs.map(ProductCategory.fromDoc).toList();
  }

  Future<void> create(String wsId, ProductCategory category) async {
    await sub(wsId, Collections.categories).add(category.toCreateMap());
  }

  Future<void> update(String wsId, ProductCategory category) async {
    await sub(wsId, Collections.categories).doc(category.id).update(category.toUpdateMap());
  }

  Future<bool> archiveIfUnused(String wsId, String categoryId) async {
    final used = await sub(wsId, Collections.products)
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    if (used.docs.isNotEmpty) {
      await sub(wsId, Collections.categories).doc(categoryId).update({
        'archived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return false;
    }
    await sub(wsId, Collections.categories).doc(categoryId).delete();
    return true;
  }
}

class ProductRepository extends BaseRepository {
  Query<Map<String, dynamic>> baseQuery(
    String wsId, {
    bool includeArchived = false,
    ProductType? type,
    String? categoryId,
    bool onlyActiveForSelling = false,
  }) {
    var q = sub(wsId, Collections.products) as Query<Map<String, dynamic>>;
    if (!includeArchived) q = q.where('archived', isEqualTo: false);
    if (onlyActiveForSelling) q = q.where('isActive', isEqualTo: true);
    if (type != null) q = q.where('type', isEqualTo: type.name);
    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.where('categoryId', isEqualTo: categoryId);
    }
    return q;
  }

  Stream<List<Product>> watchAll(
    String wsId, {
    bool includeArchived = false,
    ProductType? type,
    String? categoryId,
    bool onlyActiveForSelling = false,
  }) {
    return sub(wsId, Collections.products).snapshots().map((s) {
      final list = s.docs
          .map(Product.fromDoc)
          .where((p) => includeArchived || !p.archived)
          .toList();
      if (onlyActiveForSelling) {
        list.retainWhere((p) => p.isActive);
      }
      if (type != null) {
        list.retainWhere((p) => p.type == type);
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        list.retainWhere((p) => p.categoryId == categoryId);
      }
      list.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Stream<List<Product>> watchRecent(String wsId, {int limit = 5}) {
    return watchAll(wsId, onlyActiveForSelling: true).map((list) {
      if (list.length > limit) return list.sublist(0, limit);
      return list;
    });
  }

  Future<List<Product>> searchByName(String wsId, String term,
      {int limit = 15}) async {
    final cleanTerm = term.trim().toLowerCase();
    if (cleanTerm.isEmpty) return [];
    try {
      final snap = await sub(wsId, Collections.products).get();
      final results = snap.docs
          .map(Product.fromDoc)
          .where((p) =>
              !p.archived &&
              p.isActive &&
              (p.name.toLowerCase().contains(cleanTerm) ||
                  p.sku.toLowerCase().contains(cleanTerm) ||
                  p.barcode.toLowerCase().contains(cleanTerm)))
          .toList();
      results.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (results.length > limit) return results.sublist(0, limit);
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<List<Product>> searchByBarcodeOrSku(String wsId, String code) async {
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty) return [];
    try {
      final snap = await sub(wsId, Collections.products).get();
      final results = snap.docs
          .map(Product.fromDoc)
          .where((p) =>
              !p.archived &&
              (p.sku.toLowerCase() == clean ||
                  p.barcode.toLowerCase() == clean))
          .toList();
      return results;
    } catch (_) {
      return [];
    }
  }

  Stream<Product?> watchById(String wsId, String productId) {
    return sub(wsId, Collections.products)
        .doc(productId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Product.fromDoc(doc);
    });
  }

  Future<Product?> getById(String wsId, String productId) async {
    final doc = await sub(wsId, Collections.products).doc(productId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Product.fromDoc(doc);
  }

  Future<DocumentReference<Map<String, dynamic>>> create(
      String wsId, Product product) async {
    return await sub(wsId, Collections.products).add(product.toCreateMap());
  }

  Future<void> update(String wsId, Product product,
      {required bool hadInitialStock}) async {
    await sub(wsId, Collections.products)
        .doc(product.id)
        .update(product.toUpdateMap(hadInitialStock: hadInitialStock));
  }

  Future<void> setActive(String wsId, String productId, bool active) async {
    await sub(wsId, Collections.products).doc(productId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archive(String wsId, String productId) async {
    await sub(wsId, Collections.products).doc(productId).update({
      'archived': true,
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePermanently(String wsId, Product product) async {
    final usedInSales = await sub(wsId, Collections.sales)
        .where('items.productId', isEqualTo: product.id)
        .limit(1)
        .get();
    final hasMovements = await sub(wsId, Collections.stockMovements)
        .where('productId', isEqualTo: product.id)
        .limit(1)
        .get();
    if (usedInSales.docs.isNotEmpty || hasMovements.docs.isNotEmpty) {
      throw RepoException(
        '${product.name} sudah pernah digunakan dalam transaksi sehingga tidak dapat dihapus permanen. Gunakan arsip agar histori laporan tetap aman.',
      );
    }
    await sub(wsId, Collections.products).doc(product.id).delete();
  }

  Stream<int> countLowStock(String wsId) {
    return watchAll(wsId, onlyActiveForSelling: true).map((products) => products
        .where((p) =>
            p.type.tracksStock &&
            p.trackStock &&
            !p.unlimitedStock &&
            p.stock <= p.minStock)
        .length);
  }

  Future<List<Product>> listLowStock(String wsId, {int limit = 20}) async {
    final all = await listAll(wsId);
    final filtered = all
        .where((p) =>
            p.type.tracksStock &&
            p.trackStock &&
            !p.unlimitedStock &&
            p.stock <= p.minStock &&
            p.availableForSale)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    if (filtered.length > limit) return filtered.sublist(0, limit);
    return filtered;
  }

  Future<List<Product>> listAll(String wsId, {int limit = 500}) async {
    try {
      final snap = await sub(wsId, Collections.products).get();
      final list = snap.docs
          .map(Product.fromDoc)
          .where((p) => !p.archived)
          .toList();
      list.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (list.length > limit) return list.sublist(0, limit);
      return list;
    } catch (e) {
      return [];
    }
  }
}
