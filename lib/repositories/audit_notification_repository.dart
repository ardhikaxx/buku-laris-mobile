import '../core/constants/app_constants.dart';
import '../models/enums.dart';
import '../models/misc_models.dart';
import 'base_repository.dart';

class AuditRepository extends BaseRepository {
  void log({
    required String workspaceId,
    required String actorId,
    required String actorName,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? metadata,
  }) {
    sub(workspaceId, Collections.auditLogs)
        .add(AuditLog(
          actorId: actorId,
          actorName: actorName,
          action: action,
          entityType: entityType,
          entityId: entityId,
          metadata: metadata ?? const {},
        ).toCreateMap())
        .then((_) {}, onError: (_) {});
  }

  Future<List<AuditLog>> listRecent(String workspaceId, {int limit = 50}) async {
    final snap = await sub(workspaceId, Collections.auditLogs)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AuditLog.fromDoc).toList();
  }
}

class NotificationRepository extends BaseRepository {
  Stream<List<NotificationModel>> watchForUser(String uid) {
    return usersCol()
        .doc(uid)
        .collection(Collections.notifications)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(NotificationModel.fromDoc).toList());
  }

  Stream<int> unreadCount(String uid) {
    return usersCol()
        .doc(uid)
        .collection(Collections.notifications)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> pushToUser(
    String uid, {
    required String title,
    required String body,
    required NotificationType type,
    String? workspaceId,
    Map<String, dynamic>? extra,
  }) async {
    await usersCol()
        .doc(uid)
        .collection(Collections.notifications)
        .add(NotificationModel.createMap(
          title: title,
          body: body,
          type: type,
          workspaceId: workspaceId,
          extra: extra,
        ));
  }

  Future<void> markRead(String uid, String notificationId) async {
    await usersCol()
        .doc(uid)
        .collection(Collections.notifications)
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> markAllRead(String uid) async {
    final snap = await usersCol()
        .doc(uid)
        .collection(Collections.notifications)
        .where('read', isEqualTo: false)
        .get();
    final batch = fs.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
