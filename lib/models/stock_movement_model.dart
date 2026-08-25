import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class StockMovement {
  final String id;
  final String productId;
  final String productName;
  final StockReason reason;
  final int qtyChange;
  final int stockBefore;
  final int stockAfter;
  final String note;
  final String? relatedSaleId;
  final String createdBy;
  final DateTime? createdAt;

  const StockMovement({
    this.id = '',
    required this.productId,
    required this.productName,
    required this.reason,
    required this.qtyChange,
    required this.stockBefore,
    required this.stockAfter,
    this.note = '',
    this.relatedSaleId,
    required this.createdBy,
    this.createdAt,
  });

  factory StockMovement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return StockMovement(
      id: doc.id,
      productId: str(d['productId']),
      productName: str(d['productName']),
      reason: enumFromName(StockReason.values, d['reason'], StockReason.manualCorrection),
      qtyChange: intOf(d['qtyChange']),
      stockBefore: intOf(d['stockBefore']),
      stockAfter: intOf(d['stockAfter']),
      note: str(d['note']),
      relatedSaleId: strOrNull(d['relatedSaleId']),
      createdBy: str(d['createdBy']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  StockDirection get direction => StockDirectionX.fromReason(reason);

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'reason': reason.name,
        'direction': direction.name,
        'qtyChange': qtyChange,
        'stockBefore': stockBefore,
        'stockAfter': stockAfter,
        'note': note,
        'relatedSaleId': relatedSaleId,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
