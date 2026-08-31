import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DynamicIconService {
  static const _iconChannel = MethodChannel('com.noctra.app/launcher_icon');
  static bool? _lastIsDark;

  /// Updates both the Android Launcher Icon and Task Switcher header
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
        await _iconChannel.invokeMethod('setLauncherIcon', {
          'icon': isDark ? 'noir_black' : 'noir_white',
        });
      }
    } catch (_) {}
  }
}
