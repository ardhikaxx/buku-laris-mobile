import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/sale_model.dart';
import '../../shared/widgets/navigation.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SaleStatus? _statusFilter;
  OrderType? _orderTypeFilter;
  PaymentStatus? _paymentStatusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(activeWorkspaceProvider);
    final canCreate = ws.can(Permission.salesCreate);

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: const Icon(Icons.receipt_long_rounded,
              color: Colors.white, size: 20),
        ),
        titleText: 'Riwayat Penjualan',
        subtitleText: 'Kelola transaksi & pesanan pelanggan',
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(7),
                minimumSize: const Size(36, 36),
              ),
              onPressed: () => context.push('/sales/new'),
              tooltip: 'Catat Penjualan',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari no. transaksi / pelanggan / produk...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildStatusDropdown(),
                      const SizedBox(width: 8),
                      _buildOrderTypeDropdown(),
                      const SizedBox(width: 8),
                      _buildPaymentStatusDropdown(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _SalesListContent(
              key: ValueKey(
                  '$_statusFilter-$_orderTypeFilter-$_paymentStatusFilter-$_searchQuery'),
              statusFilter: _statusFilter,
              orderTypeFilter: _orderTypeFilter,
              paymentStatusFilter: _paymentStatusFilter,
              searchQuery: _searchQuery,
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'sales-fab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/sales/new'),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text('Jual',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildStatusDropdown() {
    final isSelected = _statusFilter != null;
    return PopupMenuButton<SaleStatus?>(
      tooltip: 'Filter Status Transaksi',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 42),
      onSelected: (status) => setState(() => _statusFilter = status),
      itemBuilder: (context) => [
        const PopupMenuItem<SaleStatus?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.all_inclusive_rounded,
                  size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Semua Status',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('Tampilkan semua status transaksi',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final status in SaleStatus.values)
          PopupMenuItem<SaleStatus?>(
            value: status,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status.label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(_statusDescription(status),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                if (_statusFilter == status)
                  const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.primary),
              ],
            ),
          ),
      ],
      child: _buildFilterChip(
        label: 'Status',
        activeLabel: _statusFilter?.label ?? '',
        isActive: isSelected,
        icon: Icons.flag_rounded,
        onClear: () => setState(() => _statusFilter = null),
      ),
    );
  }

  Widget _buildOrderTypeDropdown() {
    final isSelected = _orderTypeFilter != null;
    return PopupMenuButton<OrderType?>(
      tooltip: 'Filter Tipe Pesanan',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 42),
      onSelected: (type) => setState(() => _orderTypeFilter = type),
      itemBuilder: (context) => [
        const PopupMenuItem<OrderType?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Semua Tipe',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('Stok Siap & Pre-Order',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<OrderType?>(
          value: OrderType.readyStock,
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: AppColors.income),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stok Siap (Ready Stock)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Barang langsung tersedia saat transaksi',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_orderTypeFilter == OrderType.readyStock)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
        PopupMenuItem<OrderType?>(
          value: OrderType.preOrder,
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pre-Order (PO)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Pesanan dengan jadwal estimasi selesai',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_orderTypeFilter == OrderType.preOrder)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ],
      child: _buildFilterChip(
        label: 'Tipe',
        activeLabel: _orderTypeFilter == OrderType.readyStock
            ? 'Stok Siap'
            : (_orderTypeFilter == OrderType.preOrder ? 'Pre-Order' : ''),
        isActive: isSelected,
        icon: Icons.category_rounded,
        onClear: () => setState(() => _orderTypeFilter = null),
      ),
    );
  }

  Widget _buildPaymentStatusDropdown() {
    final isSelected = _paymentStatusFilter != null;
    return PopupMenuButton<PaymentStatus?>(
      tooltip: 'Filter Status Pembayaran',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 42),
      onSelected: (pay) => setState(() => _paymentStatusFilter = pay),
      itemBuilder: (context) => [
        const PopupMenuItem<PaymentStatus?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.payment_rounded, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Semua Pembayaran',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('Tampilkan semua status pembayaran',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<PaymentStatus?>(
          value: PaymentStatus.paid,
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.income),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lunas (Paid)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Pembayaran telah selesai penuh',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_paymentStatusFilter == PaymentStatus.paid)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
        PopupMenuItem<PaymentStatus?>(
          value: PaymentStatus.partial,
          child: Row(
            children: [
              const Icon(Icons.timelapse_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sebagian / DP (Partial)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Masih ada sisa tagihan pembayaran',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_paymentStatusFilter == PaymentStatus.partial)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
        PopupMenuItem<PaymentStatus?>(
          value: PaymentStatus.unpaid,
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 18, color: AppColors.expense),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Belum Bayar (Unpaid)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Belum ada uang yang dibayarkan',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_paymentStatusFilter == PaymentStatus.unpaid)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
        PopupMenuItem<PaymentStatus?>(
          value: PaymentStatus.refunded,
          child: Row(
            children: [
              const Icon(Icons.replay_rounded,
                  size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Refunded',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('Uang pembayaran telah dikembalikan',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (_paymentStatusFilter == PaymentStatus.refunded)
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ],
      child: _buildFilterChip(
        label: 'Bayar',
        activeLabel: switch (_paymentStatusFilter) {
          PaymentStatus.paid => 'Lunas',
          PaymentStatus.partial => 'Sebagian',
          PaymentStatus.unpaid => 'Belum Bayar',
          PaymentStatus.refunded => 'Refund',
          null => '',
        },
        isActive: isSelected,
        icon: Icons.payments_outlined,
        onClear: () => setState(() => _paymentStatusFilter = null),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String activeLabel,
    required bool isActive,
    required IconData icon,
    required VoidCallback onClear,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.12)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isActive ? AppColors.primary : const Color(0xFF64748B),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? '$label: $activeLabel' : label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? AppColors.primaryDark : const Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 4),
          if (isActive)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(2),
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
              size: 18,
              color: Color(0xFF94A3B8),
            ),
        ],
      ),
    );
  }

  String _statusDescription(SaleStatus status) => switch (status) {
        SaleStatus.pending => 'Menunggu konfirmasi kasir / toko',
        SaleStatus.confirmed => 'Pesanan telah diterima & dikonfirmasi',
        SaleStatus.processing => 'Sedang disiapkan / diproduksi',
        SaleStatus.ready => 'Siap untuk diambil pelanggan / dikirim',
        SaleStatus.completed => 'Transaksi selesai & barang diterima',
        SaleStatus.cancelled => 'Transaksi dibatalkan',
        SaleStatus.refunded => 'Transaksi dikembalikan dananya',
        SaleStatus.draft => 'Draf transaksi belum disimpan',
      };
}

class _SalesListContent extends ConsumerWidget {
  final SaleStatus? statusFilter;
  final OrderType? orderTypeFilter;
  final PaymentStatus? paymentStatusFilter;
  final String searchQuery;

  const _SalesListContent({
    super.key,
    required this.statusFilter,
    required this.orderTypeFilter,
    required this.paymentStatusFilter,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    if (wsId == null) return const SizedBox.shrink();

    return StreamBuilder<List<Sale>>(
      stream: ref.read(saleRepositoryProvider).watchAll(
            wsId,
            status: statusFilter,
            orderType: orderTypeFilter,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListSkeleton(itemCount: 6);
        }
        if (snapshot.hasError) {
          return ErrorStateView(
            error: snapshot.error!,
            onRetry: () {},
          );
        }
        var sales = snapshot.data ?? [];
        if (paymentStatusFilter != null) {
          sales = sales
              .where((s) => s.paymentStatus == paymentStatusFilter)
              .toList();
        }
        if (searchQuery.trim().isNotEmpty) {
          final q = searchQuery.trim().toLowerCase();
          sales = sales.where((s) {
            return s.transactionNumber.toLowerCase().contains(q) ||
                s.customerName.toLowerCase().contains(q) ||
                s.customerWhatsapp.toLowerCase().contains(q) ||
                s.notes.toLowerCase().contains(q) ||
                s.items.any((i) => i.productName.toLowerCase().contains(q));
          }).toList();
        }

        if (sales.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Tidak ada penjualan',
            message:
                'Tidak ditemukan transaksi dengan filter yang dipilih atau belum ada penjualan.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sales.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final sale = sales[index];
            return Card(
              child: ListTile(
                onTap: () => context.push('/sales/${sale.id}'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sale.transactionNumber,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusChip(_saleStatusLabel(sale.status), sale.status.color),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sale.customerName.isEmpty ? 'Tanpa pelanggan' : sale.customerName}'
                        ' • ${sale.items.length} item • ${dateTimeShort(sale.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (sale.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Keterangan: ${sale.notes}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      if (sale.offlineCreated)
                        const Row(children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 12, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text('Menunggu sinkronisasi stok',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.warning)),
                        ]),
                    ],
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(sale.grandTotal),
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark)),
                    const SizedBox(height: 2),
                    Text(
                      switch (sale.paymentStatus) {
                        PaymentStatus.paid => 'Lunas',
                        PaymentStatus.partial =>
                          'Sisa ${compactMoney(sale.remainingAmount)}',
                        PaymentStatus.unpaid => 'Belum bayar',
                        PaymentStatus.refunded => 'Refund',
                      },
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: sale.paymentStatus == PaymentStatus.paid
                            ? AppColors.income
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _saleStatusLabel(SaleStatus status) => status.label;
}
