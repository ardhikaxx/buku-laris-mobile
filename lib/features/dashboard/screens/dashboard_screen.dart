import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../repositories/dashboard_repository.dart';
import '../../../services/connectivity_service.dart';
import '../../shared/widgets/navigation.dart';

enum DashboardPeriod { today, week, month, custom }

extension on DashboardPeriod {
  String get label => switch (this) {
        DashboardPeriod.today => 'Hari Ini',
        DashboardPeriod.week => 'Minggu Ini',
        DashboardPeriod.month => 'Bulan Ini',
        DashboardPeriod.custom => 'Kustom',
      };

  IconData get icon => switch (this) {
        DashboardPeriod.today => Icons.today_rounded,
        DashboardPeriod.week => Icons.date_range_rounded,
        DashboardPeriod.month => Icons.calendar_month_rounded,
        DashboardPeriod.custom => Icons.tune_rounded,
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
  String? _loadedForWsId;
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _subscribeRealtime();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    _realtimeSub?.cancel();
    if (wsId == null) return;
    _realtimeSub = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(wsId)
        .collection('dailySummaries')
        .snapshots()
        .listen((_) {
      if (mounted) _load(force: true);
    });
  }

  void _load({bool force = false}) {
    final state = ref.read(activeWorkspaceProvider);
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    if (wsId == null) return;
    if (!force && _loadedForWsId == wsId && _future != null && _error == null) return;
    _loadedForWsId = wsId;
    final includeFinance = state.member?.isOwner ?? false;
    setState(() {
      _error = null;
      _future = ref
          .read(dashboardRepositoryProvider)
          .load(wsId: wsId, includeFinance: includeFinance, range: _range);
    });
  }

