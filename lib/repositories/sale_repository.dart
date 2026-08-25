import '../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cash_transaction_model.dart';
import '../models/daily_summary_model.dart';
import '../models/enums.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import 'audit_notification_repository.dart';
import 'base_repository.dart';

class SaleDraft {
  final OrderType orderType;
  final List<SaleItem> items;
  final int discountAmount;
  final int shippingCost;
  final double taxPercent;
  final String? customerId;
  final String customerName;
  final String customerWhatsapp;
  final String paymentMethodId;
  final String paymentMethodName;
  final int paidAmount;
  final String notes;
  final DateTime? estimatedCompletionDate;

  const SaleDraft({
    required this.orderType,
    required this.items,
    this.discountAmount = 0,
    this.shippingCost = 0,
    this.taxPercent = 0,
    this.customerId,
    this.customerName = '',
    this.customerWhatsapp = '',
    this.paymentMethodId = '',
    this.paymentMethodName = '',
    this.paidAmount = 0,
    this.notes = '',
    this.estimatedCompletionDate,
  });

  int get subtotal => items.fold(0, (s, i) => s + i.lineTotal);

  int get taxAmount =>
      ((subtotal - discountAmount) * taxPercent / 100).round();

  int get grandTotal =>
      subtotal - discountAmount + taxAmount + shippingCost;
}

class CreateSaleResult {
  final String saleId;
  final String transactionNumber;
  final bool savedOffline;

  const CreateSaleResult({
    required this.saleId,
    required this.transactionNumber,
    required this.savedOffline,
  });
}

enum SaleStatusChangeResult { success, invalidTransition }

class SaleRepository extends BaseRepository {
  static const Map<SaleStatus, Set<SaleStatus>> _transitions = {
    SaleStatus.draft: {
      SaleStatus.pending,
      SaleStatus.confirmed,
      SaleStatus.cancelled
    },
    SaleStatus.pending: {
      SaleStatus.confirmed,
      SaleStatus.processing,
      SaleStatus.cancelled
    },
    SaleStatus.confirmed: {
      SaleStatus.processing,
      SaleStatus.ready,
      SaleStatus.cancelled
    },
    SaleStatus.processing: {
      SaleStatus.ready,
      SaleStatus.completed,
      SaleStatus.cancelled
    },
    SaleStatus.ready: {SaleStatus.completed, SaleStatus.cancelled},
    SaleStatus.completed: {SaleStatus.refunded},
    SaleStatus.cancelled: {},
    SaleStatus.refunded: {},
  };

  final AuditRepository _audit = AuditRepository();

