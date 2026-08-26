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
      child: _buildPeriodDropdown(),
    );
  }

  Widget _buildPeriodDropdown() {
    final isCustomOrNotDefault = _period != DashboardPeriod.month;
    return PopupMenuButton<DashboardPeriod>(
      tooltip: 'Pilih Periode Dashboard',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 48),
      onSelected: (period) => _selectPeriod(period),
      itemBuilder: (context) => [
        const PopupMenuItem<DashboardPeriod>(
          enabled: false,
          child: Text(
            'PILIH PERIODE DASHBOARD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<DashboardPeriod>(
          value: DashboardPeriod.today,
          child: Row(
            children: [
              const Icon(Icons.today_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hari Ini',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Menampilkan penjualan & transaksi hari ini',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_period == DashboardPeriod.today)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
        PopupMenuItem<DashboardPeriod>(
          value: DashboardPeriod.week,
          child: Row(
            children: [
              const Icon(Icons.date_range_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Minggu Ini',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Akumulasi dari awal minggu hingga hari ini',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_period == DashboardPeriod.week)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
        PopupMenuItem<DashboardPeriod>(
          value: DashboardPeriod.month,
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulan Ini',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Total ringkasan selama bulan berjalan',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_period == DashboardPeriod.month)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
        PopupMenuItem<DashboardPeriod>(
          value: DashboardPeriod.custom,
          child: Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kustom (Pilih Rentang)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Tentukan sendiri tanggal awal & akhir',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_period == DashboardPeriod.custom)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCustomOrNotDefault
              ? AppColors.primary.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCustomOrNotDefault
                ? AppColors.primary
                : const Color(0xFFE2E8F0),
            width: isCustomOrNotDefault ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isCustomOrNotDefault
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _period.icon,
                size: 16,
                color: isCustomOrNotDefault
                    ? AppColors.primary
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Periode: ${_period.label}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isCustomOrNotDefault
                          ? FontWeight.w800
                          : FontWeight.w700,
                      color: isCustomOrNotDefault
                          ? AppColors.primaryDark
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _getRangeLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isCustomOrNotDefault
                          ? AppColors.primary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isCustomOrNotDefault)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectPeriod(DashboardPeriod.month),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 22,
                color: Color(0xFF94A3B8),
              ),
          ],
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF0D9488),
                  Color(0xFF14B8A6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned(
                    right: -25,
                    top: -25,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 45,
                    bottom: -35,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -30,
                    child: Container(
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.trending_up_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Penjualan $periodLabel',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          compactMoney(data.periodRevenue),
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.receipt_rounded,
                                      color: Colors.white70, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${data.periodOrders} Transaksi Selesai',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF0D9488),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Pesanan Berjalan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${data.activeOrders} Pesanan',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.pending_actions_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ],
                    ),
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
        SkeletonBox(height: 140, radius: 20),
        SizedBox(height: 12),
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
