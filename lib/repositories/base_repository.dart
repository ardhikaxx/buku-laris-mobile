import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

abstract class BaseRepository {
  FirebaseFirestore get fs => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> usersCol() =>
      fs.collection(Collections.users);

  DocumentReference<Map<String, dynamic>> workspaceDoc(String wsId) =>
      fs.collection(Collections.workspaces).doc(wsId);

  CollectionReference<Map<String, dynamic>> sub(String wsId, String name) =>
      workspaceDoc(wsId).collection(name);
}

class RepoException implements Exception {
  final String message;
  RepoException(this.message);

  @override
  String toString() => message;
}
