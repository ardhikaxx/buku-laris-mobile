import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class ProductCategory {
  final String id;
  final String name;
  final String description;
  final String? parentId;
  final ProductType? productType;
  final bool archived;
  final DateTime? createdAt;

  const ProductCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.parentId,
    this.productType,
    this.archived = false,
    this.createdAt,
  });

  factory ProductCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ProductCategory(
      id: doc.id,
      name: str(d['name']),
      description: str(d['description']),
      parentId: strOrNull(d['parentId']),
      productType: d['productType'] == null
          ? null
          : enumFromName(ProductType.values, d['productType'], ProductType.physicalProduct),
      archived: boolOf(d['archived']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name.trim(),
        'description': description,
        'parentId': parentId,
        'productType': productType?.name,
        'archived': archived,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name.trim(),
        'description': description,
        'parentId': parentId,
        'productType': productType?.name,
        'archived': archived,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
