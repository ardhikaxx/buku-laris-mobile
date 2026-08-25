import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/enums.dart';
import '../models/payment_method_model.dart';
import '../models/workspace_model.dart';
import '../models/workspace_member_model.dart';
import 'base_repository.dart';

class WorkspaceCreateResult {
  final String workspaceId;
  final List<String> defaultCategoryIds;
  const WorkspaceCreateResult({required this.workspaceId, required this.defaultCategoryIds});
}

class WorkspaceRepository extends BaseRepository {
  Future<WorkspaceCreateResult> createWorkspace({
    required Workspace workspace,
    required String ownerUid,
    required String ownerName,
    required String ownerEmail,
  }) async {
    final wsRef = fs.collection(Collections.workspaces).doc();
    final memberRef = wsRef.collection(Collections.members).doc(ownerUid);
    final userRef = usersCol().doc(ownerUid);

    final categoryNames = _defaultCategories(workspace.businessModels);
    final paymentDefaults = DefaultPaymentMethods.defaults();

    final batch = fs.batch();
    batch.set(wsRef, workspace.toCreateMap());
    batch.set(
      memberRef,
      WorkspaceMember(
        userId: ownerUid,
        workspaceId: wsRef.id,
        displayName: ownerName,
        email: ownerEmail,
        role: UserRole.OWNER,
      ).toCreateMap(),
    );
    for (final name in categoryNames) {
      final catRef = wsRef.collection(Collections.categories).doc();
      batch.set(catRef, {
        'name': name,
        'description': '',
        'parentId': null,
        'productType': null,
        'archived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final pm in paymentDefaults) {
      final pmRef = wsRef.collection(Collections.paymentMethods).doc();
      batch.set(pmRef, pm.toMap(isCreate: true));
    }
    batch.set(wsRef.collection(Collections.counters).doc('sales'), {'seq': 0});
    batch.update(userRef, {
      'workspaceIds': FieldValue.arrayUnion([wsRef.id]),
      'activeWorkspaceId': wsRef.id,
      if (workspace.isPersonalWorkspace) 'hasPersonalWorkspace': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return WorkspaceCreateResult(workspaceId: wsRef.id, defaultCategoryIds: []);
  }

  Stream<Workspace?> watch(String wsId) {
    return workspaceDoc(wsId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Workspace.fromDoc(doc);
    });
  }

  Future<Workspace?> getById(String wsId) async {
    final doc = await workspaceDoc(wsId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Workspace.fromDoc(doc);
  }

  Future<void> updateBasics(String wsId, Map<String, dynamic> fields) async {
    await workspaceDoc(wsId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSettings(String wsId, WorkspaceSettings settings) async {
    await workspaceDoc(wsId).update({
      'settings': settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<int> cascadeDelete({
    required String wsId,
    void Function(int deleted, int phase)? onProgress,
  }) async* {
    final subcollections = [
      Collections.auditLogs,
      Collections.stockMovements,
      Collections.sales,
      Collections.cashTransactions,
      Collections.products,
      Collections.categories,
      Collections.customers,
      Collections.paymentMethods,
      Collections.counters,
      Collections.dailySummaries,
      Collections.members,
    ];

    var deleted = 0;
    for (final name in subcollections) {
      var more = true;
      while (more) {
        final snap = await sub(wsId, name).limit(AppConstants.cascadeBatchSize).get();
        if (snap.docs.isEmpty) {
          more = false;
          break;
        }
        final batch = fs.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        deleted += snap.docs.length;
        onProgress?.call(deleted, subcollections.indexOf(name));
        if (snap.docs.length < AppConstants.cascadeBatchSize) more = false;
      }
      yield deleted;
    }

    final invitations = await fs
        .collection(Collections.invitations)
        .where('workspaceId', isEqualTo: wsId)
        .get();
    for (var i = 0; i < invitations.docs.length; i += AppConstants.cascadeBatchSize) {
      final chunk = invitations.docs.sublist(
        i,
        (i + AppConstants.cascadeBatchSize) > invitations.docs.length
            ? invitations.docs.length
            : i + AppConstants.cascadeBatchSize,
      );
      final batch = fs.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += chunk.length;
      onProgress?.call(deleted, -1);
    }

    await workspaceDoc(wsId).delete();
    yield deleted + 1;
  }

  List<String> _defaultCategories(Set<BusinessModel> models) {
    final cats = <String>{};
    if (models.contains(BusinessModel.physicalProduct)) cats.addAll(['Umum', 'Peralatan']);
    if (models.contains(BusinessModel.digitalProduct)) cats.add('Produk Digital');
    if (models.contains(BusinessModel.service)) cats.add('Jasa');
    if (models.contains(BusinessModel.layanan)) cats.add('Layanan');
    if (cats.isEmpty) cats.add('Umum');
    return cats.toList();
  }
}
