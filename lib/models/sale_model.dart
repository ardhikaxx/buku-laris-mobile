import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class SaleItem {
  final String productId;
  final String productName;
  final ProductType type;
  final String categoryId;
  final String categoryName;
  final int qty;
  final String unit;
  final int unitPrice;
  final int? costPrice;
  final int itemDiscount;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.type,
    this.categoryId = '',
    this.categoryName = '',
    required this.qty,
    this.unit = 'pcs',
    required this.unitPrice,
    this.costPrice,
    this.itemDiscount = 0,
  });

  int get lineTotal => (unitPrice * qty) - itemDiscount;

  int get lineCost => (costPrice ?? 0) * qty;

  bool get hasKnownCost => costPrice != null;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'qty': qty,
        'unit': unit,
        'unitPrice': unitPrice,
        'costPrice': costPrice,
        'itemDiscount': itemDiscount,
      };

  factory SaleItem.fromMap(dynamic raw) {
    final m = mapOf(raw);
    return SaleItem(
      productId: str(m['productId']),
      productName: str(m['productName']),
      type: enumFromName(ProductType.values, m['type'], ProductType.physicalProduct),
      categoryId: str(m['categoryId']),
      categoryName: str(m['categoryName']),
      qty: intOf(m['qty'], 1),
      unit: str(m['unit'], 'pcs'),
      unitPrice: intOf(m['unitPrice']),
      costPrice: m['costPrice'] == null ? null : intOf(m['costPrice']),
      itemDiscount: intOf(m['itemDiscount']),
    );
  }
}

class SaleStatusEvent {
  final SaleStatus status;
  final DateTime at;
  final String byUserId;
  final String note;

  const SaleStatusEvent({
    required this.status,
    required this.at,
    required this.byUserId,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'at': Timestamp.fromDate(at),
        'byUserId': byUserId,
        'note': note,
      };

  factory SaleStatusEvent.fromMap(dynamic raw) {
    final m = mapOf(raw);
    return SaleStatusEvent(
      status: enumFromName(SaleStatus.values, m['status'], SaleStatus.pending),
      at: dtFromTs(m['at']) ?? DateTime.now(),
      byUserId: str(m['byUserId']),
      note: str(m['note']),
    );
  }
}

enum TransactionType { SALE, RETUR }

class Sale {
  final String id;
  final String workspaceId;
  final String transactionNumber;
  final String sellerId;
  final String sellerName;
  final String? customerId;
  final String customerName;
  final String customerWhatsapp;
  final TransactionType transactionType;
  final OrderType orderType;
  final List<SaleItem> items;
  final int subtotal;
  final int discountAmount;
  final double taxPercent;
  final int taxAmount;
  final int shippingCost;
  final int grandTotal;
  final int paidAmount;
  final int remainingAmount;
  final String paymentMethodId;
  final String paymentMethodName;
  final PaymentStatus paymentStatus;
  final SaleStatus status;
  final bool countsRevenue;
  final DateTime? estimatedCompletionDate;
  final String notes;
  final List<SaleStatusEvent> statusHistory;
  final bool stockDeducted;
  final bool offlineCreated;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const Sale({
    required this.id,
    required this.workspaceId,
    required this.transactionNumber,
    required this.sellerId,
    this.sellerName = '',
    this.customerId,
    this.customerName = '',
    this.customerWhatsapp = '',
    this.transactionType = TransactionType.SALE,
    required this.orderType,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0,
    this.taxPercent = 0,
    this.taxAmount = 0,
    this.shippingCost = 0,
    required this.grandTotal,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.paymentMethodId = '',
    this.paymentMethodName = '',
    this.paymentStatus = PaymentStatus.unpaid,
    this.status = SaleStatus.completed,
    this.countsRevenue = true,
    this.estimatedCompletionDate,
    this.notes = '',
    this.statusHistory = const [],
    this.stockDeducted = false,
    this.offlineCreated = false,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory Sale.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final items =
        (d['items'] as List? ?? []).map(SaleItem.fromMap).toList();
    final history = (d['statusHistory'] as List? ?? [])
        .map(SaleStatusEvent.fromMap)
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final grandTotal = intOf(d['grandTotal']);
    final paid = intOf(d['paidAmount']);
    final status =
        enumFromName(SaleStatus.values, d['status'], SaleStatus.pending);
    return Sale(
      id: doc.id,
      workspaceId: str(d['workspaceId']),
      transactionNumber: str(d['transactionNumber']),
      sellerId: str(d['sellerId']),
      sellerName: str(d['sellerName']),
      customerId: strOrNull(d['customerId']),
      customerName: str(d['customerName']),
      customerWhatsapp: str(d['customerWhatsapp']),
      transactionType: str(d['transactionType']) == 'RETUR'
          ? TransactionType.RETUR
          : TransactionType.SALE,
      orderType:
          enumFromName(OrderType.values, d['orderType'], OrderType.readyStock),
      items: items,
      subtotal: intOf(d['subtotal']),
      discountAmount: intOf(d['discountAmount']),
      taxPercent: doubleOf(d['taxPercent']),
      taxAmount: intOf(d['taxAmount']),
      shippingCost: intOf(d['shippingCost']),
      grandTotal: grandTotal,
      paidAmount: paid,
      remainingAmount: d['remainingAmount'] == null
          ? (grandTotal - paid)
          : intOf(d['remainingAmount']),
      paymentMethodId: str(d['paymentMethodId']),
      paymentMethodName: str(d['paymentMethodName']),
      paymentStatus: enumFromName(
          PaymentStatus.values, d['paymentStatus'], PaymentStatus.unpaid),
      status: status,
      countsRevenue: d['countsRevenue'] == null
          ? status.countsRevenue
          : boolOf(d['countsRevenue']),
      estimatedCompletionDate: dtFromTs(d['estimatedCompletionDate']),
      notes: str(d['notes']),
      statusHistory: history,
      stockDeducted: boolOf(d['stockDeducted']),
      offlineCreated: boolOf(d['offlineCreated']),
      createdAt: dtFromTs(d['createdAt']),
      updatedAt: dtFromTs(d['updatedAt']),
      completedAt: dtFromTs(d['completedAt']),
      cancelledAt: dtFromTs(d['cancelledAt']),
    );
  }

  bool get hasUnknownCosts => items.any((i) => !i.hasKnownCost);

  int get totalCost => items.fold(0, (sum, i) => sum + i.lineCost);

  int get estimatedProfit =>
      subtotal - discountAmount - totalCost - taxAmount - shippingCost;

  bool get isPreOrder => orderType == OrderType.preOrder;
}
