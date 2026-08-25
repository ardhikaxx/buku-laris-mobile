import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/misc_models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(gateProvider).user?.uid;
    if (uid == null) return const SizedBox.shrink();

    final repo = ref.read(notificationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          StreamBuilder<int>(
            stream: repo.unreadCount(uid),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => repo.markAllRead(uid),
                child: const Text('Tandai dibaca'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: repo.watchForUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorStateView(error: snapshot.error!);
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Belum ada notifikasi',
              message:
                  'Pemberitahuan penting seperti undangan dan aktivitas usaha akan muncul di sini.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = items[index];
                return Card(
                  color: n.read
                      ? Colors.white
                      : AppColors.primary.withValues(alpha: 0.04),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    onTap: () => repo.markRead(uid, n.id),
                    leading: CircleAvatar(
                      radius: 19,
                      backgroundColor:
                          _typeColor(n.type).withValues(alpha: 0.12),
                      child: Icon(_typeIcon(n.type),
                          size: 19, color: _typeColor(n.type)),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: n.read
                                      ? FontWeight.w600
                                      : FontWeight.w800)),
                        ),
                        if (!n.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(n.body,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: Colors.grey[700])),
                        const SizedBox(height: 4),
                        Text(dateTimeShort(n.createdAt),
                            style: TextStyle(
                                fontSize: 10.5, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _typeIcon(NotificationType type) => switch (type) {
        NotificationType.invitation => Icons.mark_email_unread_outlined,
        NotificationType.lowStock => Icons.warning_amber_rounded,
        NotificationType.preorderDue => Icons.schedule_send_outlined,
        NotificationType.paymentUnpaid => Icons.payments_outlined,
        NotificationType.system => Icons.info_outline_rounded,
      };

  Color _typeColor(NotificationType type) => switch (type) {
        NotificationType.invitation => AppColors.accent,
        NotificationType.lowStock => AppColors.expense,
        NotificationType.preorderDue => AppColors.info,
        NotificationType.paymentUnpaid => AppColors.warning,
        NotificationType.system => AppColors.primary,
      };
}
