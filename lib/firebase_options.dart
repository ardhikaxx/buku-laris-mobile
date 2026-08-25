import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }
}

static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyCrl1txAnuW6X_8v-ZKQeMqbuYGWQoLdfs',
  appId: '1:627019837892:android:846a6bda3c1d3df53f3491',
  messagingSenderId: '627019837892',
  projectId: 'buku-laris',
  storageBucket: 'buku-laris.firebasestorage.app',
);
