import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../theme/noir_theme.dart';

class DynamicIconService {
  static const _iconChannel = MethodChannel('com.noctra.app/launcher_icon');
  static NoirThemeMode? _lastMode;

  /// Updates the Android Launcher Icon, Task Switcher header, and system status bar
  /// brightness to match the active [NoirThemeMode].
  static Future<void> updateForTheme(NoirThemeMode mode) async {
    if (_lastMode == mode) return;
    _lastMode = mode;

    if (kIsWeb) return;

    // Derive display values from mode.
    final String iconKey;
    final String label;
    final int primaryColor;
    final Brightness statusBarBrightness;

    switch (mode) {
      case NoirThemeMode.noirWhite:
        iconKey = 'noir_white';
        label = 'Noctra | Noir White';
        primaryColor = 0xFFFFFFFF;
        statusBarBrightness = Brightness.dark; // dark icons on white bg
        break;
      case NoirThemeMode.noirAmoled:
        iconKey = 'noir_amoled';
        label = 'Noctra | AMOLED';
        primaryColor = 0xFF000000;
        statusBarBrightness = Brightness.light;
        break;
      case NoirThemeMode.noirBlack:
        iconKey = 'noir_black';
        label = 'Noctra | Noir Black';
        primaryColor = 0xFF000000;
        statusBarBrightness = Brightness.light;
        break;
    }

    try {
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: label, primaryColor: primaryColor),
      );
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: const Color(0x00000000),
          statusBarIconBrightness: statusBarBrightness,
          systemNavigationBarColor: const Color(0x00000000),
          systemNavigationBarIconBrightness: statusBarBrightness,
        ),
      );
    } catch (_) {}

    try {
      await _iconChannel.invokeMethod('setLauncherIcon', {'icon': iconKey});
    } catch (_) {}
  }

  /// Legacy shim — callers that still pass a bool can use this.
  static Future<void> updateAppIcon({required bool isDark}) =>
      updateForTheme(isDark ? NoirThemeMode.noirBlack : NoirThemeMode.noirWhite);
}
