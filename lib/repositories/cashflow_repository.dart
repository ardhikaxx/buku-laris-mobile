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
      var income = 0;
      var expense = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
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
