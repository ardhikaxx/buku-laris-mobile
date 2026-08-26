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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Tab 0: Beranda
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Beranda',
                  selected: currentIndex == 0,
                  onTap: () {
                    if (currentIndex != 0) context.go('/home');
                  },
                ),
              ),
              // Tab 1: Penjualan
              Expanded(
                child: _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Penjualan',
                  selected: currentIndex == 1,
                  onTap: () {
                    if (currentIndex != 1) context.go('/sales');
                  },
                ),
              ),
              // Center Action Button: Kasir POS
              _CenterActionButton(
                onTap: () => context.push('/sales/new'),
                onLongPress: () => showQuickActions(context),
              ),
              // Tab 2: Produk
              Expanded(
                child: _NavItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: 'Produk',
                  selected: currentIndex == 2,
                  onTap: () {
                    if (currentIndex != 2) context.go('/products');
                  },
                ),
              ),
              // Tab 3: Lainnya
              Expanded(
                child: _NavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Lainnya',
                  selected: currentIndex == 3 || currentIndex == 4,
                  onTap: () {
                    if (currentIndex != 3) context.go('/more');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CenterActionButton({required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Kasir POS (Tahan untuk Aksi Cepat)',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFB45309),
                    Color(0xFFD97706),
                    Color(0xFFF59E0B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kasir',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFEF3C7)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 21,
                  color: selected
                      ? AppColors.primaryDark
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected
                      ? AppColors.primaryDark
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
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
