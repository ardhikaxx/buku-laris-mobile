import 'package:cloud_firestore/cloud_firestore.dart';

class DailySummary {
  final String id;
  final int revenue;
  final int orderCount;
  final int estimatedProfit;
  final int cashIn;
  final int cashOut;

  const DailySummary({
    required this.id,
    this.revenue = 0,
    this.orderCount = 0,
    this.estimatedProfit = 0,
    this.cashIn = 0,
    this.cashOut = 0,
  });

  factory DailySummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return DailySummary(
      id: doc.id,
      revenue: (d['revenue'] as num?)?.toInt() ?? 0,
      orderCount: (d['orderCount'] as num?)?.toInt() ?? 0,
      estimatedProfit: (d['estimatedProfit'] as num?)?.toInt() ?? 0,
      cashIn: (d['cashIn'] as num?)?.toInt() ?? 0,
      cashOut: (d['cashOut'] as num?)?.toInt() ?? 0,
    );
  }

  static String dayKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$day';
  }

  static Map<String, dynamic> incrementMap({
    required int revenueDelta,
    required int orderDelta,
    required int profitDelta,
    required bool hasUnknownCosts,
  }) =>
      {
        'revenue': FieldValue.increment(revenueDelta),
        'orderCount': FieldValue.increment(orderDelta),
        'estimatedProfit': FieldValue.increment(profitDelta),
        if (hasUnknownCosts) 'hasUnknownCostSales': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static Map<String, dynamic> cashIncrementMap({
    required int cashInDelta,
    required int cashOutDelta,
  }) =>
      {
        'cashIn': FieldValue.increment(cashInDelta),
        'cashOut': FieldValue.increment(cashOutDelta),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
