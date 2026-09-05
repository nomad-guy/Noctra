import 'package:flutter/foundation.dart';

class LogEntry {
  final String level;
  final String message;
  final dynamic error;
  final DateTime timestamp;

  const LogEntry(this.level, this.message, this.error, this.timestamp);
}

class NoctraLogger {
  static final List<LogEntry> _recentLogs = [];
  static const int _maxLogs = 250;

  static List<LogEntry> get recentLogs => List.unmodifiable(List<LogEntry>.from(_recentLogs));

  static void _record(String level, String message, [dynamic error]) {
    while (_recentLogs.length >= _maxLogs) {
      if (_recentLogs.isNotEmpty) _recentLogs.removeAt(0);
    }
    _recentLogs.add(LogEntry(level, message, error, DateTime.now()));
  }

  static void d(String message, [dynamic error]) {
    _record('DEBUG', message, error);
    if (kDebugMode) {
      debugPrint('[NOCTRA DEBUG] $message ${error != null ? '=> $error' : ''}');
    }
  }

  static void i(String message) {
    _record('INFO', message);
    if (kDebugMode) {
      debugPrint('[NOCTRA INFO] $message');
    }
  }

  static void w(String message, [dynamic error]) {
    _record('WARN', message, error);
    if (kDebugMode) {
      debugPrint('[NOCTRA WARN] $message ${error != null ? '=> $error' : ''}');
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _record('ERROR', message, error);
    debugPrint('[NOCTRA ERROR] $message ${error != null ? '=> $error' : ''}');
    if (stackTrace != null && kDebugMode) {
      debugPrint('[NOCTRA STACK] $stackTrace');
    }
  }
}
