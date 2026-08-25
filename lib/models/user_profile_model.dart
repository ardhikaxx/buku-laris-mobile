import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_helpers.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final List<String> workspaceIds;
  final String? activeWorkspaceId;
  final bool hasPersonalWorkspace;
  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.workspaceIds = const [],
    this.activeWorkspaceId,
    this.hasPersonalWorkspace = false,
    this.createdAt,
  });

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return UserProfile(
      uid: str(d['uid'], doc.id),
      email: str(d['email']),
      displayName: str(d['displayName'], 'Pengguna'),
      photoUrl: strOrNull(d['photoUrl']),
      phoneNumber: strOrNull(d['phoneNumber']),
      workspaceIds: strList(d['workspaceIds']),
      activeWorkspaceId: strOrNull(d['activeWorkspaceId']),
      hasPersonalWorkspace: boolOf(d['hasPersonalWorkspace']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool isCreate = false}) => {
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> fullMap() => {
        'uid': uid,
        'email': email.toLowerCase(),
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'workspaceIds': workspaceIds,
        'activeWorkspaceId': activeWorkspaceId,
        'hasPersonalWorkspace': hasPersonalWorkspace,
      };
}
