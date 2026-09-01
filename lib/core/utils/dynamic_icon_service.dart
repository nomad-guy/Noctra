import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../theme/noir_theme.dart';

/// Handles dynamic launcher icon changes on Android.
///
/// Uses the "defer until background" technique to avoid killing the app:
/// - On theme change, we queue the icon swap via MethodChannel.
/// - The native side enables the target alias FIRST (safe), then resets
///   all other aliases to DEFAULT state (not DISABLED — which would kill the app).
/// - The swap is applied when the app goes to the background, so the launcher
///   re-queries the component list and shows the new icon.
class DynamicIconService {
  static const _iconChannel = MethodChannel('com.noctra.app/launcher_icon');
  static NoirThemeMode? _lastMode;
  static String? _pendingIconKey;

  /// Queues a launcher icon swap for [mode].
  /// The actual swap is applied when the app goes to background
  /// (call [applyPending] from WidgetsBindingObserver.didChangeAppLifecycleState).
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
      case NoirThemeMode.liquidGlass:
        iconKey = 'liquid_glass';
        label = 'Noctra | Liquid Glass';
        primaryColor = 0xFF0B1020;
        statusBarBrightness = Brightness.light;
        break;
    }

    // Update system UI immediately (status bar, task switcher)
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

    // Queue the icon swap — actual component toggle happens when app
    // goes to background via applyPending(). This avoids killing the
    // app process while the user is still interacting with it.
    _pendingIconKey = iconKey;
    try {
      await _iconChannel.invokeMethod('setLauncherIcon', {
        'icon': iconKey,
      }).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Called when the app goes to background (paused state).
  /// Executes the queued icon swap so the launcher refreshes.
  static Future<void> applyPending() async {
    if (_pendingIconKey == null) return;
    final key = _pendingIconKey!;
    _pendingIconKey = null;
    try {
      await _iconChannel.invokeMethod('applyPendingIcon', {
        'icon': key,
      }).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Legacy shim — callers that still pass a bool can use this.
  static Future<void> updateAppIcon({required bool isDark}) =>
      updateForTheme(isDark ? NoirThemeMode.noirBlack : NoirThemeMode.noirWhite);
}
