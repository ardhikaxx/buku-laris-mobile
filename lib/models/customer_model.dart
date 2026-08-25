import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_helpers.dart';

class Customer {
  final String id;
  final String name;
  final String whatsapp;
  final String email;
  final String address;
  final String notes;
  final int totalTransactions;
  final int totalSpent;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.name,
    this.whatsapp = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.totalTransactions = 0,
    this.totalSpent = 0,
    this.createdAt,
  });

  factory Customer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Customer(
      id: doc.id,
      name: str(d['name'], 'Pelanggan'),
      whatsapp: str(d['whatsapp']),
      email: str(d['email']),
      address: str(d['address']),
      notes: str(d['notes']),
      totalTransactions: intOf(d['totalTransactions']),
      totalSpent: intOf(d['totalSpent']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name.trim(),
        'whatsapp': whatsapp.trim(),
        'email': email.trim().toLowerCase(),
        'address': address.trim(),
        'notes': notes.trim(),
        'totalTransactions': 0,
        'totalSpent': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name.trim(),
        'whatsapp': whatsapp.trim(),
        'email': email.trim().toLowerCase(),
        'address': address.trim(),
        'notes': notes.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
