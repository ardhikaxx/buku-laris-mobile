import '../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_model.dart';
import 'base_repository.dart';

class CustomerRepository extends BaseRepository {
  Future<DocumentReference<Map<String, dynamic>>> create(
      String wsId, Customer customer) async {
    return await sub(wsId, Collections.customers).add(customer.toCreateMap());
  }

  Future<void> update(String wsId, Customer customer) async {
    await sub(wsId, Collections.customers)
        .doc(customer.id)
        .update(customer.toUpdateMap());
  }

  Future<void> delete(String wsId, String customerId) async {
    final usedInSales = await sub(wsId, Collections.sales)
        .where('customerId', isEqualTo: customerId)
        .limit(1)
        .get();
    if (usedInSales.docs.isNotEmpty) {
      throw RepoException(
        'Pelanggan ini memiliki riwayat transaksi sehingga tidak dapat dihapus.',
      );
    }
    await sub(wsId, Collections.customers).doc(customerId).delete();
  }

  Stream<Customer?> watchById(String wsId, String customerId) {
    return sub(wsId, Collections.customers).doc(customerId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Customer.fromDoc(doc);
    });
  }

  Future<Customer?> getById(String wsId, String customerId) async {
    final doc = await sub(wsId, Collections.customers).doc(customerId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Customer.fromDoc(doc);
  }

  Future<List<Customer>> searchByName(String wsId, String term, {int limit = 10}) async {
    final cleanTerm = term.trim();
    if (cleanTerm.isEmpty) return [];
    var q = sub(wsId, Collections.customers).orderBy('name');
    q = q.where('name', isGreaterThanOrEqualTo: cleanTerm);
    q = q.where('name', isLessThanOrEqualTo: '$cleanTerm\uf8ff');
    final snap = await q.limit(limit).get();
    return snap.docs.map(Customer.fromDoc).toList();
  }

  Future<List<Customer>> topCustomers(String wsId, {int limit = 5}) async {
    final snap = await sub(wsId, Collections.customers)
        .orderBy('totalSpent', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Customer.fromDoc).toList();
  }

  Stream<List<Customer>> watchAll(String wsId, {String? search}) {
    return sub(wsId, Collections.customers).snapshots().map((s) {
      var list = s.docs.map(Customer.fromDoc).toList();
      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().toLowerCase();
        list = list
            .where((c) =>
                c.name.toLowerCase().contains(term) ||
                c.whatsapp.toLowerCase().contains(term) ||
                c.email.toLowerCase().contains(term))
            .toList();
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Stream<int> watchCount(String wsId) {
    return sub(wsId, Collections.customers)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Query<Map<String, dynamic>> listQuery(String wsId) {
    return sub(wsId, Collections.customers) as Query<Map<String, dynamic>>;
  }
}
