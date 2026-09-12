import 'package:flutter/foundation.dart';

class LogEntry {
  final String level;
  final String message;
  final dynamic error;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  const LogEntry(this.level, this.message, this.error, this.timestamp,
      [this.stackTrace]);

  String toText() {
    final ts = timestamp.toIso8601String();
    final err = error == null ? '' : ' | error: $error';
    final st = (stackTrace == null || stackTrace.toString().isEmpty)
        ? ''
        : '\n    at ${stackTrace.toString().trimRight().split('\n').take(6).join('\n    at ')}';
    return '[$ts] [$level] $message$err$st';
  }
}

/// Central Noctra diagnostic logging.
///
/// Beyond explicit [d]/[i]/[w]/[e] calls, [install] hooks the Flutter
/// framework error channel and the platform dispatcher so *every* uncaught
/// runtime error (widget build errors, unhandled async exceptions, isolate
/// errors) lands in the ring buffer. The buffer can be exported as a .txt
/// file from Settings (see [exportLogs]).
class NoctraLogger {
  static final List<LogEntry> _recentLogs = [];
  static const int _maxLogs = 2000;
  static bool _installed = false;

  static List<LogEntry> get recentLogs =>
      List.unmodifiable(List<LogEntry>.from(_recentLogs));

  static int get entryCount => _recentLogs.length;

  /// Clears the in-memory log buffer (Settings > Diagnostics).
  static void clear() {
    _recentLogs.clear();
    i('Diagnostic log cleared');
  }

  /// Installs global runtime-error capture. Call once from main().
  static void install() {
    if (_installed) return;
    _installed = true;

    // Widget build / layout / paint errors and framework exceptions.
    final originalFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      e('Flutter framework error',
          details.exceptionAsString(), details.stack);
      originalFlutterError?.call(details);
    };

    // Uncaught errors in Dart async code on the root isolate.
    final originalDispatcherError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      e('Uncaught runtime error', error, stack);
      return originalDispatcherError?.call(error, stack) ?? false;
    };

    i('Noctra diagnostic logging installed');
  }

  /// Renders the full buffer as one plain-text document. Actual file export
  /// (platform I/O) lives in the service layer: DiagnosticLogExportService.
  static String buildLogText() {
    const header =
        '========================================================================';
    const divider =
        '------------------------------------------------------------------------';
    final buf = StringBuffer();
    buf.writeln('NOCTRA DIAGNOSTIC LOG');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('Entries: ${_recentLogs.length}');
    buf.writeln(header);
    for (final entry in _recentLogs) {
      buf.writeln(entry.toText());
      buf.writeln(divider);
    }
    return buf.toString();
  }

  static void _record(String level, String message, [dynamic error,
      StackTrace? stackTrace]) {
    while (_recentLogs.length >= _maxLogs) {
      if (_recentLogs.isNotEmpty) _recentLogs.removeAt(0);
    }
    _recentLogs.add(LogEntry(level, message, error, DateTime.now(),
        stackTrace));
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

  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _record('WARN', message, error, stackTrace);
    if (kDebugMode) {
      debugPrint('[NOCTRA WARN] $message ${error != null ? '=> $error' : ''}');
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _record('ERROR', message, error, stackTrace);
    debugPrint('[NOCTRA ERROR] $message ${error != null ? '=> $error' : ''}');
    if (stackTrace != null && kDebugMode) {
      debugPrint('[NOCTRA STACK] $stackTrace');
    }
  }
}
