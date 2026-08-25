import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../repositories/dashboard_repository.dart';
import '../../../repositories/report_repository.dart';

enum ReportTab { sales, cashflow, products, preorders }

extension ReportTabX on ReportTab {
  String get label => switch (this) {
        ReportTab.sales => 'Penjualan',
        ReportTab.cashflow => 'Kas',
        ReportTab.products => 'Stok',
        ReportTab.preorders => 'Pre-Order',
      };
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportTab _tab = ReportTab.sales;
  DateTimeRange _range = _last30Days();
  Future<Object>? _future;

  static DateTimeRange _last30Days() {
    final now = DateTime.now();
    return DateTimeRange(
      start: startOfDay(now).subtract(const Duration(days: 29)),
      end: now,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    if (wsId == null) return;
    final range = AppDateRange(start: _range.start, end: _range.end);
    final repo = ReportRepository(wsId: wsId);
    setState(() {
      _future = switch (_tab) {
        ReportTab.sales =>
          repo.salesReport(range),
        ReportTab.cashflow => repo.cashflowReport(range),
        ReportTab.products => repo.stockReport(),
        ReportTab.preorders => repo.preOrderReport(range),
      };
    });
  }

  void _switchTab(ReportTab tab) {
    setState(() => _tab = tab);
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        _range = DateTimeRange(start: picked.start, end: picked.end);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final tab in ReportTab.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(tab.label),
                              selected: _tab == tab,
                              onSelected: (_) => _switchTab(tab),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Pilih periode',
                  icon: const Icon(Icons.date_range_rounded, size: 20),
                  onPressed: _pickRange,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.date_range_rounded, size: 19),
                      title: const Text('Periode Laporan',
                          style: TextStyle(fontSize: 13)),
                      subtitle: Text(
                          '${dateShort(_range.start)} - ${dateShort(_range.end)}',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark)),
                      trailing: TextButton(
                        onPressed: () {
                          setState(() => _range = _last30Days());
                          _load();
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_future == null)
                    const SizedBox(height: 100)
                  else
                    FutureBuilder<Object>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Column(children: [
                            SkeletonBox(height: 90, radius: 14),
                            SizedBox(height: 10),
                            SkeletonBox(height: 220, radius: 14),
                          ]);
                        }
                        if (snapshot.hasError) {
                          return ErrorStateView(error: snapshot.error!, onRetry: _load);
                        }
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildReport(snapshot.data!),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(Object data) {
    return switch (_tab) {
      ReportTab.sales => _SalesReportView(data as SalesReport),
      ReportTab.cashflow => _CashflowReportView(data as CashflowReport),
      ReportTab.products => _StockReportView(data as StockReport),
      ReportTab.preorders => _PreOrderReportView(data as PreOrderReport),
    };
  }
}

class _SalesReportView extends StatelessWidget {
  final SalesReport report;

  const _SalesReportView(this.report);

