import 'package:flutter/foundation.dart';

class NoctraLogger {
  static void d(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint('[NOCTRA DEBUG] $message ${error != null ? '=> $error' : ''}');
    }
  }

  static void i(String message) {
    if (kDebugMode) {
      debugPrint('[NOCTRA INFO] $message');
    }
  }

  static void w(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint('[NOCTRA WARN] $message ${error != null ? '=> $error' : ''}');
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[NOCTRA ERROR] $message ${error != null ? '=> $error' : ''}');
      if (stackTrace != null) {
        debugPrint('[NOCTRA STACK] $stackTrace');
      }
    }
  }
}
