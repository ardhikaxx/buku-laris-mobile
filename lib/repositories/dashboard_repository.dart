import '../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';
import '../models/daily_summary_model.dart';
import '../models/enums.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../services/logger.dart';
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
  static final List<String> _activeStatusNames = [
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
      if (includeFinance)
        _revenueAndOrders(wsId, startOfMonth(DateTime.now()), now)
      else
        Future.value(const _RevOrd(revenue: 0, orders: 0)),
      if (includeFinance)
        _guard(
          () => _cashflow.totalsForRange(
              wsId, startOfMonth(DateTime.now()), now),
          fallback: const CashTotals(income: 0, expense: 0),
        )
      else
        Future.value(const CashTotals(income: 0, expense: 0)),
      _productCount(wsId),
      if (includeFinance)
        _guard(() => _products.listLowStock(wsId, limit: 6),
            fallback: <Product>[])
      else
        Future.value(<Product>[]),
      _activeOrdersCounts(wsId),
      _guard(() => _chart(wsId, range), fallback: <DailyPoint>[]),
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
    final activeCounts = results[6] as (int, int);
    final chart = results[7] as List<DailyPoint>;
    final unknownCosts = results[8] as bool;
    final monthProfit = results[9] as (int, bool);

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
      activeOrders: activeCounts.$1,
      activePreOrders: activeCounts.$2,
      chart: chart,
      range: range,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action,
      {required T fallback}) async {
    try {
      return await action();
    } catch (e) {
      Logger.e('dashboard: bagian dashboard gagal dimuat, dinolkan', e);
      return fallback;
    }
  }

  bool _isValidSaleForRevenue(Map<String, dynamic> d) {
    final status = d['status'] as String?;
    final paymentStatus = d['paymentStatus'] as String?;
    if (status == SaleStatus.cancelled.name ||
        status == SaleStatus.refunded.name ||
        status == SaleStatus.draft.name ||
        paymentStatus == PaymentStatus.refunded.name) {
      return false;
    }
    return d['countsRevenue'] == true;
  }

  Future<_RevOrd> _revenueAndOrders(
      String wsId, DateTime from, DateTime to) async {
    try {
      final snap = await sub(wsId, Collections.sales).get();
      final fromMs = from.millisecondsSinceEpoch;
      final toMs = to.millisecondsSinceEpoch;
      var revenue = 0;
      var orders = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        if (!_isValidSaleForRevenue(d)) continue;
        final ts = d['createdAt'] as Timestamp?;
        if (ts != null) {
          final ms = ts.millisecondsSinceEpoch;
          if (ms < fromMs || ms > toMs) continue;
        }
        revenue += (d['grandTotal'] as num?)?.toInt() ?? 0;
        orders += 1;
      }
      return _RevOrd(revenue: revenue, orders: orders);
    } catch (e) {
      Logger.e('dashboard _revenueAndOrders failed', e);
      return const _RevOrd(revenue: 0, orders: 0);
    }
  }

  Future<int> _productCount(String wsId) async {
    try {
      final snap = await sub(wsId, Collections.products).get();
      return snap.docs.where((d) => d.data()['archived'] != true).length;
    } catch (_) {
      return 0;
    }
  }

  Future<(int, int)> _activeOrdersCounts(String wsId) async {
    try {
      final snap = await sub(wsId, Collections.sales).get();
      var active = 0;
      var preOrders = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final status = d['status'] as String?;
        if (_activeStatusNames.contains(status)) {
          active += 1;
          if (d['orderType'] == OrderType.preOrder.name) {
            preOrders += 1;
          }
        }
      }
      return (active, preOrders);
    } catch (_) {
      return (0, 0);
    }
  }

  Future<List<DailyPoint>> _chart(String wsId, AppDateRange range) async {
    try {
      final snap = await sub(wsId, Collections.sales).get();
      final dailyMap = <String, DailyPoint>{};
      var day = DateTime(range.start.year, range.start.month, range.start.day);
      while (!day.isAfter(range.end)) {
        final key = DailySummary.dayKey(day);
        dailyMap[key] = DailyPoint(day: day, revenue: 0, orders: 0, profit: 0);
        day = day.add(const Duration(days: 1));
      }

      for (final doc in snap.docs) {
        final d = doc.data();
        if (!_isValidSaleForRevenue(d)) continue;
        final ts = d['createdAt'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        final key = DailySummary.dayKey(dt);
        if (dailyMap.containsKey(key)) {
          final existing = dailyMap[key]!;
          final sale = Sale.fromDoc(doc);
          dailyMap[key] = DailyPoint(
            day: existing.day,
            revenue: existing.revenue + sale.grandTotal,
            orders: existing.orders + 1,
            profit: existing.profit + sale.estimatedProfit,
          );
        }
      }
      return dailyMap.values.toList()
        ..sort((a, b) => a.day.compareTo(b.day));
    } catch (_) {
      return <DailyPoint>[];
    }
  }

  Future<bool> _hasUnknownCostSales(String wsId) async {
    try {
      final snap = await sub(wsId, Collections.sales).get();
      for (final doc in snap.docs) {
        final d = doc.data();
        if (!_isValidSaleForRevenue(d)) continue;
        final sale = Sale.fromDoc(doc);
        if (sale.hasUnknownCosts) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<(int, bool)> _monthProfit(String wsId, DateTime now) async {
    try {
      final from = startOfMonth(now);
      final fromMs = from.millisecondsSinceEpoch;
      final toMs = now.millisecondsSinceEpoch;
      final snap = await sub(wsId, Collections.sales).get();
      var profit = 0;
      var hasUnknown = false;
      for (final doc in snap.docs) {
        final d = doc.data();
        if (!_isValidSaleForRevenue(d)) continue;
        final ts = d['createdAt'] as Timestamp?;
        if (ts != null) {
          final ms = ts.millisecondsSinceEpoch;
          if (ms < fromMs || ms > toMs) continue;
        }
        final sale = Sale.fromDoc(doc);
        profit += sale.estimatedProfit;
        if (sale.hasUnknownCosts) {
          hasUnknown = true;
        }
      }
      return (profit, hasUnknown);
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
