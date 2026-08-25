import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/invitation_model.dart';
import '../../../models/workspace_member_model.dart';
import '../../../services/logger.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(gateProvider);
    final wsId = gate.activeWorkspaceId;
    if (wsId == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Karyawan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Anggota'),
              Tab(text: 'Undangan'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'employees-fab',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _showInviteDialog(context, ref),
          icon: const Icon(Icons.person_add_alt_rounded, size: 20),
          label: const Text('Undang',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        body: TabBarView(children: [
          _MembersTab(wsId: wsId),
          _InvitationsTab(wsId: wsId),
        ]),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undang Karyawan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Masukkan email akun yang digunakan karyawan Anda untuk login di aplikasi.',
                style: TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Email karyawan'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirim Undangan')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final gate = ref.read(gateProvider);
      await ref.read(invitationRepositoryProvider).createInvitation(
            wsId: gate.activeWorkspaceId!,
            workspaceName:
                ref.read(activeWorkspaceProvider).workspace?.name ?? '',
            ownerId: ref.read(authServiceProvider).currentUser!.uid,
            ownerName: gate.profile?.displayName ?? '',
            invitedEmail: emailController.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Undangan terkirim ke ${emailController.text}. Undangan berlaku 7 hari.'),
          backgroundColor: AppColors.income,
        ));
      }
    } catch (e) {
      Logger.e('invite failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }
}

class _MembersTab extends ConsumerWidget {
  final String wsId;

  const _MembersTab({required this.wsId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(gateProvider).user?.uid;
    return StreamBuilder<List<WorkspaceMember>>(
      stream: ref.read(membershipRepositoryProvider).watchMembers(wsId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListSkeleton();
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Belum ada anggota lain',
            message: 'Undang karyawan agar dapat membantu operasional usaha.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final member = members[index];
            final isSelf = member.userId == currentUid;
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                leading: CircleAvatar(
                  radius: 21,
                  backgroundColor: colorFromString(member.email)
                      .withValues(alpha: 0.14),
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colorFromString(member.email)),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(member.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    StatusChip(
                        isSelf
                            ? 'Anda'
                            : member.role.label,
                        isSelf || member.isOwner
                            ? AppColors.primary
                            : AppColors.info),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Text(
                        member.isOwner
                            ? 'Akses penuh'
                            : '${member.permissions.length} hak akses • gabung ${dateShort(member.joinedAt)}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                trailing: (!isSelf && member.isEmployee)
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 19),
                        onSelected: (value) {
                          if (value == 'permissions') {
                            _editPermissions(context, ref, member);
                          } else if (value == 'remove') {
                            _removeMember(context, ref, member);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'permissions', child: Text('Hak Akses')),
                          PopupMenuItem(value: 'remove', child: Text('Keluarkan')),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editPermissions(
      BuildContext context, WidgetRef ref, WorkspaceMember member) async {
    var selected = Set<Permission>.from(member.permissions);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hak Akses — ${member.displayName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final permission in Permission.values)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: selected.contains(permission),
                        title: Text(permission.label,
                            style: const TextStyle(fontSize: 13)),
                        onChanged: (v) => setSheet(() {
                          if (v == true) {
                            selected.add(permission);
                          } else {
                            selected.remove(permission);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan Hak Akses'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != true) return;

    try {
      final gate = ref.read(gateProvider);
      await ref.read(membershipRepositoryProvider).updatePermissions(
            wsId: wsId,
            workspaceName:
                ref.read(activeWorkspaceProvider).workspace?.name ?? '',
            actorId: ref.read(authServiceProvider).currentUser!.uid,
            actorName: gate.profile?.displayName ?? '',
            member: member,
            permissions: selected,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }

  Future<void> _removeMember(
      BuildContext context, WidgetRef ref, WorkspaceMember member) async {
    final confirmed = await confirmAction(
      context,
      title: 'Keluarkan ${member.displayName}?',
      message:
          'Akun karyawan TIDAK dihapus dan tetap bisa login. Akun tersebut akan kehilangan akses ke workspace ini dan nantinya dapat membuat usaha sendiri atau menerima undangan baru.',
      confirmLabel: 'Keluarkan',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      final gate = ref.read(gateProvider);
      await ref.read(membershipRepositoryProvider).removeEmployee(
            wsId: wsId,
            workspaceName:
                ref.read(activeWorkspaceProvider).workspace?.name ?? '',
            actorId: ref.read(authServiceProvider).currentUser!.uid,
            actorName: gate.profile?.displayName ?? '',
            member: member,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Karyawan telah dikeluarkan dari workspace')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }
}

class _InvitationsTab extends ConsumerWidget {
  final String wsId;

  const _InvitationsTab({required this.wsId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Invitation>>(
      stream: ref.read(invitationRepositoryProvider).watchForWorkspace(wsId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListSkeleton();
        }
        final invitations = snapshot.data ?? [];
        if (invitations.isEmpty) {
          return const EmptyState(
            icon: Icons.mail_outline_rounded,
            title: 'Belum ada undangan',
            message:
                'Riwayat undangan karyawan akan tampil di sini beserta statusnya.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: invitations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final inv = invitations[index];
            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                leading: Icon(
                  switch (inv.status) {
                    InvitationStatus.pending => Icons.schedule_rounded,
                    InvitationStatus.accepted => Icons.check_circle_rounded,
                    InvitationStatus.rejected => Icons.cancel_rounded,
                    InvitationStatus.expired => Icons.event_busy_rounded,
                    InvitationStatus.revoked => Icons.block_rounded,
                  },
                  color: switch (inv.status) {
                    InvitationStatus.pending => AppColors.warning,
                    InvitationStatus.accepted => AppColors.income,
                    _ => Colors.grey,
                  },
                ),
                title: Text(inv.invitedEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Dikirim ${dateShort(inv.createdAt)}'
                  '${inv.expiresAt != null ? ' • berlaku s.d. ${dateShort(inv.expiresAt)}' : ''}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                        inv.status.label,
                        switch (inv.status) {
                          InvitationStatus.pending => AppColors.warning,
                          InvitationStatus.accepted => AppColors.income,
                          InvitationStatus.rejected => AppColors.expense,
                          _ => Colors.grey,
                        }),
                    if (inv.status == InvitationStatus.pending)
                      IconButton(
                        tooltip: 'Batalkan undangan',
                        icon: const Icon(Icons.close_rounded, size: 19),
                        onPressed: () async {
                          try {
                            await ref
                                .read(invitationRepositoryProvider)
                                .revokeInvitation(
                                  invitation: inv,
                                  actorId: ref
                                      .read(authServiceProvider)
                                      .currentUser!
                                      .uid,
                                  actorName: ref
                                          .read(gateProvider)
                                          .profile
                                          ?.displayName ??
                                      '',
                                );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content:
                                    Text(mapToAppException(e).message),
                                backgroundColor: AppColors.expense,
                              ));
                            }
                          }
                        },
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
}
