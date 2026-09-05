import 'package:shared_preferences/shared_preferences.dart';

/// Decides when an automatic (background) update check is worth doing.
///
/// The auto check must not hammer the GitHub API on every launch: once
/// an update check has run, further auto checks are skipped until
/// [autoCheckInterval] (12 h) has elapsed. Manual checks bypass this
/// entirely and always re-run.
class AppUpdateCadence {
  static const Duration autoCheckInterval = Duration(hours: 12);
  static const String _lastCheckKey = 'noctra_last_auto_update_check_ms';

  /// Clock seam for deterministic tests.
  static DateTime Function() now = DateTime.now;

  /// Persistence seams (default: SharedPreferences).
  static Future<DateTime?> Function() readLastCheck = _defaultReadLastCheck;
  static Future<void> Function(DateTime when) writeLastCheck =
      _defaultWriteLastCheck;

  static Future<DateTime?> _defaultReadLastCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_lastCheckKey);
      if (ms == null || ms <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _defaultWriteLastCheck(DateTime when) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, when.millisecondsSinceEpoch);
    } catch (_) {
      // A failed persistence must not break the update flow; the next
      // launch simply performs another check.
    }
  }

  /// True only when no check has ever run or the last one is older than
  /// [autoCheckInterval]. Safe to call from startup: it never throws.
  static Future<bool> shouldAutoCheckNow() async {
    try {
      final last = await readLastCheck();
      if (last == null) return true;
      return now().difference(last) >= autoCheckInterval;
    } catch (_) {
      return true;
    }
  }

  /// Records that a check just ran. Never throws: a failed write just
  /// means the next launch performs another check.
  static Future<void> recordCheck() async {
    try {
      await writeLastCheck(now());
    } catch (_) {}
  }
}
