import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/enums.dart';
import '../../cashflow/widgets/cash_form_sheet.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  static const _routes = [
    '/home',
    '/sales',
    '/products',
    '/finance',
    '/more',
  ];

  static const _icons = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.inventory_2_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.grid_view_outlined,
  ];

  static const _activeIcons = [
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.inventory_2_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.grid_view_rounded,
  ];

  static const _labels = [
    'Beranda',
    'Penjualan',
    'Produk',
    'Keuangan',
    'Lainnya',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex.clamp(0, _routes.length - 1),
        onDestinationSelected: (index) {
          if (index != currentIndex) {
            context.go(_routes[index]);
          }
        },
        destinations: [
          for (var i = 0; i < _routes.length; i++)
            NavigationDestination(
              icon: Icon(_icons[i]),
              selectedIcon: Icon(_activeIcons[i]),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}

class QuickActionsSheet extends ConsumerWidget {
  const QuickActionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeWorkspaceProvider);
    final canCashflow = state.can(Permission.cashflowManage);
    final canProduct = state.can(Permission.productsManage);
    final preorderEnabled = state.workspace?.supportsPreOrder ?? false;

    final actions = <(String, IconData, Color, VoidCallback)>[
      (
        'Catat Penjualan',
        Icons.point_of_sale_rounded,
        AppColors.primary,
        () => context.push('/sales/new')
      ),
      if (preorderEnabled)
        (
          'Pre-Order',
          Icons.schedule_send_outlined,
          AppColors.info,
          () => context.push('/sales/new?type=preorder')
        ),
      if (canCashflow) ...[
        (
          'Uang Masuk',
          Icons.south_west_rounded,
          AppColors.income,
          () => CashFormSheet.show(context, isIncome: true)
        ),
        (
          'Uang Keluar',
          Icons.north_east_rounded,
          AppColors.expense,
          () => CashFormSheet.show(context, isIncome: false)
        ),
      ],
      if (canProduct)
        (
          'Tambah Produk',
          Icons.add_box_outlined,
          AppColors.primary,
          () => context.push('/products/new')
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Aksi Cepat',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800])),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              childAspectRatio: 1.05,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final action in actions) _QuickActionTile(action: action),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final (String, IconData, Color, VoidCallback) action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, onTap) = action;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 7),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

void showQuickActions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => const QuickActionsSheet(),
  );
}