  Future<CreateSaleResult> createSale({
    required String wsId,
    required String workspaceName,
    required SaleDraft draft,
    required String sellerId,
    required String sellerName,
    required WorkspaceSettingsSnapshot settings,
    required bool allowOverselling,
    required bool requireEstimatedDateForPreorder,
  }) async {
    if (draft.items.isEmpty) {
      throw RepoException('Transaksi harus memiliki minimal satu item.');
    }
    if (draft.orderType == OrderType.preOrder &&
        requireEstimatedDateForPreorder &&
        draft.estimatedCompletionDate == null) {
      throw RepoException(
          'Estimasi tanggal selesai wajib diisi untuk pre-order.');
    }
    if (draft.paidAmount > draft.grandTotal) {
      throw RepoException('Jumlah bayar tidak boleh melebihi total tagihan.');
    }

    try {
      return await fs.runTransaction<CreateSaleResult>((txn) async {
        final counterRef = sub(wsId, Collections.counters).doc('sales');
        final counterSnap = await txn.get(counterRef);
        var seq = ((counterSnap.data()?['seq'] ?? 0) as num).toInt();
        seq += 1;

        final saleRef = sub(wsId, Collections.sales).doc();
        final now = DateTime.now();
        final number =
            'TRX-${DailySummary.dayKey(now).replaceAll('-', '')}-${seq.toString().padLeft(4, '0')}';

        final initialStatus = draft.orderType == OrderType.readyStock
            ? SaleStatus.completed
            : SaleStatus.pending;
        final countsRevenue = initialStatus.countsRevenue;

        await _mutateStockForItems(
          txn,
          wsId,
          draft.items,
          direction: -1,
          reason: draft.orderType == OrderType.readyStock
              ? StockReason.sale
              : StockReason.preorderFulfillment,
          relatedSaleId: saleRef.id,
          actorId: sellerId,
          allowNegative: allowOverselling || settings.allowOverselling,
          skipIfPreorderPending: draft.orderType == OrderType.preOrder,
        );

        if (draft.customerId != null && draft.customerId!.isNotEmpty) {
          await _applyCustomerStats(txn, wsId, draft.customerId!,
              spentDelta: countsRevenue ? draft.grandTotal : 0,
              countDelta: countsRevenue ? 1 : 0);
        }

        if (draft.paidAmount > 0) {
          final cashRef = sub(wsId, Collections.cashTransactions).doc();
          txn.set(
            cashRef,
            CashTransaction(
              workspaceId: wsId,
              type: CashTransactionType.income,
              category: _incomeCategory(draft),
              amount: draft.paidAmount,
              occurredAt: now,
              paymentMethodId: draft.paymentMethodId,
              paymentMethodName: draft.paymentMethodName,
              sourceSaleId: saleRef.id,
              sourceType: 'SALE',
              description:
                  'Pembayaran $number${draft.customerName.isEmpty ? '' : ' - ${draft.customerName}'}',
              createdBy: sellerId,
            ).toCreateMap(occurredAt: now),
          );
          txn.set(
            sub(wsId, Collections.dailySummaries)
                .doc(DailySummary.dayKey(now)),
            DailySummary.cashIncrementMap(cashInDelta: draft.paidAmount, cashOutDelta: 0),
            SetOptions(merge: true),
          );
        }

        if (countsRevenue) {
          txn.set(
            sub(wsId, Collections.dailySummaries).doc(DailySummary.dayKey(now)),
            DailySummary.incrementMap(
              revenueDelta: draft.grandTotal,
              orderDelta: 1,
              profitDelta: _estimateProfit(draft),
              hasUnknownCosts: draft.items.any((i) => !i.hasKnownCost),
            ),
            SetOptions(merge: true),
          );
        }

        final sale = _buildSale(
          wsId: wsId,
          saleId: saleRef.id,
          transactionNumber: number,
          draft: draft,
          sellerId: sellerId,
          sellerName: sellerName,
          status: initialStatus,
          countsRevenue: countsRevenue,
          offlineCreated: false,
          createdAtLocal: now,
        );

        txn.update(counterRef, {'seq': seq});
        txn.set(saleRef, _saleToMap(sale, isCreate: true));

        _audit.log(
          workspaceId: wsId,
          actorId: sellerId,
          actorName: sellerName,
          action: draft.orderType == OrderType.preOrder
              ? 'sale.preorder_created'
              : 'sale.created',
          entityType: 'sale',
          entityId: saleRef.id,
          metadata: {'transactionNumber': number, 'grandTotal': draft.grandTotal},
        );

        return CreateSaleResult(
          saleId: saleRef.id,
          transactionNumber: number,
          savedOffline: false,
        );
      });
    } on FirebaseException catch (e) {
      if (_isNetworkError(e)) {
        return await _saveOfflineFallback(wsId, draft, sellerId, sellerName);
      }
      rethrow;
    } catch (e) {
      if (_isGenericNetworkError(e)) {
        return await _saveOfflineFallback(wsId, draft, sellerId, sellerName);
      }
      rethrow;
    }
  }

