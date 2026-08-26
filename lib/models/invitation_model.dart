import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class Invitation {
  final String id;
  final String workspaceId;
  final String workspaceName;
  final String ownerId;
  final String ownerName;
  final String invitedEmail;
  final String? invitedUserId;
  final String role;
  final InvitationStatus status;
  final String token;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? revokedAt;

  const Invitation({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.ownerId,
    required this.ownerName,
    required this.invitedEmail,
    this.invitedUserId,
    this.role = 'EMPLOYEE',
    this.status = InvitationStatus.pending,
    required this.token,
    this.createdAt,
    this.expiresAt,
    this.acceptedAt,
    this.rejectedAt,
    this.revokedAt,
  });

  factory Invitation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Invitation(
      id: doc.id,
      workspaceId: str(d['workspaceId']),
      workspaceName: str(d['workspaceName']),
      ownerId: str(d['ownerId']),
      ownerName: str(d['ownerName']),
      invitedEmail: str(d['invitedEmail']).toLowerCase(),
      invitedUserId: strOrNull(d['invitedUserId']),
      role: str(d['role'], 'EMPLOYEE'),
      status: enumFromName(
          InvitationStatus.values,
          d['status']?.toString().toLowerCase(),
          InvitationStatus.pending),
      token: str(d['token']),
      createdAt: dtFromTs(d['createdAt']),
      expiresAt: dtFromTs(d['expiresAt']),
      acceptedAt: dtFromTs(d['acceptedAt']),
      rejectedAt: dtFromTs(d['rejectedAt']),
      revokedAt: dtFromTs(d['revokedAt']),
    );
  }

  bool get effectivelyPending {
    if (status != InvitationStatus.pending) return false;
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  Map<String, dynamic> toCreateMap() => {
        'workspaceId': workspaceId,
        'workspaceName': workspaceName.trim(),
        'ownerId': ownerId,
        'ownerName': ownerName,
        'invitedEmail': invitedEmail.toLowerCase(),
        'invitedUserId': invitedUserId,
        'role': 'EMPLOYEE',
        'status': 'PENDING',
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt == null
            ? null
            : Timestamp.fromDate(expiresAt!),
        'acceptedAt': null,
        'rejectedAt': null,
        'revokedAt': null,
      };
}
