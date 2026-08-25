import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cash_transaction_model.dart';
import '../models/daily_summary_model.dart';
import '../models/enums.dart';
import '../models/sale_model.dart';
import 'base_repository.dart';
import 'cashflow_repository.dart';
import 'dashboard_repository.dart';
import 'product_repository.dart';
import 'sale_repository.dart';

class ProductSalesStat {
  final String productId;
  final String name;
  final int qty;
  final int revenue;

  const ProductSalesStat({required this.productId, required this.name, required this.qty, required this.revenue});
}

class CategorySalesStat {
  final String categoryName;
  final int qty;
  final int revenue;

  const CategorySalesStat({required this.categoryName, required this.qty, required this.revenue});
}

class PaymentMethodStat {
  final String methodName;
  final int count;
  final int amount;

  const PaymentMethodStat({required this.methodName, required this.count, required this.amount});
}

class SalesReport {
  final AppDateRange range;
  final int totalRevenue;
  final int totalTransactions;
  final int totalCost;
  final int estimatedProfit;
  final bool profitIsEstimate;
  final List<DailyPoint> daily;
  final List<ProductSalesStat> topProducts;
  final List<CategorySalesStat> byCategory;
  final List<PaymentMethodStat> byPaymentMethod;
  final int serviceRevenue;
  final int physicalRevenue;
  final int digitalRevenue;

  const SalesReport({
    required this.range,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalCost,
    required this.estimatedProfit,
    required this.profitIsEstimate,
    required this.daily,
    required this.topProducts,
    required this.byCategory,
    required this.byPaymentMethod,
    required this.serviceRevenue,
    required this.physicalRevenue,
    required this.digitalRevenue,
  });
}

class CashflowReport {
  final AppDateRange range;
  final CashTotals totals;
  final Map<String, int> incomeByCategory;
  final Map<String, int> expenseByCategory;

