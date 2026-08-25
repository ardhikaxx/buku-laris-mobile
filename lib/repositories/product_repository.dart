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

  Stream<List<Product>> watchRecent(String wsId, {int limit = 5}) {
    return baseQuery(wsId, onlyActiveForSelling: true)
        .orderBy('name')
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Product.fromDoc).toList());
  }

  Future<List<Product>> searchByName(String wsId, String term, {int limit = 10}) async {
    final cleanTerm = term.trim();
    if (cleanTerm.isEmpty) return [];
    var q = baseQuery(wsId, onlyActiveForSelling: true).orderBy('name');
    q = q.where('name', isGreaterThanOrEqualTo: cleanTerm);
    q = q.where('name', isLessThanOrEqualTo: '$cleanTerm\uf8ff');
    final snap = await q.limit(limit).get();
    return snap.docs.map(Product.fromDoc).toList();
  }

  Future<List<Product>> searchByBarcodeOrSku(String wsId, String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return [];
    final results = <Product>[];
    final skuSnap = await sub(wsId, Collections.products)
        .where('sku', isEqualTo: clean)
        .limit(3)
        .get();
    results.addAll(skuSnap.docs.map(Product.fromDoc));
    if (results.isEmpty) {
      final barcodeSnap = await sub(wsId, Collections.products)
          .where('barcode', isEqualTo: clean)
          .limit(3)
          .get();
      results.addAll(barcodeSnap.docs.map(Product.fromDoc));
    }
    return results;
  }

  Stream<Product?> watchById(String wsId, String productId) {
    return sub(wsId, Collections.products).doc(productId).snapshots().map((doc) {
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
    return baseQuery(wsId, onlyActiveForSelling: true)
        .where('type', isEqualTo: ProductType.physicalProduct.name)
        .where('trackStock', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map(Product.fromDoc)
            .where((p) => !p.unlimitedStock && p.stock <= p.minStock)
            .length);
  }

  Future<List<Product>> listLowStock(String wsId, {int limit = 20}) async {
    final snap = await baseQuery(wsId, onlyActiveForSelling: true)
        .where('type', isEqualTo: ProductType.physicalProduct.name)
        .where('trackStock', isEqualTo: true)
        .orderBy('stock')
        .limit(limit * 2)
        .get();
    return snap.docs
        .map(Product.fromDoc)
        .where((p) => !p.unlimitedStock && p.stock <= p.minStock)
        .take(limit)
        .toList();
  }

  Future<List<Product>> listAll(String wsId, {int limit = 500}) async {
    final snap = await baseQuery(wsId).orderBy('name').limit(limit).get();
    return snap.docs.map(Product.fromDoc).toList();
  }
}
