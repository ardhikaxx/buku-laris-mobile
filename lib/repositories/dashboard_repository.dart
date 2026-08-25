import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';
import '../models/daily_summary_model.dart';
import '../models/enums.dart';
import 'base_repository.dart';
import 'cashflow_repository.dart';
import 'product_repository.dart';

class AppDateRange {
  final DateTime start;
  final DateTime end;

  const AppDateRange({required this.start, required this.end});

  factory AppDateRange.today() {
    final now = DateTime.now();
    return AppDateRange(start: startOfDay(now), end: now);
  }

  factory AppDateRange.thisWeek() {
    final now = DateTime.now();
    return AppDateRange(start: startOfWeek(now), end: now);
  }

  factory AppDateRange.thisMonth() {
    final now = DateTime.now();
    return AppDateRange(start: startOfMonth(now), end: now);
  }

  int get dayCount => end.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
}

class DailyPoint {
  final DateTime day;
  final int revenue;
  final int orders;
  final int profit;

  const DailyPoint({required this.day, this.revenue = 0, this.orders = 0, this.profit = 0});
}

class DashboardData {
  final int periodRevenue;
  final int periodOrders;
  final int todayRevenue;
  final int monthRevenue;
  final int monthCashIn;
  final int monthCashOut;
  final int monthProfitEstimate;
  final bool profitHasUnknownCosts;
  final int productCount;
  final List<Product> lowStockPreview;
  final int activeOrders;
  final int activePreOrders;
  final List<DailyPoint> chart;
  final AppDateRange range;

  const DashboardData({
    required this.periodRevenue,
    required this.periodOrders,
    required this.todayRevenue,
    required this.monthRevenue,
    required this.monthCashIn,
    required this.monthCashOut,
    required this.monthProfitEstimate,
    required this.profitHasUnknownCosts,
    required this.productCount,
    required this.lowStockPreview,
    required this.activeOrders,
    required this.activePreOrders,
    required this.chart,
    required this.range,
  });
}

class DashboardRepository extends BaseRepository {
  static const _activeStatusNames = [
    SaleStatus.pending.name,
    SaleStatus.confirmed.name,
    SaleStatus.processing.name,
    SaleStatus.ready.name,
  ];

  final CashflowRepository _cashflow = CashflowRepository();
  final ProductRepository _products = ProductRepository();

  Future<DashboardData> load({
    required String wsId,
    required bool includeFinance,
    required AppDateRange range,
  }) async {
    final now = DateTime.now().add(const Duration(minutes: 1));
    final results = await Future.wait([
      _revenueAndOrders(wsId, range.start, now),
      if (includeFinance)
        _revenueAndOrders(wsId, startOfDay(DateTime.now()), now)
      else
        Future.value(const _RevOrd(revenue: 0, orders: 0)),
      if (includeFinance) _revenueAndOrders(wsId, startOfMonth(DateTime.now()), now)
      else
        Future.value(const _RevOrd(revenue: 0, orders: 0)),
      if (includeFinance)
        _cashflow.totalsForRange(wsId, startOfMonth(DateTime.now()), now)
      else
        Future.value(const CashTotals(income: 0, expense: 0)),
      _productCount(wsId),
      if (includeFinance) _products.listLowStock(wsId, limit: 6) else Future.value(<Product>[]),
      _countQuery(sub(wsId, Collections.sales).where('status', whereIn: _activeStatusNames)),
      _countQuery(sub(wsId, Collections.sales)
          .where('orderType', isEqualTo: OrderType.preOrder.name)
          .where('status', whereIn: _activeStatusNames)),
      _chart(wsId, range),
      if (includeFinance) _hasUnknownCostSales(wsId) else Future.value(false),
      if (includeFinance)
        _monthProfit(wsId, now)
      else
        Future.value((0, false)),
    ]);

    final period = results[0] as _RevOrd;
    final today = results[1] as _RevOrd;
    final month = results[2] as _RevOrd;
    final cashTotals = results[3] as CashTotals;
    final productCount = results[4] as int;
    final lowStock = results[5] as List<Product>;
    final activeOrders = results[6] as int;
    final activePreOrders = results[7] as int;
    final chart = results[8] as List<DailyPoint>;
    final unknownCosts = results[9] as bool;
    final monthProfit = results[10] as (int, bool);

    return DashboardData(
      periodRevenue: period.revenue,
      periodOrders: period.orders,
      todayRevenue: today.revenue,
      monthRevenue: month.revenue,
      monthCashIn: cashTotals.income,
      monthCashOut: cashTotals.expense,
      monthProfitEstimate: monthProfit.$1,
      profitHasUnknownCosts: unknownCosts || monthProfit.$2,
      productCount: productCount,
      lowStockPreview: lowStock,
      activeOrders: activeOrders,
      activePreOrders: activePreOrders,
      chart: chart,
      range: range,
    );
  }

  Future<_RevOrd> _revenueAndOrders(String wsId, DateTime from, DateTime to) async {
    try {
      final snap = await sub(wsId, Collections.sales)
          .where('countsRevenue', isEqualTo: true)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .aggregate(sum('grandTotal'), count())
          .get();
      return _RevOrd(
        revenue: (snap.getSum('grandTotal') as num?)?.toInt() ?? 0,
        orders: snap.count ?? 0,
      );
    } catch (_) {
      return const _RevOrd(revenue: 0, orders: 0);
    }
  }

  Future<int> _productCount(String wsId) async {
    try {
      final snap = await sub(wsId, Collections.products)
          .where('archived', isEqualTo: false)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countQuery(Query<Map<String, dynamic>> q) async {
    try {
      final snap = await q.count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<DailyPoint>> _chart(String wsId, AppDateRange range) async {
    final summaries = await _summaries(wsId, range.start, range.end);
    final byKey = {for (final s in summaries) s.id: s};
    final chart = <DailyPoint>[];
    var day = DateTime(range.start.year, range.start.month, range.start.day);
    while (!day.isAfter(range.end)) {
      final key = DailySummary.dayKey(day);
      final summary = byKey[key];
      chart.add(DailyPoint(
        day: day,
        revenue: summary?.revenue ?? 0,
        orders: summary?.orderCount ?? 0,
        profit: summary?.estimatedProfit ?? 0,
      ));
      day = day.add(const Duration(days: 1));
    }
    return chart;
  }

  Future<List<DailySummary>> _summaries(String wsId, DateTime from, DateTime to) async {
    final ids = <String>[];
    var day = DateTime(from.year, from.month, from.day);
    while (!day.isAfter(to)) {
      ids.add(DailySummary.dayKey(day));
      day = day.add(const Duration(days: 1));
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

  Future<bool> _hasUnknownCostSales(String wsId) async {
    try {
      final snap = await sub(wsId, Collections.dailySummaries)
          .where('hasUnknownCostSales', isEqualTo: true)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<(int, bool)> _monthProfit(String wsId, DateTime now) async {
    try {
      final summaries =
          await _summaries(wsId, startOfMonth(DateTime.now()), DateTime.now());
      final total = summaries.fold(0, (sum, s) => sum + s.estimatedProfit);
      return (total, false);
    } catch (_) {
      return (0, false);
    }
  }
}

class _RevOrd {
  final int revenue;
  final int orders;

  const _RevOrd({required this.revenue, required this.orders});
}
