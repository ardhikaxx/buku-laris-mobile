import '../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cash_transaction_model.dart';
import '../models/daily_summary_model.dart';
import '../models/enums.dart';
import 'base_repository.dart';

class CashTotals {
  final int income;
  final int expense;

  const CashTotals({required this.income, required this.expense});

  int get net => income - expense;
}

class CashflowRepository extends BaseRepository {
  Future<DocumentReference<Map<String, dynamic>>> add(
      CashTransaction txnModel, DateTime occurredAt) async {
    final ref = await sub(txnModel.workspaceId, Collections.cashTransactions)
        .add(txnModel.toCreateMap(occurredAt: occurredAt));
    await _bumpDailySummary(txnModel.workspaceId, occurredAt,
        income: txnModel.type == CashTransactionType.income ? txnModel.amount : 0,
        expense: txnModel.type == CashTransactionType.expense ? txnModel.amount : 0);
    return ref;
  }

  Future<void> transfer({
    required String wsId,
    required String fromMethodId,
    required String fromMethodName,
    required String toMethodId,
    required String toMethodName,
    required int amount,
    required DateTime occurredAt,
    required String notes,
    required String createdBy,
  }) async {
    if (amount <= 0) {
      throw RepoException('Nominal transfer harus lebih besar dari 0.');
    }
    if (fromMethodName.toLowerCase().trim() ==
        toMethodName.toLowerCase().trim()) {
      throw RepoException(
          'Akun asal dan akun tujuan transfer tidak boleh sama.');
    }

    final batch = fs.batch();
    final col = sub(wsId, Collections.cashTransactions);

    // 1. Catatan Uang Keluar dari Akun Asal
    final outRef = col.doc();
    final outTxn = CashTransaction(
      workspaceId: wsId,
      type: CashTransactionType.expense,
      category: 'Transfer Kas Keluar',
      amount: amount,
      occurredAt: occurredAt,
      paymentMethodId: fromMethodId,
      paymentMethodName: fromMethodName,
      sourceType: 'TRANSFER',
      description: 'Pindah dana ke $toMethodName',
      notes: notes,
      createdBy: createdBy,
    );
    batch.set(outRef, outTxn.toCreateMap(occurredAt: occurredAt));

    // 2. Catatan Uang Masuk ke Akun Tujuan
    final inRef = col.doc();
    final inTxn = CashTransaction(
      workspaceId: wsId,
      type: CashTransactionType.income,
      category: 'Transfer Kas Masuk',
      amount: amount,
      occurredAt: occurredAt,
      paymentMethodId: toMethodId,
      paymentMethodName: toMethodName,
      sourceType: 'TRANSFER',
      description: 'Pindah dana dari $fromMethodName',
      notes: notes,
      createdBy: createdBy,
    );
    batch.set(inRef, inTxn.toCreateMap(occurredAt: occurredAt));

    await batch.commit();
  }

  Future<void> update(
      CashTransaction txnModel, DateTime occurredAt) async {
    if (txnModel.sourceSaleId.isNotEmpty) {
      throw RepoException(
          'Catatan kas yang berasal dari penjualan tidak dapat diubah dari modul kas. Ubah melalui detail transaksi penjualan.');
    }
    final oldDoc = await sub(txnModel.workspaceId, Collections.cashTransactions)
        .doc(txnModel.id)
        .get();
    final old = oldDoc.exists ? CashTransaction.fromDoc(oldDoc) : null;

    await sub(txnModel.workspaceId, Collections.cashTransactions)
        .doc(txnModel.id)
        .update(txnModel.toUpdateMap(occurredAt: occurredAt));

    if (old != null) {
      await _bumpDailySummary(txnModel.workspaceId, old.occurredAt,
          income: old.type == CashTransactionType.income ? -old.amount : 0,
          expense: old.type == CashTransactionType.expense ? -old.amount : 0);
    }
    await _bumpDailySummary(txnModel.workspaceId, occurredAt,
        income: txnModel.type == CashTransactionType.income ? txnModel.amount : 0,
        expense: txnModel.type == CashTransactionType.expense ? txnModel.amount : 0);
  }

  Future<void> delete(CashTransaction txnModel) async {
    if (txnModel.sourceSaleId.isNotEmpty) {
      throw RepoException(
          'Catatan kas yang terhubung ke transaksi penjualan tidak dapat dihapus langsung. Batalkan atau refund transaksi penjualannya.');
    }

    // Jika catatan merupakan bagian dari Pindah Dana / Transfer, hapus juga transaksi pasangannya
    if (txnModel.sourceType == 'TRANSFER') {
      try {
        final twinSnap = await sub(txnModel.workspaceId, Collections.cashTransactions)
            .where('sourceType', isEqualTo: 'TRANSFER')
            .where('amount', isEqualTo: txnModel.amount)
            .get();
        for (final doc in twinSnap.docs) {
          if (doc.id == txnModel.id) continue;
          final t = CashTransaction.fromDoc(doc);
          if (t.type != txnModel.type &&
              t.occurredAt.difference(txnModel.occurredAt).inMinutes.abs() <= 5) {
            await sub(txnModel.workspaceId, Collections.cashTransactions)
                .doc(t.id)
                .delete();
            await _bumpDailySummary(txnModel.workspaceId, t.occurredAt,
                income: t.type == CashTransactionType.income ? -t.amount : 0,
                expense: t.type == CashTransactionType.expense ? -t.amount : 0);
            break;
          }
        }
      } catch (_) {}
    }

    await sub(txnModel.workspaceId, Collections.cashTransactions)
        .doc(txnModel.id)
        .delete();
    await _bumpDailySummary(txnModel.workspaceId, txnModel.occurredAt,
        income: txnModel.type == CashTransactionType.income ? -txnModel.amount : 0,
        expense: txnModel.type == CashTransactionType.expense ? -txnModel.amount : 0);
  }