  Future<void> _openCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
      locale: const Locale('id', 'ID'),
      helpText: 'PILIH RENTANG TANGGAL',
      cancelText: 'BATAL',
      confirmText: 'TERAPKAN',
      saveText: 'PILIH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: const Color(0xFF1E293B),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _period = DashboardPeriod.custom;
      _range = AppDateRange(
        start: startOfDay(picked.start),
        end: endOfDay(picked.end),
      );
    });
    _load(force: true);
  }

  void _selectPeriod(DashboardPeriod period) {
    if (period == DashboardPeriod.custom) {
      _openCustomDatePicker();
      return;
    }
    setState(() {
      _period = period;
      _range = switch (period) {
        DashboardPeriod.today => AppDateRange.today(),
        DashboardPeriod.week => AppDateRange.thisWeek(),
        _ => AppDateRange.thisMonth(),
      };
    });
    _load(force: true);
  }

  String _getRangeLabel() {
    switch (_period) {
      case DashboardPeriod.today:
        return 'Hari ini • ${dateShort(_range.start)}';
      case DashboardPeriod.week:
        return '${dateShort(_range.start)} \u2013 ${dateShort(_range.end)}';
      case DashboardPeriod.month:
        return monthYear(_range.start);
      case DashboardPeriod.custom:
        return '${dateShort(_range.start)} \u2013 ${dateShort(_range.end)}';
    }
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

    if (gate.activeWorkspaceId != _loadedForWsId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    if (workspace == null && active.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.storefront_rounded,
              color: AppColors.primary, size: 20),
        ),
        titleText: workspace?.name ?? 'Buku Laris',
        subtitleText:
            '${member?.role.label ?? ''} \u2022 ${gate.profile?.displayName ?? ''}',
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, size: 21),
                ValueListenableBuilder<bool>(
                  valueListenable: ConnectivityService.instance.isOnline,
                  builder: (context, offline, _) => offline
                      ? Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
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
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(7),
              minimumSize: const Size(36, 36),
            ),
            onPressed: () => context.push('/notifications'),
          ),
          if (isOwner) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(7),
                minimumSize: const Size(36, 36),
              ),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(force: true),
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
        _buildPeriodFilter(context),
        const SizedBox(height: 14),
        if (_error != null)
          ErrorStateView(error: _error!, onRetry: () => _load(force: true))
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
                return ErrorStateView(
                    error: snapshot.error!,
                    onRetry: () => _load(force: true));
              }
              final data = snapshot.data!;
              return _DashboardContent(
                data: data,
                isOwner: isOwner,
                isEmployee: isEmployee,
                canManageProducts:
                    ref.read(activeWorkspaceProvider).can(Permission.productsManage),
                periodLabel: _period.label,
              );
            },
          ),
      ],
    );
  }

  Widget _buildPeriodFilter(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final p in DashboardPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildPeriodChip(p),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getRangeLabel(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                if (_period == DashboardPeriod.custom)
                  InkWell(
                    onTap: _openCustomDatePicker,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_calendar_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Ubah',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(DashboardPeriod p) {
    final isSelected = _period == p;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectPeriod(p),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                p.icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                p.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final bool isOwner;
  final bool isEmployee;
  final bool canManageProducts;
  final String periodLabel;

  const _DashboardContent({
    required this.data,
    required this.isOwner,
    required this.isEmployee,
    required this.canManageProducts,
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
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Arus Kas Bersih (bulan ini)',
                  value: compactMoney(data.monthCashIn - data.monthCashOut),
                  icon: Icons.account_balance_wallet_outlined,
                  color: (data.monthCashIn - data.monthCashOut) >= 0
                      ? AppColors.primary
                      : AppColors.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: data.profitHasUnknownCosts
                      ? 'Estimasi Keuntungan*'
                      : 'Estimasi Keuntungan',
                  value: compactMoney(data.monthProfitEstimate),
                  icon: Icons.savings_outlined,
                  color: AppColors.accent,
                  sublabel: data.profitHasUnknownCosts
                      ? '*modal belum lengkap'
                      : null,
                ),
              ),
            ],
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
        if (data.periodOrders == 0 && data.productCount == 0) ...[
          Card(
            color: const Color(0xFFF0FDFA),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.rocket_launch_outlined,
                      size: 34, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text('Mulai dari sini!',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.teal[900])),
                  const SizedBox(height: 6),
                  Text(
                    'Usaha Anda baru dibuat sehingga semua angka masih nol. '
                    'Tambahkan produk atau layanan pertama, lalu catat penjualan lewat tombol Aksi Cepat di bawah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.55, color: Colors.grey[700]),
                  ),
                  if (canManageProducts) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(42)),
                      onPressed: () => context.push('/products/new'),
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      label: const Text('Tambah Produk Pertama'),
                    ),
                  ],
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
    if (points.isEmpty || points.every((p) => p.revenue == 0)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 34, color: Colors.grey[350]),
            const SizedBox(height: 8),
            Text('Grafik akan terisi setelah ada penjualan',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
          ],
        ),
      );
    }
    final maxY = points.map((p) => p.revenue).fold<int>(0, max) * 1.15;
    final step = points.length > 10 ? (points.length ~/ 5).clamp(1, 100) : 1;

    return BarChart(
      key: ValueKey(
          'rev_chart_${points.length}_${points.isNotEmpty ? points.first.day.millisecondsSinceEpoch : 0}'),
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        alignment: BarChartAlignment.spaceAround,
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
                if (points.length > 10 &&
                    index % step != 0 &&
                    index != points.length - 1) {
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
              final idx = group.x.toInt();
              if (idx < 0 || idx >= points.length) return null;
              final point = points[idx];
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
                  width: points.length > 20
                      ? 6
                      : (points.length == 1
                          ? 28
                          : (points.length < 8 ? 18 : 12)),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
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
    return const Column(
      children: [
        SkeletonBox(height: 96, radius: 14),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
          ],
        ),
        SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: SkeletonBox(height: 14)),
        SizedBox(height: 10),
        SkeletonBox(height: 190, radius: 14),
      ],
    );
  }
}
