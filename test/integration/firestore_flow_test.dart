import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:buku_laris/firebase_options.dart';

/// Integration tests against the Firebase Emulator Suite.
///
/// Run (after `firebase emulators:start`):
///   set FLUTTER_TEST_EMULATOR=1
///   set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
///   set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
///   flutter test test/integration
///
/// Skipped automatically in normal CI/local runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['FLUTTER_TEST_EMULATOR'] != '1') {
    test('integration suite requires Firebase Emulator', () {
      markTestSkipped(
        'Start firebase emulators and set FLUTTER_TEST_EMULATOR=1 to run.',
      );
    });
    return;
  }

  late FirebaseFirestore fs;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    fs = FirebaseFirestore.instance;
    fs.useFirestoreEmulator('127.0.0.1', 8080);
  });

  String uniqueId() =>
      'it_${DateTime.now().microsecondsSinceEpoch}_${Object().hashCode.abs()}';

  test('workspace creation batch writes owner membership and counter', () async {
    final uid = uniqueId();
    final wsRef = fs.collection('workspaces').doc();
    final batch = fs.batch();

    batch.set(wsRef, {
      'ownerId': uid,
      'name': 'Warung Uji ${uniqueId()}',
      'businessModels': ['physicalProduct'],
      'currency': 'IDR',
      'timezone': 'Asia/Jakarta',
      'status': 'ACTIVE',
      'personalWorkspace': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(wsRef.collection('members').doc(uid), {
      'userId': uid,
      'workspaceId': wsRef.id,
      'role': 'OWNER',
      'status': 'ACTIVE',
      'permissions': ['dashboardView'],
    });
    batch.set(wsRef.collection('counters').doc('sales'), {'seq': 0});
    batch.set(fs.collection('users').doc(uid), {
      'uid': uid,
      'email': '$uid@test.local',
      'displayName': 'Tester',
      'workspaceIds': [wsRef.id],
    });

    await batch.commit();

    final ws = await wsRef.get();
    expect(ws.exists, isTrue);
    expect(ws.data()!['ownerId'], uid);
    final member = await wsRef.collection('members').doc(uid).get();
    expect(member.exists, isTrue);
    final counter = await wsRef.collection('counters').doc('sales').get();
    expect(counter.data()!['seq'], 0);
  });

  test('daily summary merge increments aggregate fields', () async {
    final wsRef = fs.collection('workspaces').doc();
    await wsRef.set({
      'ownerId': 'seed',
      'name': 'x',
      'status': 'ACTIVE',
      'createdAt': FieldValue.serverTimestamp(),
    });
    const dayKey = '2026-08-25';
    final summary = wsRef.collection('dailySummaries').doc(dayKey);

    await summary.set({
      'revenue': FieldValue.increment(50000),
      'orderCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await summary.set({
      'revenue': FieldValue.increment(20000),
      'cashIn': FieldValue.increment(70000),
    }, SetOptions(merge: true));

    final snap = await summary.get();
    expect(snap.data()!['revenue'], 70000);
    expect(snap.data()!['orderCount'], 1);
    expect(snap.data()!['cashIn'], 70000);
  });

  test('sale document rejects unknown workspace writes via rules', () async {
    final outsider = fs.collection('workspaces').doc('definitely-missing');
    expect(
      () => outsider.collection('sales').add({
        'transactionNumber': 'TRX-FAKE-0001',
        'grandTotal': 1000,
        'items': [],
      }),
      throwsA(anything),
    );
  });
}
