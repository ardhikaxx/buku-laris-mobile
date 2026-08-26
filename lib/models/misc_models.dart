import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_helpers.dart';

class AuditLog {
  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const AuditLog({
    this.id = '',
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.metadata = const {},
    this.createdAt,
  });

  factory AuditLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AuditLog(
      id: doc.id,
      actorId: str(d['actorId']),
      actorName: str(d['actorName']),
      action: str(d['action']),
      entityType: str(d['entityType']),
      entityId: str(d['entityId']),
      metadata: mapOf(d['metadata']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'actorId': actorId,
        'actorName': actorName,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
