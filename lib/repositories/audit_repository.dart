import '../core/constants/app_constants.dart';
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
