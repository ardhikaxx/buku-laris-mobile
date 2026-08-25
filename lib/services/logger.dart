import 'package:flutter/foundation.dart';

class Logger {
  Logger._();

  static void d(String message) {
    if (kDebugMode) debugPrint('[BukuLaris] $message');
  }

  static void e(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[BukuLaris][ERROR] $message ${error?.toString() ?? ''}');
    }
  }
}