  Future<CashTotals> totalsForRange(String wsId, DateTime from, DateTime to) async {
    try {
      final snap = await sub(wsId, Collections.cashTransactions).get();
      final fromMs = from.millisecondsSinceEpoch;
      final toMs = to.millisecondsSinceEpoch;

      final refundedSaleIds = <String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final sourceSaleId = d['sourceSaleId'] as String?;
        final sourceType = d['sourceType'] as String?;
        final isVoided = d['isVoided'] == true || d['isRefunded'] == true;
        if ((isVoided || sourceType == 'REFUND') &&
            sourceSaleId != null &&
            sourceSaleId.isNotEmpty) {
          refundedSaleIds.add(sourceSaleId);
        }
      }

      var income = 0;
      var expense = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final sourceSaleId = d['sourceSaleId'] as String?;
        final sourceType = d['sourceType'] as String?;
        final isVoided = d['isVoided'] == true || d['isRefunded'] == true;

        if (isVoided) continue;
        if (sourceType == 'TRANSFER') continue;
        if (sourceSaleId != null && refundedSaleIds.contains(sourceSaleId)) {
          // Exclude transactions from refunded/cancelled sales
          continue;
        }

        final ts = d['occurredAt'] as Timestamp?;
        final amount = (d['amount'] as num?)?.toInt() ?? 0;
        final type = d['type'] as String?;
        if (ts != null) {
          final ms = ts.millisecondsSinceEpoch;
          if (ms < fromMs || ms > toMs) continue;
        }
        if (type == CashTransactionType.income.name) {
          income += amount;
        } else if (type == CashTransactionType.expense.name) {
          expense += amount;
        }
      }
      return CashTotals(income: income, expense: expense);
    } catch (_) {
      return const CashTotals(income: 0, expense: 0);
    }
  }

  Query<Map<String, dynamic>> listQuery(
    String wsId, {
    CashTransactionType? type,
    String? category,
    DateTime? from,
    DateTime? to,
  }) {
    var q = sub(wsId, Collections.cashTransactions)
        as Query<Map<String, dynamic>>;
    if (type != null) q = q.where('type', isEqualTo: type.name);
    if (category != null && category.isNotEmpty) {
      q = q.where('category', isEqualTo: category);
    }
    if (from != null) {
      q = q.where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('occurredAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }
    return q.orderBy('occurredAt', descending: true);
  }

  Stream<List<CashTransaction>> watchAll(
    String wsId, {
    CashTransactionType? type,
    String? category,
    DateTime? from,
    DateTime? to,
  }) {
    return sub(wsId, Collections.cashTransactions).snapshots().map((s) {
      final fromMs = from?.millisecondsSinceEpoch;
      final toMs = to?.millisecondsSinceEpoch;
      final list = s.docs
          .map(CashTransaction.fromDoc)
          .where((txn) {
            if (type != null && txn.type != type) return false;
            if (category != null && category.isNotEmpty && txn.category != category) {
              return false;
            }
            final ms = txn.occurredAt.millisecondsSinceEpoch;
            if (fromMs != null && ms < fromMs) return false;
            if (toMs != null && ms > toMs) return false;
            return true;
          })
          .toList();
      list.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return list;
    });
  }

  Stream<List<CashTransaction>> watchRecent(String wsId, {int limit = 5}) {
    return watchAll(wsId).map((list) {
      if (list.length > limit) return list.sublist(0, limit);
      return list;
    });
  }

  Future<List<DailySummary>> summariesInRange(
      String wsId, DateTime from, DateTime to) async {
    var day = DateTime(from.year, from.month, from.day);
    final ids = <String>[];
    while (!day.isAfter(to)) {
      ids.add(DailySummary.dayKey(day));
      day = day.add(const Duration(days: 1));
    }
    if (ids.length > 62) {
      ids.removeRange(62, ids.length);
    }
    final result = <DailySummary>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await sub(wsId, Collections.dailySummaries)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(snap.docs.map(DailySummary.fromDoc));
    }
    return result;
  }

  Future<void> _bumpDailySummary(String wsId, DateTime day,
      {required int income, required int expense}) async {
    try {
      await sub(wsId, Collections.dailySummaries)
          .doc(DailySummary.dayKey(day))
          .set(
              DailySummary.cashIncrementMap(cashInDelta: income, cashOutDelta: expense),
              SetOptions(merge: true));
    } catch (_) {}
  }
}
