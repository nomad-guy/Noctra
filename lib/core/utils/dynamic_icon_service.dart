import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DynamicIconService {
  static const MethodChannel _channel = MethodChannel('com.noctra.app/launcher_icon');
  static bool? _lastIsDark;

  /// Updates the launcher icon (Android)
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
        await _channel.invokeMethod('setLauncherIcon', {
          'icon': isDark ? 'NoirDark' : 'NoirLight',
          'isDark': isDark,
        });
      }
    } catch (_) {}
  }
}
