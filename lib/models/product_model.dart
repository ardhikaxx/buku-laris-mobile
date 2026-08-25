import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class Product {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String categoryId;
  final ProductType type;
  final int? costPrice;
  final int sellingPrice;
  final String unit;
  final bool trackStock;
  final bool unlimitedStock;
  final int stock;
  final int minStock;
  final int? licenseCount;
  final String? imageUrl;
  final String description;
  final bool isActive;
  final bool archived;
  final int soldCount;
  final DateTime? lastSoldAt;
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.categoryId = '',
    this.type = ProductType.physicalProduct,
    this.costPrice,
    this.sellingPrice = 0,
    this.unit = 'pcs',
    this.trackStock = true,
    this.unlimitedStock = false,
    this.stock = 0,
    this.minStock = 0,
    this.licenseCount,
    this.imageUrl,
    this.description = '',
    this.isActive = true,
    this.archived = false,
    this.soldCount = 0,
    this.lastSoldAt,
    this.createdAt,
  });

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Product(
      id: doc.id,
      name: str(d['name'], 'Produk'),
      sku: str(d['sku']),
      barcode: str(d['barcode']),
      categoryId: str(d['categoryId']),
      type: enumFromName(ProductType.values, d['type'], ProductType.physicalProduct),
      costPrice: d['costPrice'] == null ? null : intOf(d['costPrice']),
      sellingPrice: intOf(d['sellingPrice']),
      unit: str(d['unit'], 'pcs'),
      trackStock: d['trackStock'] == null
          ? true
          : boolOf(d['trackStock'], true),
      unlimitedStock: boolOf(d['unlimitedStock']),
      stock: intOf(d['stock']),
      minStock: intOf(d['minStock']),
      licenseCount: d['licenseCount'] == null ? null : intOf(d['licenseCount']),
      imageUrl: strOrNull(d['imageUrl']),
      description: str(d['description']),
      isActive: d['isActive'] == null ? true : boolOf(d['isActive'], true),
      archived: boolOf(d['archived']),
      soldCount: intOf(d['soldCount']),
      lastSoldAt: dtFromTs(d['lastSoldAt']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  bool get isLowStock =>
      type == ProductType.physicalProduct &&
      trackStock &&
      !unlimitedStock &&
      stock <= minStock;

  bool get availableForSale => isActive && !archived;

  bool canSell(int qty, {bool allowOverselling = false}) {
    if (!type.tracksStock || !trackStock || unlimitedStock) return true;
    if (licenseCount != null && type == ProductType.digitalProduct) {
      return allowOverselling || licenseCount! >= qty;
    }
    return allowOverselling || stock >= qty;
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name.trim(),
        'sku': sku.trim(),
        'barcode': barcode.trim(),
        'categoryId': categoryId,
        'type': type.name,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
        'trackStock': type.tracksStock ? trackStock : false,
        'unlimitedStock':
            type == ProductType.digitalProduct ? unlimitedStock : false,
        'stock': type.tracksStock && trackStock ? stock : 0,
        'minStock': minStock,
        'licenseCount': licenseCount,
        'imageUrl': imageUrl,
        'description': description,
        'isActive': isActive,
        'archived': archived,
        'soldCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap({required bool hadInitialStock}) => {
        'name': name.trim(),
        'sku': sku.trim(),
        'barcode': barcode.trim(),
        'categoryId': categoryId,
        'type': type.name,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
        if (type.tracksStock && hadInitialStock) 'trackStock': trackStock,
        if (type == ProductType.digitalProduct) 'unlimitedStock': unlimitedStock,
        'minStock': minStock,
        'licenseCount': licenseCount,
        'imageUrl': imageUrl,
        'description': description,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
