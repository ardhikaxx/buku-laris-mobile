import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  Timer? _timer;
  bool _checking = false;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 12), (_) => check());
    check();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 4));
      isOnline.value = result.isNotEmpty && result.first.address.isNotEmpty;
    } catch (_) {
      try {
        final socket = await Socket.connect('1.1.1.1', 53,
            timeout: const Duration(seconds: 3));
        socket.destroy();
        isOnline.value = true;
      } catch (_) {
        isOnline.value = false;
      }
    } finally {
      _checking = false;
    }
  }
}
