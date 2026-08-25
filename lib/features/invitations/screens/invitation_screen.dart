import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/gate.dart';
import '../../../../config/providers.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/invitation_model.dart';
import '../../../../services/logger.dart';

class InvitationScreen extends ConsumerStatefulWidget {
  const InvitationScreen({super.key});

  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _accept(Invitation invitation) async {
    setState(() => _busy = true);
    try {
      final profile = ref.read(gateProvider).profile!;
      await ref
          .read(invitationRepositoryProvider)
          .acceptInvitation(invitation: invitation, user: profile);
      ref.read(gateProvider.notifier).refreshAfterInvitationResolved();
    } catch (e) {
      Logger.e('accept invitation failed', e);
      if (mounted) {
        setState(() => _error = mapToAppException(e).message);
        _busy = false;
      }
    }
  }

  Future<void> _reject(Invitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak undangan?'),
        content: Text(
            'Anda akan menolak undangan dari ${invitation.workspaceName}. Pemilik usaha dapat mengundang Anda kembali nantinya.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final profile = ref.read(gateProvider).profile!;
      await ref
          .read(invitationRepositoryProvider)
          .rejectInvitation(invitation: invitation, user: profile);
      ref.read(gateProvider.notifier).refreshAfterInvitationResolved();
    } catch (e) {
      if (mounted) {
        setState(() => _error = mapToAppException(e).message);
        _busy = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(gateProvider);
    final invitations = gate.pendingInvitations;
    final name = gate.profile?.displayName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        size: 34, color: AppColors.accent),
                    alignment: Alignment.center,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    invitations.length > 1
                        ? 'Anda punya ${invitations.length} undangan'
                        : 'Undangan Bergabung',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hai $name, Anda diundang untuk bergabung sebagai karyawan. Terima undangan untuk mulai bekerja, atau tolak jika tidak berminat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: Colors.grey[600], height: 1.55),
                  ),
                  const SizedBox(height: 22),
                  for (final inv in invitations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(Icons.storefront_rounded,
                                        color: AppColors.primary, size: 21),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          inv.workspaceName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          'Diundang oleh ${inv.ownerName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(_error!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFDC2626))),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          _busy ? null : () => _reject(inv),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(42),
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        minimumSize: const Size.fromHeight(42),
                                      ),
                                      onPressed:
                                          _busy ? null : () => _accept(inv),
                                      child: _busy
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Text('Terima & Gabung'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
