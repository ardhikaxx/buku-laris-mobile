import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class WorkspaceMember {
  final String userId;
  final String workspaceId;
  final String displayName;
  final String email;
  final UserRole role;
  final Set<Permission> permissions;
  final String status;
  final DateTime? joinedAt;
  final String? invitedBy;
  final DateTime? removedAt;
  final DateTime? lastActiveAt;
  final String? invitationId;

  const WorkspaceMember({
    required this.userId,
    required this.workspaceId,
    required this.displayName,
    required this.email,
    required this.role,
    this.permissions = const {},
    this.status = 'ACTIVE',
    this.joinedAt,
    this.invitedBy,
    this.removedAt,
    this.lastActiveAt,
    this.invitationId,
  });

  factory WorkspaceMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return WorkspaceMember(
      userId: str(d['userId'], doc.id),
      workspaceId: str(d['workspaceId']),
      displayName: str(d['displayName'], 'Anggota'),
      email: str(d['email']),
      role: enumFromName(UserRole.values, d['role'], UserRole.EMPLOYEE),
      permissions: strList(d['permissions'])
          .map((s) => enumFromName(Permission.values, s, Permission.dashboardView))
          .toSet(),
      status: str(d['status'], 'ACTIVE'),
      joinedAt: dtFromTs(d['joinedAt']),
      invitedBy: strOrNull(d['invitedBy']),
      removedAt: dtFromTs(d['removedAt']),
      lastActiveAt: dtFromTs(d['lastActiveAt']),
      invitationId: strOrNull(d['invitationId']),
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isOwner => role == UserRole.OWNER && isActive;
  bool get isEmployee => role == UserRole.EMPLOYEE && isActive;

  bool hasPermission(Permission p) =>
      isActive && (isOwner || permissions.isEmpty || permissions.contains(p));

  Map<String, dynamic> toCreateMap() => {
        'userId': userId,
        'workspaceId': workspaceId,
        'displayName': displayName,
        'email': email.toLowerCase(),
        'role': role.name,
        'permissions': (role == UserRole.OWNER || permissions.isEmpty)
            ? Permission.values.map((p) => p.name).toList()
            : permissions.map((p) => p.name).toList(),
        'status': status,
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': invitedBy,
        'removedAt': null,
        'invitationId': invitationId,
      };
}
