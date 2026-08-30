import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DynamicIconService {
  static bool? _lastIsDark;

  /// Updates the application switcher header (Android & Web)
  static Future<void> updateAppIcon({required bool isDark}) async {
    if (_lastIsDark == isDark) return;
    _lastIsDark = isDark;

    try {
      if (!kIsWeb) {
        SystemChrome.setApplicationSwitcherDescription(
          ApplicationSwitcherDescription(
            label: isDark ? 'Noctra | Noir Black' : 'Noctra | Noir White',
            primaryColor: isDark ? 0xFF000000 : 0xFFFFFFFF,
          ),
        );
      }
    } catch (_) {}
  }
}
