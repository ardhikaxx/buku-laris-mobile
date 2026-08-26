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

class _WalletSummary {
  final String name;
  final int startingBalance;
  final int periodIncome;
  final int periodExpense;
  final int endingBalance;
  final IconData icon;
  final Color color;

  const _WalletSummary({
    required this.name,
    required this.startingBalance,
    required this.periodIncome,
    required this.periodExpense,
    required this.endingBalance,
    required this.icon,
    required this.color,
  });
}

class CashflowScreen extends ConsumerStatefulWidget {
  const CashflowScreen({super.key});

  @override
  ConsumerState<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends ConsumerState<CashflowScreen> {
  _CashTab _tab = _CashTab.income;
  DateTimeRange _range = _thisMonth();
  String? _selectedWallet; // null = Semua Akun / Dompet

  static DateTimeRange _thisMonth() {
    final now = DateTime.now();
    return DateTimeRange(
      start: startOfMonth(now),
      end: now.add(const Duration(minutes: 1)),
    );
  }

  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59);

  IconData _resolveWalletIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tunai') || lower.contains('cash')) {
      return Icons.payments_rounded;
    }
    if (lower.contains('bri') ||
        lower.contains('bca') ||
        lower.contains('bank') ||
        lower.contains('transfer') ||
        lower.contains('mandiri') ||
        lower.contains('bni')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('qris')) {
      return Icons.qr_code_2_rounded;
    }
    if (lower.contains('wallet') ||
        lower.contains('gopay') ||
        lower.contains('ovo') ||
        lower.contains('dana') ||
        lower.contains('shopee')) {
      return Icons.phone_android_rounded;
    }
    return Icons.account_balance_wallet_rounded;
  }

  Color _resolveWalletColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tunai') || lower.contains('cash')) {
      return const Color(0xFF16A34A); // Green
    }
    if (lower.contains('bri') ||
        lower.contains('bca') ||
        lower.contains('bank') ||
        lower.contains('transfer')) {
      return AppColors.primary; // Royal Blue BRI
    }
    if (lower.contains('qris')) {
      return const Color(0xFFEA580C); // Orange QRIS
    }
    if (lower.contains('wallet') ||
        lower.contains('gopay') ||
        lower.contains('ovo') ||
        lower.contains('dana') ||
        lower.contains('shopee')) {
      return const Color(0xFF0284C7); // Cyan
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    final canManage =
        ref.watch(activeWorkspaceProvider).can(Permission.cashflowManage);

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 20),
        ),
        titleText: 'Keuangan & Arus Kas',
        subtitleText: 'Rekap mutasi kas masuk & keluar',
        actions: [
          IconButton(
            tooltip: 'Filter Tanggal',
            icon: const Icon(Icons.date_range_rounded, size: 19),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
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
              stream: ref.watch(cashflowRepositoryProvider).watchAll(wsId),
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

                final allWorkspaceTxns = snapshot.data ?? [];

                // 1. Identify refunded / voided sale IDs
                final refundedSaleIds = <String>{};
                for (final t in allWorkspaceTxns) {
                  if ((t.sourceType == 'REFUND' ||
                          t.category.toLowerCase().contains('refund') ||
                          t.category.toLowerCase().contains('batal')) &&
                      t.sourceSaleId.isNotEmpty) {
                    refundedSaleIds.add(t.sourceSaleId);
                  }
                }

                // 2. Separate prior transactions (before start date) for Saldo Awal
                final priorActiveTxns = allWorkspaceTxns.where((t) {
                  if (t.sourceSaleId.isNotEmpty &&
                      refundedSaleIds.contains(t.sourceSaleId)) {
                    return false;
                  }
                  return t.occurredAt.isBefore(_range.start);
                }).toList();

                final startingIncome = priorActiveTxns
                    .where((t) => t.type == CashTransactionType.income)
                    .fold(0, (acc, t) => acc + t.amount);
                final startingExpense = priorActiveTxns
                    .where((t) => t.type == CashTransactionType.expense)
                    .fold(0, (acc, t) => acc + t.amount);
                final startingBalance = startingIncome - startingExpense;

                // 3. Transactions inside the selected period
                final fromMs = _range.start.millisecondsSinceEpoch;
                final toMs = _range.end.millisecondsSinceEpoch;
                final periodTxns = allWorkspaceTxns.where((t) {
                  final ms = t.occurredAt.millisecondsSinceEpoch;
                  return ms >= fromMs && ms <= toMs;
                }).toList();

                final periodActiveTxns = periodTxns.where((t) {
                  if (t.sourceSaleId.isNotEmpty &&
                      refundedSaleIds.contains(t.sourceSaleId)) {
                    return false;
                  }
                  return true;
                }).toList();

                final periodIncome = periodActiveTxns
                    .where((t) => t.type == CashTransactionType.income)
                    .fold(0, (acc, t) => acc + t.amount);
                final periodExpense = periodActiveTxns
                    .where((t) => t.type == CashTransactionType.expense)
                    .fold(0, (acc, t) => acc + t.amount);
                final netChange = periodIncome - periodExpense;
                final endingBalance = startingBalance + netChange;

                // 4. Multi-wallet / account summaries
                final walletNames = <String>{'Tunai'};
                for (final t in allWorkspaceTxns) {
                  final wName = t.paymentMethodName.trim().isEmpty
                      ? 'Tunai'
                      : t.paymentMethodName.trim();
                  walletNames.add(wName);
                }

                final walletSummaries = <_WalletSummary>[];
                for (final wName in walletNames) {
                  final wPrior = priorActiveTxns.where((t) {
                    final n = t.paymentMethodName.trim().isEmpty
                        ? 'Tunai'
                        : t.paymentMethodName.trim();
                    return n.toLowerCase() == wName.toLowerCase();
                  });
                  final wStartIncome = wPrior
                      .where((t) => t.type == CashTransactionType.income)
                      .fold(0, (acc, t) => acc + t.amount);
                  final wStartExpense = wPrior
                      .where((t) => t.type == CashTransactionType.expense)
                      .fold(0, (acc, t) => acc + t.amount);
                  final wStart = wStartIncome - wStartExpense;

                  final wPeriod = periodActiveTxns.where((t) {
                    final n = t.paymentMethodName.trim().isEmpty
                        ? 'Tunai'
                        : t.paymentMethodName.trim();
                    return n.toLowerCase() == wName.toLowerCase();
                  });
                  final wIncome = wPeriod
                      .where((t) => t.type == CashTransactionType.income)
                      .fold(0, (acc, t) => acc + t.amount);
                  final wExpense = wPeriod
                      .where((t) => t.type == CashTransactionType.expense)
                      .fold(0, (acc, t) => acc + t.amount);
                  final wEnd = wStart + wIncome - wExpense;

                  // Include wallet if it has any balance or activity
                  if (wName == 'Tunai' ||
                      wStart != 0 ||
                      wIncome != 0 ||
                      wExpense != 0 ||
                      wEnd != 0) {
                    walletSummaries.add(_WalletSummary(
                      name: wName,
                      startingBalance: wStart,
                      periodIncome: wIncome,
                      periodExpense: wExpense,
                      endingBalance: wEnd,
                      icon: _resolveWalletIcon(wName),
                      color: _resolveWalletColor(wName),
                    ));
                  }
                }

                // 5. Filtered items for list view
                final filteredItems = periodTxns.where((t) {
                  // Tab filter
                  if (_tab == _CashTab.income &&
                      t.type != CashTransactionType.income) {
                    return false;
                  }
                  if (_tab == _CashTab.expense &&
                      t.type != CashTransactionType.expense) {
                    return false;
                  }

                  // Wallet filter
                  if (_selectedWallet != null) {
                    final wName = t.paymentMethodName.trim().isEmpty
                        ? 'Tunai'
                        : t.paymentMethodName.trim();
                    if (wName.toLowerCase() != _selectedWallet!.toLowerCase()) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                final incomeCount = periodTxns
                    .where((t) => t.type == CashTransactionType.income)
                    .length;
                final expenseCount = periodTxns
                    .where((t) => t.type == CashTransactionType.expense)
                    .length;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ══════════════════════════════════════════════
                            // 1. KARTU REKAP SALDO AWAL, MUTASI & SALDO AKHIR
                            // ══════════════════════════════════════════════
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded,
                                              size: 13, color: Colors.grey[600]),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Periode: ${dateShort(_range.start)} - ${dateShort(_range.end)}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${periodTxns.length} Catatan',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),

                                  // Baris 1: Saldo Awal, Mutasi Bersih, Saldo Akhir
                                  Row(
                                    children: [
                                      // Saldo Awal
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.history_rounded,
                                                    size: 13,
                                                    color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Saldo Awal',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              money(startingBalance),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[800],
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
                                      const SizedBox(width: 8),

                                      // Mutasi Bersih Periode Ini
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.swap_vert_rounded,
                                                    size: 13,
                                                    color: netChange >= 0
                                                        ? AppColors.income
                                                        : AppColors.expense),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Mutasi Kas',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${netChange >= 0 ? '+' : ''}${money(netChange)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: netChange >= 0
                                                    ? AppColors.income
                                                    : AppColors.expense,
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
                                      const SizedBox(width: 8),

                                      // Saldo Akhir
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                    Icons
                                                        .account_balance_wallet_rounded,
                                                    size: 13,
                                                    color: AppColors.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Saldo Akhir',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              money(endingBalance),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        // Detail Masuk
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.south_west_rounded,
                                                size: 13,
                                                color: AppColors.income),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Masuk: ',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600]),
                                            ),
                                            Text(
                                              money(periodIncome),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.income,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                            width: 1,
                                            height: 14,
                                            color: Colors.grey[300]),
                                        // Detail Keluar
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.north_east_rounded,
                                                size: 13,
                                                color: AppColors.expense),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Keluar: ',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600]),
                                            ),
                                            Text(
                                              money(periodExpense),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.expense,
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

                            const SizedBox(height: 14),

                            // ══════════════════════════════════════════════
                            // 2. REKAP KAS PER AKUN / DOMPET (MULTI-WALLET)
                            // ══════════════════════════════════════════════
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 15,
                                        color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      'Rekap per Akun / Dompet',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedWallet != null)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () =>
                                        setState(() => _selectedWallet = null),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Tampilkan Semua',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(Icons.close_rounded,
                                              size: 13,
                                              color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Horizontal scroll of Wallet Cards
                            SizedBox(
                              height: 86,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  // Kartu 'Semua Akun'
                                  _buildWalletCard(
                                    name: 'Semua Akun',
                                    endingBalance: endingBalance,
                                    periodIncome: periodIncome,
                                    periodExpense: periodExpense,
                                    icon: Icons.all_inclusive_rounded,
                                    color: AppColors.primaryDark,
                                    isSelected: _selectedWallet == null,
                                    onTap: () =>
                                        setState(() => _selectedWallet = null),
                                  ),
                                  const SizedBox(width: 8),
                                  // Kartu tiap wallet
                                  ...walletSummaries.map((w) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: _buildWalletCard(
                                          name: w.name,
                                          endingBalance: w.endingBalance,
                                          periodIncome: w.periodIncome,
                                          periodExpense: w.periodExpense,
                                          icon: w.icon,
                                          color: w.color,
                                          isSelected: _selectedWallet
                                                  ?.toLowerCase() ==
                                              w.name.toLowerCase(),
                                          onTap: () {
                                            setState(() {
                                              if (_selectedWallet
                                                      ?.toLowerCase() ==
                                                  w.name.toLowerCase()) {
                                                _selectedWallet = null;
                                              } else {
                                                _selectedWallet = w.name;
                                              }
                                            });
                                          },
                                        ),
                                      )),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ══════════════════════════════════════════════
                            // 3. TAB SELECTOR
                            // ══════════════════════════════════════════════
                            SegmentedButton<_CashTab>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: _CashTab.income,
                                  label: Text(
                                    'Uang Masuk ($incomeCount)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _tab == _CashTab.income
                                          ? Colors.white
                                          : null,
                                    ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: _CashTab.expense,
                                  label: Text(
                                    'Uang Keluar ($expenseCount)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _tab == _CashTab.expense
                                          ? Colors.white
                                          : null,
                                    ),
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
                    ),

                    // Active Wallet Filter indicator if selected
                    if (_selectedWallet != null)
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: Row(
                            children: [
                              const Icon(Icons.filter_alt_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Menampilkan mutasi akun: $_selectedWallet',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedWallet = null),
                                child: const Icon(Icons.cancel_rounded,
                                    size: 16, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // List of transactions
                    if (filteredItems.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: _tab == _CashTab.income
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          title: _tab == _CashTab.income
                              ? 'Belum ada uang masuk'
                              : 'Belum ada uang keluar',
                          message: _selectedWallet != null
                              ? 'Tidak ada mutasi ${_tab == _CashTab.income ? "masuk" : "keluar"} untuk akun $_selectedWallet pada periode ini.'
                              : 'Belum ada catatan ${_tab == _CashTab.income ? "pemasukan" : "pengeluaran"} di periode ini.',
                          action: canManage
                              ? ElevatedButton.icon(
                                  onPressed: () => CashFormSheet.show(
                                    context,
                                    isIncome: _tab == _CashTab.income,
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(_tab == _CashTab.income
                                      ? 'Catat Uang Masuk'
                                      : 'Catat Uang Keluar'),
                                )
                              : null,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final txn = filteredItems[index];
                              final isVoided = txn.sourceSaleId.isNotEmpty &&
                                  refundedSaleIds.contains(txn.sourceSaleId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _CashTile(
                                  txnModel: txn,
                                  canManage: canManage,
                                  isRefundedOrVoided: isVoided,
                                ),
                              );
                            },
                            childCount: filteredItems.length,
                          ),
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

  Widget _buildWalletCard({
    required String name,
    required int endingBalance,
    required int periodIncome,
    required int periodExpense,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 146,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 13, color: color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? color : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(endingBalance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: endingBalance >= 0
                        ? const Color(0xFF0F172A)
                        : AppColors.expense,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '+${compactMoney(periodIncome)} / -${compactMoney(periodExpense)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
