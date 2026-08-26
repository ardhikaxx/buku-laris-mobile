import '../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enums.dart';
import '../models/workspace_member_model.dart';
import 'audit_repository.dart';
import 'base_repository.dart';

class MembershipRepository extends BaseRepository {
  final AuditRepository _audit = AuditRepository();

  Stream<List<WorkspaceMember>> watchMembers(String wsId) {
    return sub(wsId, Collections.members)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((s) => s.docs.map(WorkspaceMember.fromDoc).toList());
  }

  Future<WorkspaceMember?> getMember(String wsId, String uid) async {
    final doc = await sub(wsId, Collections.members).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return WorkspaceMember.fromDoc(doc);
  }

  Future<void> updatePermissions({
    required String wsId,
    required String workspaceName,
    required String actorId,
    required String actorName,
    required WorkspaceMember member,
    required Set<Permission> permissions,
  }) async {
    if (member.role == UserRole.OWNER) {
      throw RepoException('Permission pemilik usaha tidak dapat diubah.');
    }
    await sub(wsId, Collections.members).doc(member.userId).update({
      'permissions': permissions.map((p) => p.name).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _audit.log(
      workspaceId: wsId,
      actorId: actorId,
      actorName: actorName,
      action: 'member.permissions_updated',
      entityType: 'member',
      entityId: member.userId,
      metadata: {'permissions': permissions.map((p) => p.name).toList()},
    );
  }

  Future<void> setMemberActive({
    required String wsId,
    required String actorId,
    required String actorName,
    required WorkspaceMember member,
    required bool active,
  }) async {
    if (member.role == UserRole.OWNER) {
      throw RepoException('Status pemilik usaha tidak dapat diubah.');
    }
    await sub(wsId, Collections.members).doc(member.userId).update({
      'status': active ? 'ACTIVE' : 'SUSPENDED',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _audit.log(
      workspaceId: wsId,
      actorId: actorId,
      actorName: actorName,
      action: active ? 'member.reactivated' : 'member.suspended',
      entityType: 'member',
      entityId: member.userId,
    );
  }

  Future<void> removeEmployee({
    required String wsId,
    required String workspaceName,
    required String actorId,
    required String actorName,
    required WorkspaceMember member,
  }) async {
    if (member.role != UserRole.EMPLOYEE) {
      throw RepoException('Hanya karyawan yang dapat dikeluarkan dari workspace.');
    }
    final batch = fs.batch();
    batch.update(sub(wsId, Collections.members).doc(member.userId), {
      'status': 'REMOVED',
      'removedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      usersCol().doc(member.userId),
      {'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();

    _audit.log(
      workspaceId: wsId,
      actorId: actorId,
      actorName: actorName,
      action: 'member.removed',
      entityType: 'member',
      entityId: member.userId,
      metadata: {'email': member.email},
    );
  }

  Future<void> touchLastActive(String wsId, String uid) async {
    try {
      await sub(wsId, Collections.members).doc(uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<List<WorkspaceMember>> watchMyMemberships(String uid) {
    return fs
        .collectionGroup(Collections.members)
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((s) => s.docs.map(WorkspaceMember.fromDoc).toList());
  }
}
