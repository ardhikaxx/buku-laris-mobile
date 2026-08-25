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

class CashflowScreen extends ConsumerStatefulWidget {
  const CashflowScreen({super.key});

  @override
  ConsumerState<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends ConsumerState<CashflowScreen> {
  CashTransactionType _tab = CashTransactionType.income;
  DateTimeRange _range = _thisMonth();

  static DateTimeRange _thisMonth() {
    final now = DateTime.now();
    return DateTimeRange(
      start: startOfMonth(now),
      end: now.add(const Duration(minutes: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    final canManage =
        ref.watch(activeWorkspaceProvider).can(Permission.cashflowManage);

    return Scaffold(
      appBar: AppBar(title: const Text('Keuangan')),
      body: wsId == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<CashTransactionType>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                                value: CashTransactionType.income,
                                label: Text('Uang Masuk',
                                    style:
                                        TextStyle(fontSize: 12, color: _tab == CashTransactionType.income ? Colors.white : null)),
                            ),
                            ButtonSegment(
                                value: CashTransactionType.expense,
                                label: Text('Uang Keluar',
                                    style:
                                        TextStyle(fontSize: 12, color: _tab == CashTransactionType.expense ? Colors.white : null))),
                          ],
                          selected: {_tab},
                          style: SegmentedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            selectedBackgroundColor:
                                _tab == CashTransactionType.income
                                    ? AppColors.income
                                    : AppColors.expense,
                          ),
                          onSelectionChanged: (selection) =>
                              setState(() => _tab = selection.first),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Filter tanggal',
                        icon: const Icon(Icons.date_range_rounded, size: 20),
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
                ),
                Expanded(
                  child: PagedListView<CashTransaction>(
                    key: ValueKey('${_tab.name}-${_range.start}-${_range.end}'),
                    buildQuery: () => ref
                        .read(cashflowRepositoryProvider)
                        .listQuery(wsId,
                            type: _tab,
                            from: _range.start,
                            to: _range.end),
                    mapper: CashTransaction.fromDoc,
                    emptyState: EmptyState(
                      icon: _tab == CashTransactionType.income
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      title: 'Belum ada catatan',
                      message: _tab == CashTransactionType.income
                          ? 'Catat pemasukan dari penjualan, DP, atau modal masuk di sini.'
                          : 'Catat pengeluaran seperti stok, operasional, dan biaya lainnya.',
                      action: canManage
                          ? ElevatedButton.icon(
                              onPressed: () => CashFormSheet.show(context,
                                  isIncome: _tab == CashTransactionType.income),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(_tab == CashTransactionType.income
                                  ? 'Uang Masuk'
                                  : 'Uang Keluar'))
                          : null,
                    ),
                    itemBuilder: (context, txnModel, index) =>
                        _CashTile(txnModel: txnModel, canManage: canManage),
                  ),
                ),
              ],
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'cash-fab',
              backgroundColor:
                  _tab == CashTransactionType.income ? AppColors.income : AppColors.expense,
              foregroundColor: Colors.white,
              onPressed: () =>
                  CashFormSheet.show(context, isIncome: _tab == CashTransactionType.income),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Catat',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
}

class _CashTile extends ConsumerWidget {
  final CashTransaction txnModel;
  final bool canManage;

  const _CashTile({required this.txnModel, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = txnModel.type == CashTransactionType.income;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          onTap: () {
            if (txnModel.sourceSaleId.isNotEmpty) {
              context.push('/sales/${txnModel.sourceSaleId}');
            }
          },
          leading: CircleAvatar(
            radius: 19,
            backgroundColor: isIncome
                ? AppColors.income.withValues(alpha: 0.11)
                : AppColors.expense.withValues(alpha: 0.11),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isIncome ? AppColors.income : AppColors.expense,
              size: 19,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  txnModel.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isIncome ? AppColors.income : AppColors.expense),
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}${money(txnModel.amount)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (txnModel.description.isNotEmpty)
                  Text(txnModel.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (txnModel.paymentMethodName.isNotEmpty) ...[
                      Icon(Icons.credit_card, size: 11.5, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text('${txnModel.paymentMethodName} • ',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                    Text(dateShort(txnModel.occurredAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (txnModel.sourceSaleId.isNotEmpty)
                      Text(' • dari penjualan',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
          trailing: canManage && txnModel.sourceSaleId.isEmpty
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
                            '${isIncome ? '+' : '-'}${money(txnModel.amount)} — ${txnModel.category}',
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
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}
