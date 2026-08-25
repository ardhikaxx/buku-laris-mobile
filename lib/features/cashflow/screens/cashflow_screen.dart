import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/cash_transaction_model.dart';
import '../../../models/enums.dart';
import '../../shared/widgets/navigation.dart';
import '../widgets/cash_form_sheet.dart';

enum _CashTab { income, expense }

class CashflowScreen extends ConsumerStatefulWidget {
  const CashflowScreen({super.key});

  @override
  ConsumerState<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends ConsumerState<CashflowScreen> {
  _CashTab _tab = _CashTab.income;
  DateTimeRange _range = _thisMonth();

  static DateTimeRange _thisMonth() {
    final now = DateTime.now();
    return DateTimeRange(
      start: startOfMonth(now),
      end: now.add(const Duration(minutes: 1)),
    );
  }

  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    final canManage =
        ref.watch(activeWorkspaceProvider).can(Permission.cashflowManage);

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.income.withValues(alpha: 0.12),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.income, size: 20),
        ),
        titleText: 'Keuangan & Arus Kas',
        subtitleText: 'Rekap mutasi kas masuk & keluar',
        actions: [
          IconButton(
            tooltip: 'Filter Tanggal',
            icon: const Icon(Icons.date_range_rounded, size: 19),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(7),
              minimumSize: const Size(36, 36),
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _range,
                locale: const Locale('id', 'ID'),
              );
              if (picked != null) {
                setState(() {
                  _range = DateTimeRange(
                    start: picked.start,
                    end: endOfDay(picked.end),
                  );
                });
              }
            },
          ),
        ],
      ),
      body: wsId == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<CashTransaction>>(
              stream: ref.watch(cashflowRepositoryProvider).watchAll(
                    wsId,
                    from: _range.start,
                    to: _range.end,
                  ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListSkeleton(itemCount: 6);
                }
                if (snapshot.hasError) {
                  return ErrorStateView(
                    error: snapshot.error!,
                    onRetry: () => setState(() {}),
                  );
                }

                final allItems = snapshot.data ?? [];

                final refundedSaleIds = <String>{};
                for (final t in allItems) {
                  if ((t.sourceType == 'REFUND' ||
                          t.category.toLowerCase().contains('refund') ||
                          t.category.toLowerCase().contains('batal')) &&
                      t.sourceSaleId.isNotEmpty) {
                    refundedSaleIds.add(t.sourceSaleId);
                  }
                }

                // Active items for total calculations (exclude refunded transactions so they don't count in Uang Masuk / Keluar)
                final activeItems = allItems.where((t) {
                  if (t.sourceSaleId.isNotEmpty &&
                      refundedSaleIds.contains(t.sourceSaleId)) {
                    return false;
                  }
                  return true;
                }).toList();

                final totalIncome = activeItems
                    .where((t) => t.type == CashTransactionType.income)
                    .fold(0, (acc, t) => acc + t.amount);
                final totalExpense = activeItems
                    .where((t) => t.type == CashTransactionType.expense)
                    .fold(0, (acc, t) => acc + t.amount);
                final netCash = totalIncome - totalExpense;

                final filteredItems = allItems.where((t) {
                  if (_tab == _CashTab.income) {
                    return t.type == CashTransactionType.income;
                  } else {
                    return t.type == CashTransactionType.expense;
                  }
                }).toList();

                return Column(
                  children: [
                    // Financial Summary Card
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Periode: ${dateShort(_range.start)} - ${dateShort(_range.end)}',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600]),
                                    ),
                                    Text(
                                      '${allItems.length} Catatan',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.south_west_rounded,
                                                  size: 13,
                                                  color: AppColors.income),
                                              const SizedBox(width: 4),
                                              Text('Uang Masuk',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            money(totalIncome),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.income,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 32,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.north_east_rounded,
                                                  size: 13,
                                                  color: AppColors.expense),
                                              const SizedBox(width: 4),
                                              Text('Uang Keluar',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            money(totalExpense),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.expense,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 32,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .account_balance_wallet_outlined,
                                                  size: 13,
                                                  color: netCash >= 0
                                                      ? AppColors.primary
                                                      : AppColors.expense),
                                              const SizedBox(width: 4),
                                              Text('Sisa Kas',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            money(netCash),
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: netCash >= 0
                                                  ? AppColors.primary
                                                  : AppColors.expense,
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
                          const SizedBox(height: 10),
                          // Tab Selector (2 Tabs only: Uang Masuk & Uang Keluar)
                          SegmentedButton<_CashTab>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: _CashTab.income,
                                label: Text(
                                  'Uang Masuk (${allItems.where((t) => t.type == CashTransactionType.income).length})',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _tab == _CashTab.income
                                          ? Colors.white
                                          : null),
                                ),
                              ),
                              ButtonSegment(
                                value: _CashTab.expense,
                                label: Text(
                                  'Uang Keluar (${allItems.where((t) => t.type == CashTransactionType.expense).length})',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _tab == _CashTab.expense
                                          ? Colors.white
                                          : null),
                                ),
                              ),
                            ],
                            selected: {_tab},
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              selectedBackgroundColor: _tab == _CashTab.income
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                            onSelectionChanged: (selection) =>
                                setState(() => _tab = selection.first),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? EmptyState(
                              icon: _tab == _CashTab.income
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              title: _tab == _CashTab.income
                                  ? 'Belum ada uang masuk'
                                  : 'Belum ada uang keluar',
                              message: _tab == _CashTab.income
                                  ? 'Belum ada catatan pemasukan di periode ini.'
                                  : 'Belum ada catatan pengeluaran di periode ini.',
                              action: canManage
                                  ? ElevatedButton.icon(
                                      onPressed: () => CashFormSheet.show(
                                          context,
                                          isIncome:
                                              _tab == _CashTab.income),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: Text(_tab == _CashTab.income
                                          ? 'Catat Uang Masuk'
                                          : 'Catat Uang Keluar'))
                                  : null,
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final txn = filteredItems[index];
                                final isVoided = txn.sourceSaleId.isNotEmpty &&
                                    refundedSaleIds.contains(txn.sourceSaleId);
                                return _CashTile(
                                  txnModel: txn,
                                  canManage: canManage,
                                  isRefundedOrVoided: isVoided,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'cash-fab',
              backgroundColor: _tab == _CashTab.income
                  ? AppColors.income
                  : AppColors.expense,
              foregroundColor: Colors.white,
              onPressed: () => CashFormSheet.show(context,
                  isIncome: _tab == _CashTab.income),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                _tab == _CashTab.income
                    ? 'Catat Uang Masuk'
                    : 'Catat Uang Keluar',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _CashTile extends ConsumerWidget {
  final CashTransaction txnModel;
  final bool canManage;
  final bool isRefundedOrVoided;

  const _CashTile({
    required this.txnModel,
    required this.canManage,
    this.isRefundedOrVoided = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = txnModel.type == CashTransactionType.income;
    final isSaleLinked = txnModel.sourceSaleId.isNotEmpty;
    final isRefundEntry = txnModel.sourceType == 'REFUND' ||
        txnModel.category.toLowerCase().contains('refund') ||
        txnModel.category.toLowerCase().contains('batal');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRefundedOrVoided
              ? Colors.grey.shade300
              : (isIncome
                  ? AppColors.income.withValues(alpha: 0.2)
                  : AppColors.expense.withValues(alpha: 0.2)),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          if (isSaleLinked) {
            context.push('/sales/${txnModel.sourceSaleId}');
          }
        },
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: isRefundedOrVoided
              ? Colors.grey.shade200
              : (isIncome
                  ? AppColors.income.withValues(alpha: 0.12)
                  : AppColors.expense.withValues(alpha: 0.12)),
          child: Icon(
            isRefundedOrVoided
                ? (isRefundEntry ? Icons.replay_rounded : Icons.cancel_outlined)
                : (isIncome
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded),
            color: isRefundedOrVoided
                ? Colors.grey.shade600
                : (isIncome ? AppColors.income : AppColors.expense),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      txnModel.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isRefundedOrVoided
                            ? Colors.grey[600]
                            : const Color(0xFF1E293B),
                        decoration: isRefundedOrVoided && !isRefundEntry
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (isRefundedOrVoided) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isRefundEntry ? 'REFUND' : 'BATAL/REFUND',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ] else if (isSaleLinked) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PENJUALAN',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isIncome ? '+' : '-'}${money(txnModel.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isRefundedOrVoided
                    ? Colors.grey[500]
                    : (isIncome ? AppColors.income : AppColors.expense),
                decoration: isRefundedOrVoided && !isRefundEntry
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isRefundedOrVoided)
                Text(
                  isRefundEntry
                      ? 'Dana kas telah dikembalikan ke pelanggan (tidak dihitung di kas)'
                      : 'Transaksi dibatalkan / refund (tidak dihitung di Uang Masuk)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange[800],
                  ),
                )
              else if (txnModel.description.isNotEmpty)
                Text(
                  txnModel.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (txnModel.paymentMethodName.isNotEmpty) ...[
                    Icon(Icons.credit_card_rounded,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(
                      '${txnModel.paymentMethodName} \u2022 ',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  Text(
                    dateTimeShort(txnModel.occurredAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (isSaleLinked) ...[
                    const Spacer(),
                    const Text(
                      'Lihat Struk \u203A',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        trailing: canManage && !isSaleLinked
            ? PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await CashFormSheet.show(context,
                        isIncome: isIncome, existing: txnModel);
                  } else if (value == 'delete') {
                    final confirmed = await confirmAction(
                      context,
                      title: 'Hapus catatan kas?',
                      message:
                          '${isIncome ? '+' : '-'}${money(txnModel.amount)} \u2014 ${txnModel.category}',
                      destructive: true,
                    );
                    if (!confirmed) return;
                    try {
                      await ref
                          .read(cashflowRepositoryProvider)
                          .delete(txnModel);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(mapToAppException(e).message),
                          backgroundColor: AppColors.expense,
                        ));
                      }
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus',
                          style: TextStyle(color: AppColors.expense))),
                ],
              )
            : null,
      ),
    );
  }
}
