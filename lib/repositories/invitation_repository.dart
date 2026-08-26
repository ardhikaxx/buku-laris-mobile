import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/enums.dart';
import '../models/invitation_model.dart';
import '../models/user_profile_model.dart';
import '../models/workspace_member_model.dart';
import 'audit_repository.dart';
import 'base_repository.dart';

class InvitationRepository extends BaseRepository {
  final AuditRepository _audit = AuditRepository();

  String _generateToken() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    ).replaceAll(RegExp(r'[=+/]'), '');
  }

  Future<void> createInvitation({
    required String wsId,
    required String workspaceName,
    required String ownerId,
    required String ownerName,
    required String invitedEmail,
    Set<Permission> permissions = DefaultPermissions.employeeDefault,
  }) async {
    final email = invitedEmail.trim().toLowerCase();
    if (!email.contains('@')) {
      throw RepoException('Format email tidak valid.');
    }
    final userDoc = await usersCol().doc(ownerId).get();
    final ownerEmail = (userDoc.data()?['email'] ?? '').toString().trim().toLowerCase();
    if (ownerEmail.isNotEmpty && email == ownerEmail) {
      throw RepoException(
          'Anda tidak bisa mengundang email akun sendiri sebagai karyawan.');
    }

    final existingActive = await fs
        .collection(Collections.invitations)
        .where('workspaceId', isEqualTo: wsId)
        .where('invitedEmail', isEqualTo: email)
        .where('status', isEqualTo: 'PENDING')
        .limit(1)
        .get();
    if (existingActive.docs.isNotEmpty) {
      throw RepoException(
          'Undangan untuk email ini masih menunggu respons. Batalkan undangan lama terlebih dahulu untuk mengirim ulang.');
    }

    final memberSnap = await sub(wsId, Collections.members).limit(50).get();
    for (final m in memberSnap.docs) {
      if ((m.data()['email'] ?? '').toString().toLowerCase() == email &&
          (m.data()['status'] ?? '') == 'ACTIVE') {
        throw RepoException('Email ini sudah menjadi anggota aktif workspace.');
      }
    }

    final inviteRef = fs.collection(Collections.invitations).doc();
    final invitation = Invitation(
      id: inviteRef.id,
      workspaceId: wsId,
      workspaceName: workspaceName,
      ownerId: ownerId,
      ownerName: ownerName,
      invitedEmail: email,
      role: UserRole.EMPLOYEE.name,
      token: _generateToken(),
      expiresAt: DateTime.now().add(const Duration(days: AppConstants.invitationExpiryDays)),
    );
    await inviteRef.set(invitation.toCreateMap());

    _audit.log(
      workspaceId: wsId,
      actorId: ownerId,
      actorName: ownerName,
      action: 'invitation.sent',
      entityType: 'invitation',
      entityId: inviteRef.id,
      metadata: {'invitedEmail': email},
    );
  }

  Future<List<Invitation>> listPendingForEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final snap = await fs
        .collection(Collections.invitations)
        .where('invitedEmail', isEqualTo: cleanEmail)
        .get();
    return snap.docs
        .map(Invitation.fromDoc)
        .where((i) => i.effectivelyPending)
        .toList();
  }

  Stream<List<Invitation>> watchPendingForEmail(String email) {
    final cleanEmail = email.trim().toLowerCase();
    return fs
        .collection(Collections.invitations)
        .where('invitedEmail', isEqualTo: cleanEmail)
        .snapshots()
        .map((snap) => snap.docs
            .map(Invitation.fromDoc)
            .where((i) => i.effectivelyPending)
            .toList());
  }

  Future<List<Invitation>> listForWorkspace(String wsId) async {
    final snap = await fs
        .collection(Collections.invitations)
        .where('workspaceId', isEqualTo: wsId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    return snap.docs.map(Invitation.fromDoc).toList();
  }

  Stream<List<Invitation>> watchForWorkspace(String wsId) {
    return fs
        .collection(Collections.invitations)
        .where('workspaceId', isEqualTo: wsId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map(Invitation.fromDoc).toList());
  }

  Future<bool> hasBlockingPersonalWorkspace(UserProfile profile) =>
      Future.value(profile.hasPersonalWorkspace);

  Future<void> acceptInvitation({
    required Invitation invitation,
    required UserProfile user,
  }) async {
    final now = FieldValue.serverTimestamp();
    final inviteRef = fs.collection(Collections.invitations).doc(invitation.id);
    final memberRef = sub(invitation.workspaceId, Collections.members).doc(user.uid);
    final userRef = usersCol().doc(user.uid);

    final fresh = await inviteRef.get();
    if (!fresh.exists || !Invitation.fromDoc(fresh).effectivelyPending) {
      throw RepoException('Undangan sudah tidak berlaku.');
    }

    await fs.runTransaction((txn) async {
      txn.update(inviteRef, {
        'status': InvitationStatus.accepted.name,
        'acceptedAt': now,
        'invitedUserId': user.uid,
        'updatedAt': now,
      });
      txn.set(
        memberRef,
        WorkspaceMember(
          userId: user.uid,
          workspaceId: invitation.workspaceId,
          displayName: user.displayName,
          email: user.email,
          role: UserRole.EMPLOYEE,
          permissions: DefaultPermissions.employeeDefault,
          invitedBy: invitation.ownerId,
          invitationId: invitation.id,
        ).toCreateMap(),
      );
      txn.update(userRef, {
        'workspaceIds': FieldValue.arrayUnion([invitation.workspaceId]),
        'activeWorkspaceId': invitation.workspaceId,
        'updatedAt': now,
      });
    });

    _audit.log(
      workspaceId: invitation.workspaceId,
      actorId: user.uid,
      actorName: user.displayName,
      action: 'invitation.accepted',
      entityType: 'invitation',
      entityId: invitation.id,
      metadata: {'invitedEmail': invitation.invitedEmail},
    );
  }

  Future<void> rejectInvitation({
    required Invitation invitation,
    required UserProfile user,
  }) async {
    await fs.collection(Collections.invitations).doc(invitation.id).update({
      'status': InvitationStatus.rejected.name,
      'rejectedAt': FieldValue.serverTimestamp(),
      'invitedUserId': user.uid,
    });
    _audit.log(
      workspaceId: invitation.workspaceId,
      actorId: user.uid,
      actorName: user.displayName,
      action: 'invitation.rejected',
      entityType: 'invitation',
      entityId: invitation.id,
      metadata: {'invitedEmail': invitation.invitedEmail},
    );
  }

  Future<void> revokeInvitation({
    required Invitation invitation,
    required String actorId,
    required String actorName,
  }) async {
    if (invitation.status != InvitationStatus.pending) {
      throw RepoException('Hanya undangan yang masih menunggu yang dapat dibatalkan.');
    }
    await fs.collection(Collections.invitations).doc(invitation.id).update({
      'status': InvitationStatus.revoked.name,
      'revokedAt': FieldValue.serverTimestamp(),
    });
    _audit.log(
      workspaceId: invitation.workspaceId,
      actorId: actorId,
      actorName: actorName,
      action: 'invitation.revoked',
      entityType: 'invitation',
      entityId: invitation.id,
      metadata: {'invitedEmail': invitation.invitedEmail},
    );
  }

  Future<int> expireStale(String wsId) async {
    final snap = await fs
        .collection(Collections.invitations)
        .where('workspaceId', isEqualTo: wsId)
        .where('status', isEqualTo: 'PENDING')
        .get();
    var expired = 0;
    final batch = fs.batch();
    for (final doc in snap.docs) {
      final inv = Invitation.fromDoc(doc);
      if (!inv.effectivelyPending) {
        batch.update(doc.reference, {'status': InvitationStatus.expired.name});
        expired++;
      }
    }
    if (expired > 0) await batch.commit();
    return expired;
  }
}
