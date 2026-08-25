import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../repositories/dashboard_repository.dart';
import '../../../services/connectivity_service.dart';
import '../../../services/logger.dart';
import '../../shared/widgets/navigation.dart';

enum DashboardPeriod { today, week, month, custom }

extension on DashboardPeriod {
  String get label => switch (this) {
        DashboardPeriod.today => 'Hari Ini',
        DashboardPeriod.week => 'Minggu Ini',
        DashboardPeriod.month => 'Bulan Ini',
        DashboardPeriod.custom => 'Kustom',
      };
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.month;
  AppDateRange _range = AppDateRange.thisMonth();
  Future<DashboardData>? _future;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final state = ref.read(activeWorkspaceProvider);
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    if (wsId == null) return;
    final includeFinance = state.member?.isOwner ?? false;
    setState(() {
      _error = null;
      _future = ref
          .read(dashboardRepositoryProvider)
          .load(wsId: wsId, includeFinance: includeFinance, range: _range)
          .catchError((e) {
        Logger.e('dashboard load failed', e);
        throw e is AppException ? e : mapToAppException(e);
      });
    });
  }

  void _selectPeriod(DashboardPeriod period) async {
    if (period == DashboardPeriod.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
        locale: const Locale('id', 'ID'),
      );
      if (picked == null) return;
      setState(() {
        _period = period;
        _range = AppDateRange(
            start: startOfDay(picked.start), end: endOfDay(picked.end));
      });
    } else {
      setState(() {
        _period = period;
        _range = switch (period) {
          DashboardPeriod.today => AppDateRange.today(),
          DashboardPeriod.week => AppDateRange.thisWeek(),
          _ => AppDateRange.thisMonth(),
        };
      });
    }
    _load();
  }

  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeWorkspaceProvider);
    final gate = ref.watch(gateProvider);
    final workspace = active.workspace;
    final member = active.member;
    final isOwner = member?.isOwner ?? false;

    if (workspace == null && active.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workspace?.name ?? 'Buku Laris',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16)),
                  Text(
                    '${member?.role.label ?? ''} \u2022 ${gate.profile?.displayName ?? ''}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, size: 24),
                  ValueListenableBuilder<bool>(
                    valueListenable: ConnectivityService.instance.isOnline,
                    builder: (context, offline, _) => offline
                        ? Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: AppColors.expense,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              onPressed: () => context.push('/notifications'),
            ),
          ],
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              onPressed: () => context.push('/settings'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: _buildBody(context, isOwner, member?.role == UserRole.EMPLOYEE),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => showQuickActions(context),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('Aksi Cepat',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isOwner, bool isEmployee) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in DashboardPeriod.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: _period == p,
                    onSelected: (_) => _selectPeriod(p),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null)
          ErrorStateView(error: _error!, onRetry: _load)
        else if (_future == null)
          const SizedBox(height: 200)
        else
          FutureBuilder<DashboardData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _DashboardSkeleton();
              }
              if (snapshot.hasError) {
                return ErrorStateView(error: snapshot.error!, onRetry: _load);
              }
              final data = snapshot.data!;
              return _DashboardContent(
                data: data,
                isOwner: isOwner,
                isEmployee: isEmployee,
                periodLabel: _period.label,
              );
            },
          ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final bool isOwner;
  final bool isEmployee;
  final String periodLabel;

  const _DashboardContent({
    required this.data,
    required this.isOwner,
    required this.isEmployee,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOwner) ...[
          Card(
            color: AppColors.primary,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text('Penjualan $periodLabel',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(compactMoney(data.periodRevenue),
                      style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(
                    '${data.periodOrders} transaksi selesai',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Penjualan Hari Ini',
                  value: compactMoney(data.todayRevenue),
                  icon: Icons.today_rounded,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Penjualan Bulan Ini',
                  value: compactMoney(data.monthRevenue),
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Uang Masuk (bulan ini)',
                  value: compactMoney(data.monthCashIn),
                  icon: Icons.south_west_rounded,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Uang Keluar (bulan ini)',
                  value: compactMoney(data.monthCashOut),
                  icon: Icons.north_east_rounded,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatCard(
            label: data.profitHasUnknownCosts
                ? 'Estimasi Keuntungan (bulan ini)*'
                : 'Keuntungan (bulan ini)',
            value: compactMoney(data.monthProfitEstimate),
            icon: Icons.savings_outlined,
            color: AppColors.accent,
            sublabel: data.profitHasUnknownCosts
                ? '*beberapa produk belum punya harga modal'
                : null,
          ),
          const SizedBox(height: 18),
        ] else ...[
          Card(
            color: AppColors.primary,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pesanan Berjalan',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('${data.activeOrders} pesanan',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.pending_actions_rounded,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        SectionHeader('Grafik Penjualan ($periodLabel)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
            child: SizedBox(height: 170, child: _RevenueChart(points: data.chart)),
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          'Pesanan & Stok',
          actionLabel: isOwner ? 'Kelola' : null,
          onAction: isOwner ? () => context.push('/inventory/low-stock') : null,
        ),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Pesanan Berjalan',
                value: number(data.activeOrders),
                icon: Icons.local_shipping_outlined,
                color: AppColors.info,
                onTap: () => context.go('/sales'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: data.activePreOrders > 0
                    ? 'Pre-Order Aktif'
                    : 'Jumlah Produk',
                value: data.activePreOrders > 0
                    ? number(data.activePreOrders)
                    : number(data.productCount),
                icon: data.activePreOrders > 0
                    ? Icons.schedule_send_outlined
                    : Icons.inventory_2_outlined,
                color: const Color(0xFF7C3AED),
                onTap: () => context.go('/products'),
              ),
            ),
          ],
        ),
        if ((isOwner || isEmployee) && data.lowStockPreview.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionHeader('Stok Menipis',
              actionLabel: 'Lihat Semua',
              onAction: () => context.push('/inventory/low-stock')),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < data.lowStockPreview.length; i++) ...[
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    dense: true,
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          size: 17, color: AppColors.expense),
                    ),
                    title: Text(
                      data.lowStockPreview[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      'sisa ${data.lowStockPreview[i].stock}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: data.lowStockPreview[i].stock == 0
                              ? AppColors.expense
                              : AppColors.warning),
                    ),
                  ),
                  if (i < data.lowStockPreview.length - 1)
                    const Divider(indent: 14, endIndent: 14),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<DailyPoint> points;

  const _RevenueChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
          child: Text('Belum ada data penjualan',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[500])));
    }
    final maxY = points.map((p) => p.revenue).fold<int>(0, max) * 1.15;
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final day = points[index].day;
                if (points.length > 10 && index % 5 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${day.day}/${day.month}',
                      style:
                          TextStyle(fontSize: 9.5, color: Colors.grey[500])),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x.toInt()];
              return BarTooltipItem(
                '${compactMoney(point.revenue)}\n${dateShort(point.day)}',
                const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].revenue.toDouble(),
                  width: points.length > 20 ? 6 : 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  color: points[i].revenue > 0
                      ? AppColors.primary
                      : Colors.grey[300],
                ),
              ],
            ),
        ],
        maxY: maxY <= 0 ? 100 : maxY,
      ),
    );
  }

  int max(int a, int b) => a > b ? a : b;
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonBox(height: 96, radius: 14),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: SkeletonBox(height: 84, radius: 14)),
            const SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: SkeletonBox(height: 84, radius: 14)),
            const SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
          ],
        ),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: SkeletonBox(height: 14)),
        const SizedBox(height: 10),
        const SkeletonBox(height: 190, radius: 14),
      ],
    );
  }
}
