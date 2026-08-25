import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_helpers.dart';

class PaymentMethodModel {
  final String id;
  final String name;
  final String type;
  final bool isActive;
  final int sortOrder;
  final String details;
  final DateTime? createdAt;

  const PaymentMethodModel({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = true,
    this.sortOrder = 0,
    this.details = '',
    this.createdAt,
  });

  factory PaymentMethodModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PaymentMethodModel(
      id: doc.id,
      name: str(d['name']),
      type: str(d['type'], 'OTHER'),
      isActive: d['isActive'] == null ? true : boolOf(d['isActive'], true),
      sortOrder: intOf(d['sortOrder']),
      details: str(d['details']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool isCreate = false}) => {
        'name': name.trim(),
        'type': type,
        'isActive': isActive,
        'sortOrder': sortOrder,
        'details': details.trim(),
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class DefaultPaymentMethods {
  DefaultPaymentMethods._();

  static List<PaymentMethodModel> defaults() => [
        const PaymentMethodModel(id: '', name: 'Tunai', type: 'CASH', sortOrder: 0),
        const PaymentMethodModel(id: '', name: 'Transfer Bank', type: 'BANK_TRANSFER', sortOrder: 1),
        const PaymentMethodModel(id: '', name: 'QRIS', type: 'QRIS', sortOrder: 2),
        const PaymentMethodModel(id: '', name: 'E-Wallet', type: 'EWALLET', sortOrder: 3),
      ];
}
