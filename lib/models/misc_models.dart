import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_helpers.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? workspaceId;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.type = NotificationType.system,
    this.workspaceId,
    this.data = const {},
    this.read = false,
    this.createdAt,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return NotificationModel(
      id: doc.id,
      title: str(d['title']),
      body: str(d['body']),
      type: enumFromName(NotificationType.values, d['type'], NotificationType.system),
      workspaceId: strOrNull(d['workspaceId']),
      data: mapOf(d['data']),
      read: boolOf(d['read']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  static Map<String, dynamic> createMap({
    required String title,
    required String body,
    required NotificationType type,
    String? workspaceId,
    Map<String, dynamic>? extra,
  }) =>
      {
        'title': title,
        'body': body,
        'type': type.name,
        'workspaceId': workspaceId,
        'data': extra ?? const {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

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
    required this.id,
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