  @override
  Widget build(BuildContext context) {
    if (report.totalTransactions == 0) {
      return const EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Belum ada penjualan pada periode ini',
        message:
            'Laporan dihitung dari transaksi nyata. Catat penjualan untuk melihat laporan.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: AppColors.primary,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Penjualan (${report.totalTransactions} transaksi)',
                    style: const TextStyle(
                        fontSize: 12.5, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(money(report.totalRevenue),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total HPP (modal terjual)',
                value: compactMoney(report.totalCost),
                icon: Icons.payments_outlined,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: report.profitIsEstimate
                    ? 'Estimasi Laba'
                    : 'Laba Kotor',
                value: compactMoney(report.estimatedProfit),
                icon: Icons.savings_outlined,
                color: report.estimatedProfit >= 0
                    ? AppColors.income
                    : AppColors.expense,
              ),
            ),
          ],
        ),
        if (report.profitIsEstimate)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Text(
              'Angka laba adalah estimasi: dihitung dari harga jual dikurangi harga modal yang tersimpan saat transaksi. Produk dengan harga modal kosong dianggap modal Rp0.',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: Colors.amber[900]),
            ),
          ),
        const SizedBox(height: 18),
        SectionHeader('Tren Harian'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 12, 6),
            child: SizedBox(height: 180, child: _LineChart(points: report.daily)),
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader('Berdasarkan Metode Pembayaran'),
        _StatList(
          rows: [
            for (final pm in report.byPaymentMethod)
              (
                pm.methodName,
                '${pm.count}x • ${money(pm.amount)}',
                pm.amount.toDouble(),
              )
          ],
          emptyText: 'Belum ada data pembayaran.',
        ),
        const SizedBox(height: 16),
        SectionHeader('Berdasarkan Kategori'),
        _StatList(
          rows: [
            for (final cat in report.byCategory)
              (
                cat.categoryName,
                '${cat.qty} item • ${money(cat.revenue)}',
                cat.revenue.toDouble(),
              )
          ],
          emptyText: 'Belum ada data kategori.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Produk Fisik',
                value: compactMoney(report.physicalRevenue),
                icon: Icons.inventory_2_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Digital & Jasa/Layanan',
                value: compactMoney(report.digitalRevenue + report.serviceRevenue),
                icon: Icons.cloud_done_outlined,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<DailyPoint> points;

  const _LineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty ||
        points.every((p) => p.revenue == 0)) {
      return Center(
          child: Text('Belum ada revenue pada periode ini',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[500])));
    }
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: double.maxFinite,
          getDrawingHorizontalLine: (v) => FlLine(
              color: const Color(0xFFF3F4F6), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${compactMoney(spot.y)}\n${dateShort(points[spot.x.toInt()].day)}',
                  const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].revenue.toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            color: AppColors.primary,
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatList extends StatelessWidget {
  final List<(String, String, double)> rows;
  final String emptyText;
  final Color color;

  const _StatList({
    required this.rows,
    required this.emptyText,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(emptyText,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
        ),
      );
    }
    final maxValue =
        rows.map((r) => r.$3).fold<double>(1, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(row.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text(row.$2,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: row.$3 / maxValue,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF3F4F6),
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashflowReportView extends StatelessWidget {
  final CashflowReport report;

  const _CashflowReportView(this.report);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Uang Masuk',
                value: compactMoney(report.totals.income),
                icon: Icons.south_west_rounded,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Uang Keluar',
                value: compactMoney(report.totals.expense),
                icon: Icons.north_east_rounded,
                color: AppColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StatCard(
          label: 'Selisih Kas (Masuk - Keluar)',
          value: compactMoney(report.net),
          icon: Icons.account_balance_wallet_outlined,
          color: report.net >= 0 ? AppColors.primary : AppColors.expense,
        ),
        const SizedBox(height: 18),
        SectionHeader('Sumber Uang Masuk'),
        _StatList(
          rows: [
            for (final entry in report.incomeByCategory.entries)
              (
                entry.key,
                money(entry.value),
                entry.value.toDouble(),
              )
          ],
          emptyText: 'Belum ada pemasukan pada periode ini.',
        ),
        const SizedBox(height: 16),
        SectionHeader('Rincian Uang Keluar'),
        _StatList(
          color: AppColors.expense,
          rows: [
            for (final entry in report.expenseByCategory.entries)
              (
                entry.key,
                money(entry.value),
                entry.value.toDouble(),
              )
          ],
          emptyText: 'Belum ada pengeluaran pada periode ini.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StockReportView extends StatelessWidget {
  final StockReport report;

  const _StockReportView(this.report);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Jumlah Produk',
                value: number(report.totalItems),
                icon: Icons.inventory_2_outlined,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Nilai Stok (estimasi)',
                value: compactMoney(report.stockValueEstimate),
                icon: Icons.savings_outlined,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
          child: Text(
            'Nilai stok = stok saat ini x harga modal. Produk tanpa harga modal memakai harga jual.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader('Perlu Restock (${report.lowStock.length})'),
        if (report.lowStock.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Semua stok aman',
            message: 'Tidak ada produk di bawah batas minimum.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final p in report.lowStock.take(20))
                  ListTile(
                    onTap: () => context.push('/products/detail/${p.id}'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    title: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5)),
                    trailing: StatusChip('${p.stock}', p.stock <= 0 ? AppColors.expense : AppColors.warning),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _PreOrderReportView extends StatelessWidget {
  final PreOrderReport report;

  const _PreOrderReportView(this.report);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Pesanan Aktif',
                value: number(report.active),
                icon: Icons.schedule_send_outlined,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'DP Terkumpul',
                value: compactMoney(report.dpCollected),
                icon: Icons.payments_rounded,
                color: AppColors.income,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Selesai',
                value: number(report.completed),
                icon: Icons.task_alt_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Dibatalkan',
                value: number(report.cancelled),
                icon: Icons.cancel_outlined,
                color: AppColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader('Jatuh Tempo ≤ 7 Hari'),
        if (report.dueSoon.isEmpty)
          const EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Tidak ada jatuh tempo dekat',
            message: 'Semua pre-order masih aman dari tenggat.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final po in report.dueSoon)
                  ListTile(
                    onTap: () => context.push('/sales/${po.id}'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    title: Text(po.customerName.isEmpty
                        ? po.transactionNumber
                        : po.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5)),
                    subtitle: Text(
                        '${po.transactionNumber} • estimasi ${dateShort(po.estimatedCompletionDate)}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                    trailing: StatusChip(po.status.label, po.status.color),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
