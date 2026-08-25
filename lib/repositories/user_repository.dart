import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile_model.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository {
  Future<UserProfile?> getByUid(String uid) async {
    final doc = await usersCol().doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromDoc(doc);
  }

  Stream<UserProfile?> watchByUid(String uid) {
    return usersCol().doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  Future<void> ensureProfile({
    required String uid,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    final ref = usersCol().doc(uid);
    await fs.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (snap.exists) return;
      final profile = UserProfile(
        uid: uid,
        email: email.toLowerCase(),
        displayName: displayName.isNotEmpty ? displayName : email.split('@').first,
        photoUrl: photoUrl,
      );
      txn.set(ref, {
        ...profile.fullMap(),
        'workspaceIds': const [],
        'activeWorkspaceId': null,
        'hasPersonalWorkspace': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateProfile(String uid, {String? displayName, String? phoneNumber, String? photoUrl}) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final name = displayName?.trim();
    if (name != null) data['displayName'] = name;
    final phone = phoneNumber?.trim();
    if (phone != null) data['phoneNumber'] = phone;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    await usersCol().doc(uid).update(data);
  }

  Future<void> setActiveWorkspace(String uid, String? workspaceId) async {
    await usersCol().doc(uid).update({
      'activeWorkspaceId': workspaceId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addWorkspaceToUser(String uid, String workspaceId) async {
    await usersCol().doc(uid).update({
      'workspaceIds': FieldValue.arrayUnion([workspaceId]),
      'activeWorkspaceId': workspaceId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeWorkspaceFromUser(String uid, String workspaceId) async {
    final ref = usersCol().doc(uid);
    final snap = await ref.get();
    final current = snap.exists ? UserProfile.fromDoc(snap) : null;
    final update = <String, dynamic>{
      'workspaceIds': FieldValue.arrayRemove([workspaceId]),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (current?.activeWorkspaceId == workspaceId) {
      update['activeWorkspaceId'] = null;
    }
    await ref.update(update);
  }
}
