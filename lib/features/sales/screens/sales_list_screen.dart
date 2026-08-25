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
  SaleStatus? _statusFilter;
  OrderType? _orderTypeFilter;

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(activeWorkspaceProvider);
    final canCreate = ws.can(Permission.salesCreate);

    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('Semua', null),
                        ...SaleStatus.values.map((s) => _chip(s.label, s)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua Jenis'),
                  selected: _orderTypeFilter == null,
                  onSelected: (_) => _applyOrderType(null),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Stok Siap'),
                  selected: _orderTypeFilter == OrderType.readyStock,
                  onSelected: (_) => _applyOrderType(OrderType.readyStock),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Pre-Order'),
                  selected: _orderTypeFilter == OrderType.preOrder,
                  onSelected: (_) => _applyOrderType(OrderType.preOrder),
                ),
              ],
            ),
          ),
          Expanded(
            child: _SalesListContent(
              key: ValueKey('$_statusFilter-$_orderTypeFilter'),
              statusFilter: _statusFilter,
              orderTypeFilter: _orderTypeFilter,
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

  Widget _chip(String label, SaleStatus? status) {
    final selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _statusFilter = status);
        },
      ),
    );
  }

  void _applyOrderType(OrderType? type) {
    setState(() => _orderTypeFilter = type);
  }
}

class _SalesListContent extends ConsumerWidget {
  final SaleStatus? statusFilter;
  final OrderType? orderTypeFilter;

  const _SalesListContent({
    super.key,
    required this.statusFilter,
    required this.orderTypeFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    if (wsId == null) return const SizedBox.shrink();

    return PagedListView<Sale>(
      buildQuery: () => ref
          .read(saleRepositoryProvider)
          .listQuery(wsId, status: statusFilter, orderType: orderTypeFilter),
      mapper: Sale.fromDoc,
      emptyState: const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada penjualan',
        message:
            'Transaksi yang Anda buat akan muncul di sini. Tekan tombol Jual untuk mencatat penjualan pertama.',
      ),
      itemBuilder: (context, sale, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
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
                    Row(children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 12, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text('Menunggu sinkronisasi stok',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.warning)),
                    ]),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(sale.grandTotal),
                    style: TextStyle(
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
        ),
      ),
    );
  }

  String _saleStatusLabel(SaleStatus status) => status.label;
}
