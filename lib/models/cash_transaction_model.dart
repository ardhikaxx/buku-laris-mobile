import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class CashTransaction {
  final String id;
  final String workspaceId;
  final CashTransactionType type;
  final String category;
  final int amount;
  final DateTime occurredAt;
  final String paymentMethodId;
  final String paymentMethodName;
  final String sourceSaleId;
  final String sourceType;
  final String description;
  final String notes;
  final String createdBy;
  final DateTime? createdAt;

  const CashTransaction({
    this.id = '',
    required this.workspaceId,
    required this.type,
    required this.category,
    required this.amount,
    required this.occurredAt,
    this.paymentMethodId = '',
    this.paymentMethodName = '',
    this.sourceSaleId = '',
    this.sourceType = 'MANUAL',
    this.description = '',
    this.notes = '',
    required this.createdBy,
    this.createdAt,
  });

  factory CashTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CashTransaction(
      id: doc.id,
      workspaceId: str(d['workspaceId']),
      type: enumFromName(
          CashTransactionType.values, d['type'], CashTransactionType.expense),
      category: str(d['category'], 'Lainnya'),
      amount: intOf(d['amount']),
      occurredAt: dtFromTs(d['occurredAt']) ?? dtFromTs(d['createdAt']) ?? DateTime.now(),
      paymentMethodId: str(d['paymentMethodId']),
      paymentMethodName: str(d['paymentMethodName']),
      sourceSaleId: str(d['sourceSaleId']),
      sourceType: str(d['sourceType'], 'MANUAL'),
      description: str(d['description']),
      notes: str(d['notes']),
      createdBy: str(d['createdBy']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap({required DateTime occurredAt}) => {
        'workspaceId': workspaceId,
        'type': type.name,
        'category': category.trim(),
        'amount': amount,
        'occurredAt': Timestamp.fromDate(occurredAt),
        'paymentMethodId': paymentMethodId,
        'paymentMethodName': paymentMethodName,
        'sourceSaleId': sourceSaleId.isEmpty ? null : sourceSaleId,
        'sourceType': sourceType,
        'description': description.trim(),
        'notes': notes.trim(),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap({required DateTime occurredAt}) => {
        'category': category.trim(),
        'amount': amount,
        'occurredAt': Timestamp.fromDate(occurredAt),
        'paymentMethodId': paymentMethodId,
        'paymentMethodName': paymentMethodName,
        'description': description.trim(),
        'notes': notes.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