  Future<CreateSaleResult> _saveOfflineFallback(String wsId, SaleDraft draft,
      String sellerId, String sellerName) async {
    final saleRef = sub(wsId, Collections.sales).doc();
    final sale = _buildSale(
      wsId: wsId,
      saleId: saleRef.id,
      transactionNumber:
          'OFFLINE-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      draft: draft,
      sellerId: sellerId,
      sellerName: sellerName,
      status: SaleStatus.draft,
      countsRevenue: false,
      offlineCreated: true,
      createdAtLocal: DateTime.now(),
    );
    await saleRef.set(_saleToMap(sale, isCreate: true));
    return CreateSaleResult(
      saleId: saleRef.id,
      transactionNumber: sale.transactionNumber,
      savedOffline: true,
    );
  }

  Future<void> finalizeOfflineSale({
    required String wsId,
    required Sale sale,
    required bool allowOverselling,
    required String actorId,
  }) async {
    if (!sale.offlineCreated) return;
    await fs.runTransaction((txn) async {
      final ref = sub(wsId, Collections.sales).doc(sale.id);
      final fresh = await txn.get(ref);
      if (!fresh.exists) throw RepoException('Transaksi tidak ditemukan.');
      if (!(fresh.data()?['offlineCreated'] ?? false)) {
        throw RepoException('Transaksi ini sudah diproses sebelumnya.');
      }

      await _mutateStockForItems(
        txn,
        wsId,
        sale.items,
        direction: -1,
        reason: StockReason.manualCorrection,
        relatedSaleId: sale.id,
        actorId: actorId,
        allowNegative: allowOverselling,
        skipIfPreorderPending: false,
        notePrefix: 'Finalisasi transaksi offline ',
      );

      txn.set(
        sub(wsId, Collections.dailySummaries)
            .doc(DailySummary.dayKey(DateTime.now())),
        DailySummary.incrementMap(
          revenueDelta: sale.grandTotal,
          orderDelta: 1,
          profitDelta: sale.estimatedProfit,
          hasUnknownCosts: sale.hasUnknownCosts,
        ),
        SetOptions(merge: true),
      );

      if (sale.customerId != null && sale.customerId!.isNotEmpty) {
        await _applyCustomerStats(txn, wsId, sale.customerId!,
            spentDelta: sale.grandTotal, countDelta: 1);
      }

      txn.update(ref, {
        'offlineCreated': false,
        'status': SaleStatus.completed.name,
        'countsRevenue': true,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<SaleStatusChangeResult> changeStatus({
    required String wsId,
    required Sale sale,
    required SaleStatus newStatus,
    required String actorId,
    required String actorName,
    required bool deductOnConfirm,
    String note = '',
    required bool allowOverselling,
  }) async {
    final allowed = _transitions[sale.status] ?? {};
    if (!allowed.contains(newStatus)) {
      throw RepoException(
          'Perubahan status dari "${sale.status.label}" ke "${newStatus.label}" tidak diizinkan.');
    }

    await fs.runTransaction((txn) async {
      final ref = sub(wsId, Collections.sales).doc(sale.id);
      final updates = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final historyEvent = SaleStatusEvent(
        status: newStatus,
        at: DateTime.now(),
        byUserId: actorId,
        note: note,
      );
      updates['statusHistory'] = FieldValue.arrayUnion([historyEvent.toMap()]);

      final willDeductStock = sale.orderType == OrderType.preOrder &&
          !sale.stockDeducted &&
          (newStatus == SaleStatus.processing ||
              (newStatus == SaleStatus.confirmed && deductOnConfirm));

      if (willDeductStock) {
        await _mutateStockForItems(txn, wsId, sale.items,
            direction: -1,
            reason: StockReason.preorderFulfillment,
            relatedSaleId: sale.id,
            actorId: actorId,
            allowNegative: allowOverselling,
            skipIfPreorderPending: false);
        updates['stockDeducted'] = true;
      }

      if (newStatus == SaleStatus.completed) {
        if (sale.orderType == OrderType.preOrder && !sale.stockDeducted && !willDeductStock) {
          await _mutateStockForItems(txn, wsId, sale.items,
              direction: -1,
              reason: StockReason.preorderFulfillment,
              relatedSaleId: sale.id,
              actorId: actorId,
              allowNegative: allowOverselling,
              skipIfPreorderPending: false);
          updates['stockDeducted'] = true;
        }
        updates['countsRevenue'] = true;
        updates['completedAt'] = FieldValue.serverTimestamp();

        txn.set(
          sub(wsId, Collections.dailySummaries)
              .doc(DailySummary.dayKey(DateTime.now())),
          DailySummary.incrementMap(
            revenueDelta: sale.grandTotal,
            orderDelta: 1,
            profitDelta: sale.hasUnknownCosts
                ? (sale.subtotal -
                    sale.discountAmount -
                    sale.taxAmount -
                    sale.shippingCost -
                    sale.totalCost)
                : sale.estimatedProfit,
            hasUnknownCosts: sale.hasUnknownCosts,
          ),
          SetOptions(merge: true),
        );

        if (sale.customerId != null && sale.customerId!.isNotEmpty) {
          await _applyCustomerStats(txn, wsId, sale.customerId!,
              spentDelta: sale.grandTotal, countDelta: 1);
        }
      }

      final restoresStock = (newStatus == SaleStatus.cancelled ||
              newStatus == SaleStatus.refunded) &&
          sale.stockDeducted;
      if (restoresStock) {
        await _mutateStockForItems(txn, wsId, sale.items,
            direction: 1,
            reason: newStatus == SaleStatus.cancelled
                ? StockReason.saleCancelled
                : StockReason.manualCorrection,
            relatedSaleId: sale.id,
            actorId: actorId,
            allowNegative: true,
            skipIfPreorderPending: false);
        updates['stockDeducted'] = false;
      }

      if (newStatus == SaleStatus.cancelled && sale.countsRevenue) {
        txn.set(
          sub(wsId, Collections.dailySummaries)
              .doc(DailySummary.dayKey(sale.createdAt ?? DateTime.now())),
          DailySummary.incrementMap(
            revenueDelta: -sale.grandTotal,
            orderDelta: -1,
            profitDelta: -sale.estimatedProfit,
            hasUnknownCosts: sale.hasUnknownCosts,
          ),
          SetOptions(merge: true),
        );
        if (sale.customerId != null && sale.customerId!.isNotEmpty) {
          await _applyCustomerStats(txn, wsId, sale.customerId!,
              spentDelta: -sale.grandTotal, countDelta: -1);
        }
        updates['countsRevenue'] = false;
        updates['cancelledAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == SaleStatus.cancelled && sale.paidAmount > 0) {
        txn.set(
          sub(wsId, Collections.cashTransactions).doc(),
          CashTransaction(
            workspaceId: wsId,
            type: CashTransactionType.expense,
            category: 'Biaya Lainnya',
            amount: sale.paidAmount,
            occurredAt: DateTime.now(),
            paymentMethodName: sale.paymentMethodName,
            sourceSaleId: sale.id,
            sourceType: 'REFUND',
            description: 'Pengembalian dana ${sale.transactionNumber}',
            createdBy: actorId,
          ).toCreateMap(occurredAt: DateTime.now()),
        );
        txn.set(
          sub(wsId, Collections.dailySummaries)
              .doc(DailySummary.dayKey(DateTime.now())),
          DailySummary.cashIncrementMap(cashInDelta: 0, cashOutDelta: sale.paidAmount),
          SetOptions(merge: true),
        );
      }

      if (newStatus == SaleStatus.refunded) {
        txn.set(
          sub(wsId, Collections.dailySummaries)
              .doc(DailySummary.dayKey(sale.createdAt ?? DateTime.now())),
          DailySummary.incrementMap(
            revenueDelta: -sale.grandTotal,
            orderDelta: -1,
            profitDelta: -sale.estimatedProfit,
            hasUnknownCosts: sale.hasUnknownCosts,
          ),
          SetOptions(merge: true),
        );
        if (sale.customerId != null && sale.customerId!.isNotEmpty) {
          await _applyCustomerStats(txn, wsId, sale.customerId!,
              spentDelta: -sale.grandTotal, countDelta: -1);
        }
        updates['paymentStatus'] = PaymentStatus.refunded.name;
        updates['countsRevenue'] = false;
        if (sale.paidAmount > 0) {
          txn.set(
            sub(wsId, Collections.cashTransactions).doc(),
            CashTransaction(
              workspaceId: wsId,
              type: CashTransactionType.expense,
              category: 'Biaya Lainnya',
              amount: sale.paidAmount,
              occurredAt: DateTime.now(),
              sourceSaleId: sale.id,
              sourceType: 'REFUND',
              description: 'Refund ${sale.transactionNumber}',
              createdBy: actorId,
            ).toCreateMap(occurredAt: DateTime.now()),
          );
          txn.set(
            sub(wsId, Collections.dailySummaries)
                .doc(DailySummary.dayKey(DateTime.now())),
            DailySummary.cashIncrementMap(cashInDelta: 0, cashOutDelta: sale.paidAmount),
            SetOptions(merge: true),
          );
        }
      }

      txn.update(ref, updates);
    });

    _audit.log(
      workspaceId: wsId,
      actorId: actorId,
      actorName: actorName,
      action: 'sale.status_changed',
      entityType: 'sale',
      entityId: sale.id,
      metadata: {
        'transactionNumber': sale.transactionNumber,
        'from': sale.status.name,
        'to': newStatus.name,
      },
    );
    return SaleStatusChangeResult.success;
  }

  Future<void> addPayment({
    required String wsId,
    required Sale sale,
    required int amount,
    required String actorId,
    required String actorName,
    String? paymentMethodId,
    String? paymentMethodName,
  }) async {
    if (amount <= 0) {
      throw RepoException('Nominal pembayaran harus lebih dari 0.');
    }
    if (amount > sale.remainingAmount) {
      throw RepoException(
          'Nominal melebihi sisa tagihan (${sale.remainingAmount}).');
    }
    final now = DateTime.now();
    final methodId = paymentMethodId ?? sale.paymentMethodId;
    final methodName = paymentMethodName ?? sale.paymentMethodName;

    await fs.runTransaction((txn) async {
      final ref = sub(wsId, Collections.sales).doc(sale.id);
      final newPaid = sale.paidAmount + amount;
      final remaining = sale.grandTotal - newPaid;
      final status =
          remaining <= 0 ? PaymentStatus.paid : PaymentStatus.partial;

      txn.update(ref, {
        'paidAmount': newPaid,
        'remainingAmount': remaining,
        'paymentStatus': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.set(
        sub(wsId, Collections.cashTransactions).doc(),
        CashTransaction(
          workspaceId: wsId,
          type: CashTransactionType.income,
          category: sale.paymentStatus == PaymentStatus.unpaid
              ? (sale.isPreOrder && sale.status != SaleStatus.completed
                  ? 'Pembayaran DP'
                  : 'Penjualan')
              : 'Pelunasan Piutang',
          amount: amount,
          occurredAt: now,
          paymentMethodId: methodId,
          paymentMethodName: methodName,
          sourceSaleId: sale.id,
          sourceType: 'PAYMENT',
          description: 'Pembayaran ${sale.transactionNumber}',
          createdBy: actorId,
        ).toCreateMap(occurredAt: now),
      );

      txn.set(
        sub(wsId, Collections.dailySummaries).doc(DailySummary.dayKey(now)),
        DailySummary.cashIncrementMap(cashInDelta: amount, cashOutDelta: 0),
        SetOptions(merge: true),
      );
    });

    _audit.log(
      workspaceId: wsId,
      actorId: actorId,
      actorName: actorName,
      action: 'sale.payment_recorded',
      entityType: 'sale',
      entityId: sale.id,
      metadata: {'amount': amount},
    );
  }

  Future<void> addManualIncomeFromDebtSettlement({
    required CashTransaction cashTxn,
    required DateTime occurredAt,
  }) async {
    await sub(cashTxn.workspaceId, Collections.cashTransactions)
        .add(cashTxn.toCreateMap(occurredAt: occurredAt));
  }

  Stream<List<Sale>> watchRecent(String wsId, {int limit = 5}) {
    return sub(wsId, Collections.sales)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Sale.fromDoc).toList());
  }

  Query<Map<String, dynamic>> listQuery(
    String wsId, {
    SaleStatus? status,
    OrderType? orderType,
    String? customerId,
    String? sellerId,
    DateTime? from,
    DateTime? to,
    bool onlyUnpaid = false,
  }) {
    var q = sub(wsId, Collections.sales) as Query<Map<String, dynamic>>;
    if (status != null) q = q.where('status', isEqualTo: status.name);
    if (orderType != null) q = q.where('orderType', isEqualTo: orderType.name);
    if (customerId != null && customerId.isNotEmpty) {
      q = q.where('customerId', isEqualTo: customerId);
    }
    if (sellerId != null && sellerId.isNotEmpty) {
      q = q.where('sellerId', isEqualTo: sellerId);
    }
    if (onlyUnpaid) q = q.where('paymentStatus', whereIn: ['unpaid', 'partial']);
    if (from != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }
    return q.orderBy('createdAt', descending: true);
  }

  Stream<Sale?> watchById(String wsId, String saleId) {
    return sub(wsId, Collections.sales).doc(saleId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Sale.fromDoc(doc);
    });
  }

  Future<Sale?> getById(String wsId, String saleId) async {
    final doc = await sub(wsId, Collections.sales).doc(saleId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Sale.fromDoc(doc);
  }

  Stream<int> watchActiveOrderCount(String wsId) {
    return sub(wsId, Collections.sales)
        .where('status', whereIn: [
          SaleStatus.pending.name,
          SaleStatus.confirmed.name,
          SaleStatus.processing.name,
          SaleStatus.ready.name,
        ])
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> watchActivePreOrderCount(String wsId) {
    return sub(wsId, Collections.sales)
        .where('orderType', isEqualTo: OrderType.preOrder.name)
        .where('status', whereIn: [
          SaleStatus.pending.name,
          SaleStatus.confirmed.name,
          SaleStatus.processing.name,
          SaleStatus.ready.name,
        ])
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> watchTodayRevenue(String wsId) {
    final start = DateTime.now();
    final startOfDay = DateTime(start.year, start.month, start.day);
    return sub(wsId, Collections.sales)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((s) => s.docs.map(Sale.fromDoc).where((x) => x.countsRevenue).fold(0, (acc, x) => acc + x.grandTotal));
  }

  Future<List<Sale>> listDuePreOrders(String wsId, {int limit = 10}) async {
    final snap = await sub(wsId, Collections.sales)
        .where('orderType', isEqualTo: OrderType.preOrder.name)
        .where('status', whereIn: [
          SaleStatus.pending.name,
          SaleStatus.confirmed.name,
          SaleStatus.processing.name,
        ])
        .orderBy('estimatedCompletionDate')
        .limit(limit)
        .get();
    return snap.docs.map(Sale.fromDoc).toList();
  }

  Future<List<Sale>> listInRange(
    String wsId,
    DateTime from,
    DateTime to, {
    int hardLimit = 800,
  }) async {
    final snap = await sub(wsId, Collections.sales)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('createdAt', descending: true)
        .limit(hardLimit)
        .get();
    return snap.docs.map(Sale.fromDoc).toList();
  }

  Map<String, dynamic> _saleToMap(Sale sale, {required bool isCreate}) {
    return {
      'workspaceId': sale.workspaceId,
      'transactionNumber': sale.transactionNumber,
      'sellerId': sale.sellerId,
      'sellerName': sale.sellerName,
      'customerId': sale.customerId,
      'customerName': sale.customerName,
      'customerWhatsapp': sale.customerWhatsapp,
      'transactionType': sale.transactionType.name,
      'orderType': sale.orderType.name,
      'items': sale.items.map((i) => i.toMap()).toList(),
      'subtotal': sale.subtotal,
      'discountAmount': sale.discountAmount,
      'taxPercent': sale.taxPercent,
      'taxAmount': sale.taxAmount,
      'shippingCost': sale.shippingCost,
      'grandTotal': sale.grandTotal,
      'paidAmount': sale.paidAmount,
      'remainingAmount': sale.remainingAmount,
      'paymentMethodId': sale.paymentMethodId,
      'paymentMethodName': sale.paymentMethodName,
      'paymentStatus': sale.paymentStatus.name,
      'status': sale.status.name,
      'countsRevenue': sale.countsRevenue,
      'estimatedCompletionDate': sale.estimatedCompletionDate == null
          ? null
          : Timestamp.fromDate(sale.estimatedCompletionDate!),
      'notes': sale.notes,
      'statusHistory': sale.statusHistory.map((e) => e.toMap()).toList(),
      'stockDeducted': sale.stockDeducted,
      'offlineCreated': sale.offlineCreated,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Sale _buildSale({
    required String wsId,
    required String saleId,
    required String transactionNumber,
    required SaleDraft draft,
    required String sellerId,
    required String sellerName,
    required SaleStatus status,
    required bool countsRevenue,
    required bool offlineCreated,
    required DateTime createdAtLocal,
  }) {
    final subtotal = draft.subtotal;
    final tax = draft.taxAmount;
    final grand = subtotal - draft.discountAmount + tax + draft.shippingCost;
    final paid = draft.paidAmount.clamp(0, grand);
    final paymentStatus = paid <= 0
        ? PaymentStatus.unpaid
        : paid >= grand
            ? PaymentStatus.paid
            : PaymentStatus.partial;
    return Sale(
      id: saleId,
      workspaceId: wsId,
      transactionNumber: transactionNumber,
      sellerId: sellerId,
      sellerName: sellerName,
      customerId: (draft.customerId?.isEmpty ?? true) ? null : draft.customerId,
      customerName: draft.customerName,
      customerWhatsapp: draft.customerWhatsapp,
      orderType: draft.orderType,
      items: draft.items,
      subtotal: subtotal,
      discountAmount: draft.discountAmount,
      taxPercent: draft.taxPercent,
      taxAmount: tax,
      shippingCost: draft.shippingCost,
      grandTotal: grand,
      paidAmount: paid,
      remainingAmount: grand - paid,
      paymentMethodId: draft.paymentMethodId,
      paymentMethodName: draft.paymentMethodName,
      paymentStatus: paymentStatus,
      status: status,
      countsRevenue: countsRevenue,
      estimatedCompletionDate: draft.estimatedCompletionDate,
      notes: draft.notes,
      statusHistory: [
        SaleStatusEvent(status: status, at: createdAtLocal, byUserId: sellerId)
      ],
      offlineCreated: offlineCreated,
      createdAt: createdAtLocal,
    );
  }

  Future<void> _mutateStockForItems(
    Transaction txn,
    String wsId,
    List<SaleItem> items, {
    required int direction,
    required StockReason reason,
    required String relatedSaleId,
    required String actorId,
    required bool allowNegative,
    required bool skipIfPreorderPending,
    String notePrefix = '',
  }) async {
    for (final item in items) {
      if (item.productId.isEmpty) continue;
      if (item.type != ProductType.physicalProduct &&
          !(item.type == ProductType.digitalProduct)) {
        continue;
      }
      final productRef = sub(wsId, Collections.products).doc(item.productId);
      final snap = await txn.get(productRef);
      if (!snap.exists || snap.data() == null) continue;
      final data = snap.data()!;
      final trackStock = data['trackStock'] ?? true;
      final unlimited = data['unlimitedStock'] ?? false;

      if (item.type == ProductType.physicalProduct) {
        if (!trackStock || unlimited) continue;
        final before = (data['stock'] as num?)?.toInt() ?? 0;
        final after = before + direction * item.qty;
        if (after < 0 && !allowNegative) {
          throw RepoException(
            'Stok "${item.productName}" tidak cukup. Tersedia: $before, diminta: ${item.qty}.',
          );
        }
        txn.update(productRef, {'stock': after});
        txn.set(
          sub(wsId, Collections.stockMovements).doc(),
          StockMovement(
            productId: item.productId,
            productName: item.productName,
            reason: reason,
            qtyChange: direction * item.qty,
            stockBefore: before,
            stockAfter: after,
            note: '$notePrefix${reason.label}',
            relatedSaleId: relatedSaleId,
            createdBy: actorId,
          ).toMap(),
        );
      } else if (item.type == ProductType.digitalProduct) {
        final licenseCount = data['licenseCount'];
        if (licenseCount == null || unlimited) continue;
        final before = (licenseCount as num).toInt();
        final after = before + direction * item.qty;
        if (after < 0 && !allowNegative) {
          throw RepoException(
            'Lisensi "${item.productName}" tidak cukup. Tersedia: $before.',
          );
        }
        txn.update(productRef, {'licenseCount': after});
        txn.set(
          sub(wsId, Collections.stockMovements).doc(),
          StockMovement(
            productId: item.productId,
            productName: item.productName,
            reason: reason,
            qtyChange: direction * item.qty,
            stockBefore: before,
            stockAfter: after,
            note: '${notePrefix}Lisensi ${reason.label}',
            relatedSaleId: relatedSaleId,
            createdBy: actorId,
          ).toMap(),
        );
      }
    }
  }

  Future<void> _applyCustomerStats(
    Transaction txn,
    String wsId,
    String customerId, {
    required int spentDelta,
    required int countDelta,
  }) async {
    final ref = sub(wsId, Collections.customers).doc(customerId);
    final snap = await txn.get(ref);
    if (!snap.exists) return;
    final data = snap.data()!;
    final currentSpent = (data['totalSpent'] as num?)?.toInt() ?? 0;
    final currentCount = (data['totalTransactions'] as num?)?.toInt() ?? 0;
    txn.update(ref, {
      'totalSpent': currentSpent + spentDelta,
      'totalTransactions': currentCount + countDelta,
    });
  }

  int _estimateProfit(SaleDraft draft) {
    final cost = draft.items.fold(0, (s, i) => s + i.lineCost);
    return draft.subtotal - draft.discountAmount - cost - draft.taxAmount - draft.shippingCost;
  }

  String _incomeCategory(SaleDraft draft) {
    if (draft.orderType == OrderType.preOrder) {
      return draft.paidAmount < draft.grandTotal ? 'Pembayaran DP' : 'Penjualan';
    }
    return draft.paidAmount < draft.grandTotal ? 'Pelunasan Piutang' : 'Penjualan';
  }

  Future<void> updateNotes(String wsId, String saleId, String notes) async {
    await sub(wsId, Collections.sales).doc(saleId).update({
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  bool _isNetworkError(FirebaseException e) =>
      e.code == 'unavailable' || e.code == 'network-request-failed';

  bool _isGenericNetworkError(Object e) =>
      e.toString().toLowerCase().contains('network') ||
      e.toString().toLowerCase().contains('unavailable') ||
      e.toString().toLowerCase().contains('host lookup');
}

class WorkspaceSettingsSnapshot {
  final bool allowOverselling;
  final bool requireCustomerForSale;
  final double taxPercent;
  final bool preOrderEnabled;

  const WorkspaceSettingsSnapshot({
    this.allowOverselling = false,
    this.requireCustomerForSale = false,
    this.taxPercent = 0,
    this.preOrderEnabled = true,
  });
}