  const CashflowReport({
    required this.range,
    required this.totals,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  int get net => totals.net;
}

class StockReport {
  final int totalItems;
  final int trackedItems;
  final int stockValueEstimate;
  final List<Product> lowStock;

  const StockReport({
    required this.totalItems,
    required this.trackedItems,
    required this.stockValueEstimate,
    required this.lowStock,
  });
}

class PreOrderReport {
  final int total;
  final int active;
  final int completed;
  final int cancelled;
  final int dpCollected;
  final List<Sale> dueSoon;

  const PreOrderReport({
    required this.total,
    required this.active,
    required this.completed,
    required this.cancelled,
    required this.dpCollected,
    required this.dueSoon,
  });
}

class ReportRepository extends BaseRepository {
  final String wsId;

  ReportRepository({required this.wsId});

  final SaleRepository _sales = SaleRepository();
  final CashflowRepository _cashflow = CashflowRepository();
  final ProductRepository _products = ProductRepository();

  Future<SalesReport> salesReport(AppDateRange range) async {
    final sales = await _sales.listInRange(wsId, range.start, range.end.add(const Duration(days: 1)));
    final completed = sales.where((s) => s.countsRevenue).toList();

    var totalRevenue = 0;
    var totalCost = 0;
    var hasUnknownCosts = false;
    var serviceRevenue = 0;
    var physicalRevenue = 0;
    var digitalRevenue = 0;

    final productAgg = <String, ProductSalesStat>{};
    final categoryAgg = <String, CategorySalesStat>{};
    final paymentAgg = <String, PaymentMethodStat>{};

    for (final sale in completed) {
      totalRevenue += sale.grandTotal;
      totalCost += sale.totalCost;
      if (sale.hasUnknownCosts) hasUnknownCosts = true;

      for (final item in sale.items) {
        switch (item.type) {
          case ProductType.service:
          case ProductType.otherService:
            serviceRevenue += item.lineTotal;
            break;
          case ProductType.physicalProduct:
            physicalRevenue += item.lineTotal;
            break;
          case ProductType.digitalProduct:
            digitalRevenue += item.lineTotal;
            break;
        }

        final pid = item.productId.isEmpty ? item.productName : item.productId;
        final existingProduct = productAgg[pid];
        productAgg[pid] = ProductSalesStat(
          productId: pid,
          name: item.productName,
          qty: (existingProduct?.qty ?? 0) + item.qty,
          revenue: (existingProduct?.revenue ?? 0) + item.lineTotal,
        );

        final catName = item.categoryName.isEmpty ? 'Tanpa Kategori' : item.categoryName;
        final existingCat = categoryAgg[catName];
        categoryAgg[catName] = CategorySalesStat(
          categoryName: catName,
          qty: (existingCat?.qty ?? 0) + item.qty,
          revenue: (existingCat?.revenue ?? 0) + item.lineTotal,
        );
      }

      final pmName = sale.paymentMethodName.isEmpty ? 'Tidak dicatat' : sale.paymentMethodName;
      final existingPm = paymentAgg[pmName];
      paymentAgg[pmName] = PaymentMethodStat(
        methodName: pmName,
        count: (existingPm?.count ?? 0) + 1,
        amount: (existingPm?.amount ?? 0) + sale.paidAmount,
      );
    }

    final summaries = await _summariesForRange(range);
    final summaryByKey = {for (final s in summaries) s.id: s};
    final daily = <DailyPoint>[];
    var day = DateTime(range.start.year, range.start.month, range.start.day);
    while (!day.isAfter(range.end)) {
      final key = DailySummary.dayKey(day);
      final s = summaryByKey[key];
      daily.add(DailyPoint(
        day: day,
        revenue: s?.revenue ?? 0,
        orders: s?.orderCount ?? 0,
        profit: s?.estimatedProfit ?? 0,
      ));
      day = day.add(const Duration(days: 1));
    }

    final topProducts = productAgg.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    final categories = categoryAgg.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final payments = paymentAgg.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return SalesReport(
      range: range,
      totalRevenue: totalRevenue,
      totalTransactions: completed.length,
      totalCost: totalCost,
      estimatedProfit: totalRevenue - totalCost,
      profitIsEstimate: hasUnknownCosts || totalCost == 0,
      daily: daily,
      topProducts: topProducts.take(10).toList(),
      byCategory: categories.take(10).toList(),
      byPaymentMethod: payments,
      serviceRevenue: serviceRevenue,
      physicalRevenue: physicalRevenue,
      digitalRevenue: digitalRevenue,
    );
  }

  Future<CashflowReport> cashflowReport(AppDateRange range) async {
    final totals = await _cashflow.totalsForRange(wsId, range.start, range.end.add(const Duration(days: 1)));
    final snap = await sub(wsId, Collections.cashTransactions)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('occurredAt',
            isLessThanOrEqualTo: Timestamp.fromDate(range.end.add(const Duration(days: 1))))
        .limit(800)
        .get();

    final incomeByCat = <String, int>{};
    final expenseByCat = <String, int>{};
    for (final doc in snap.docs) {
      final txnModel = CashTransaction.fromDoc(doc);
      if (txnModel.type == CashTransactionType.income) {
        incomeByCat[txnModel.category] =
            (incomeByCat[txnModel.category] ?? 0) + txnModel.amount;
      } else {
        expenseByCat[txnModel.category] =
            (expenseByCat[txnModel.category] ?? 0) + txnModel.amount;
      }
    }

    return CashflowReport(
      range: range,
      totals: totals,
      incomeByCategory: incomeByCat,
      expenseByCategory: expenseByCat,
    );
  }

  Future<StockReport> stockReport() async {
    final products = await _products.listAll(wsId, limit: 500);
    var tracked = 0;
    var value = 0;
    for (final p in products) {
      if (p.type == ProductType.physicalProduct && p.trackStock && !p.unlimitedStock) {
        tracked++;
        value += p.stock * (p.costPrice ?? p.sellingPrice);
      }
    }
    final lowStock = await _products.listLowStock(wsId, limit: 50);
    return StockReport(
      totalItems: products.length,
      trackedItems: tracked,
      stockValueEstimate: value,
      lowStock: lowStock,
    );
  }

  Future<PreOrderReport> preOrderReport(AppDateRange range) async {
    final sales = await _sales.listInRange(wsId, range.start, range.end.add(const Duration(days: 1)));
    final preorders = sales.where((s) => s.isPreOrder).toList();

    var dpCollected = 0;
    for (final po in preorders) {
      dpCollected += po.paidAmount;
    }

    final dueSoon = preorders
        .where((s) =>
            s.status.isActiveOrder &&
            s.estimatedCompletionDate != null &&
            s.estimatedCompletionDate!.isBefore(DateTime.now().add(const Duration(days: 7))))
        .toList()
      ..sort((a, b) => a.estimatedCompletionDate!.compareTo(b.estimatedCompletionDate!));

    return PreOrderReport(
      total: preorders.length,
      active: preorders.where((s) => s.status.isActiveOrder).length,
      completed: preorders.where((s) => s.status == SaleStatus.completed).length,
      cancelled: preorders.where((s) => s.status == SaleStatus.cancelled).length,
      dpCollected: dpCollected,
      dueSoon: dueSoon.take(20).toList(),
    );
  }

  Future<List<DailySummary>> _summariesForRange(AppDateRange range) async {
    final ids = <String>[];
    var day = DateTime(range.start.year, range.start.month, range.start.day);
    while (!day.isAfter(range.end)) {
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
}
