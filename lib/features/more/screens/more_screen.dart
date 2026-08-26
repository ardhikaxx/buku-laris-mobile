import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../shared/widgets/navigation.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeWorkspaceProvider);
    final gate = ref.watch(gateProvider);
    final isOwner = gate.myMembership?.isOwner ?? false;
    final canReports = isOwner || state.can(Permission.reportsSalesView);
    final canCustomers = isOwner || state.can(Permission.customersManage);
    final canCashflow = isOwner || state.can(Permission.cashflowManage);

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          child: const Icon(Icons.widgets_rounded,
              color: Colors.white, size: 20),
        ),
        titleText: state.workspace?.name ?? 'Buku Laris',
        subtitleText: 'Menu operasional & pengaturan',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileCard(context, ref, gate),
          const SizedBox(height: 18),
          const SectionHeader('Operasional'),
          Card(
            child: Column(
              children: [
                if (canCashflow)
                  _MenuTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Keuangan & Arus Kas',
                    onTap: () => context.push('/finance'),
                  ),
                if (canCustomers)
                  _MenuTile(
                    icon: Icons.people_outline_rounded,
                    label: 'Pelanggan',
                    onTap: () => context.push('/customers'),
                  ),
                if (canReports)
                  _MenuTile(
                    icon: Icons.bar_chart_rounded,
                    label: 'Laporan Bisnis',
                    onTap: () => context.push('/reports'),
                  ),
                _MenuTile(
                  icon: Icons.trending_down_rounded,
                  label: 'Stok Menipis',
                  onTap: () => context.push('/inventory/low-stock'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SectionHeader('Workspace'),
          Card(
            child: Column(
              children: [
                if (isOwner)
                  _MenuTile(
                    icon: Icons.group_add_outlined,
                    label: 'Karyawan & Undangan',
                    onTap: () => context.push('/employees'),
                  ),
                if (isOwner)
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan Usaha',
                    onTap: () => context.push('/settings'),
                  ),
                _MenuTile(
                  icon: Icons.sell_rounded,
                  label: 'Kategori Produk',
                  onTap: () => context.push('/categories'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SectionHeader('Akun'),
          Card(
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Keluar (Logout)',
                  danger: true,
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _profileCard(BuildContext context, WidgetRef ref, GateState gate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: gate.user?.photoURL != null
                  ? NetworkImage(gate.user!.photoURL!)
                  : null,
              child: gate.user?.photoURL == null
                  ? Text(
                      (gate.profile?.displayName.isNotEmpty ?? false)
                          ? gate.profile!.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gate.profile?.displayName ?? 'Pengguna',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(gate.profile?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Keluar dari akun?',
      message:
          'Anda perlu login kembali untuk mengakses data usaha. Data tersimpan aman di server.',
      confirmLabel: 'Keluar',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(authServiceProvider).signOut();
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Icon(icon,
          size: 21, color: danger ? AppColors.expense : Colors.grey[700]),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: danger ? AppColors.expense : const Color(0xFF111827))),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 20, color: Color(0xFFD1D5DB)),
      onTap: onTap,
    );
  }
}
