import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/gate.dart';
import '../../../../core/theme/app_theme.dart';

class PersonalWorkspaceScreen extends ConsumerWidget {
  const PersonalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(gateProvider);
    final name = gate.profile?.displayName ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      size: 38, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  name.isEmpty ? 'Akun Anda belum terhubung ke usaha' : 'Halo, $name',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Saat ini akun Anda tidak tergabung di workspace usaha mana pun. Anda bisa membuat usaha sendiri dan menjadi pemiliknya, atau menunggu undangan dari pemilik usaha lain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey[600],
                      height: 1.6),
                ),
                if (gate.profile?.hasPersonalWorkspace ?? false) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anda masih memiliki workspace pribadi. Untuk menerima undangan baru, hapus workspace pribadi Anda terlebih dahulu melalui menu Pengaturan.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.amber[900],
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => context.go('/onboarding'),
                  icon: const Icon(Icons.add_business_rounded, size: 20),
                  label: const Text('Buat Usaha Saya'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
