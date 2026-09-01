import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available launcher icon variants. These are visual icon styles, NOT themes.
/// Theme = Flutter UI colors. Icon = Android launcher image.
/// A user can have AMOLED theme with Liquid Glass icon — completely independent.
enum NoctraAppIcon {
  defaultIcon,   // ic_launcher — standard owl (app installs with this)
  noirBlack,     // ic_launcher_dark — white owl on dark bg
  noirWhite,     // ic_launcher_light — black owl on light bg
  liquidGlass,   // ic_launcher_liquid — cyan owl on sapphire bg
}

extension NoctraAppIconX on NoctraAppIcon {
  String get key => switch (this) {
    NoctraAppIcon.defaultIcon => '',
    NoctraAppIcon.noirBlack => 'noir_black',
    NoctraAppIcon.noirWhite => 'noir_white',
    NoctraAppIcon.liquidGlass => 'liquid_glass',
  };

  String get displayName => switch (this) {
    NoctraAppIcon.defaultIcon => 'Noctra Default',
    NoctraAppIcon.noirBlack => 'Noir Black',
    NoctraAppIcon.noirWhite => 'Noir White',
    NoctraAppIcon.liquidGlass => 'Liquid Glass',
  };

  static NoctraAppIcon fromKey(String? key) => switch (key) {
    'noir_black' => NoctraAppIcon.noirBlack,
    'noir_white' => NoctraAppIcon.noirWhite,
    'liquid_glass' => NoctraAppIcon.liquidGlass,
    _ => NoctraAppIcon.defaultIcon,
  };
}

/// Manages the Android launcher icon independently from the Flutter theme.
///
/// Architecture:
/// ```
///   Theme selection ──→ Flutter UI (ThemeData rebuilds)
///   Icon selection   ──→ Android activity-alias toggle
/// ```
///
/// Changing AMOLED theme cannot change the launcher icon.
/// Changing the launcher icon cannot change the theme.
class DynamicIconService {
  static const _channel = MethodChannel('com.nomadguy.noctra/launcher_icon');
  static const _prefsKey = 'selected_icon';

  static NoctraAppIcon _currentIcon = NoctraAppIcon.defaultIcon;
  static bool _changing = false;

  /// The currently active launcher icon.
  static NoctraAppIcon get currentIcon => _currentIcon;

  /// Initialize on app startup — restore persisted icon state.
  /// Does NOT perform an alias toggle (Android already has the right state
  /// from the last session). Just syncs the Dart side.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _currentIcon = NoctraAppIconX.fromKey(saved);
    } catch (e) {
      _currentIcon = NoctraAppIcon.defaultIcon;
    }
  }

  /// Change the launcher icon. Uses optimistic update with rollback on failure.
  ///
  /// The icon switch is serialized: if a previous switch is still in progress,
  /// this call is a no-op. This prevents race conditions from rapid taps.
  static Future<bool> setIcon(NoctraAppIcon icon) async {
    if (_changing) return false;
    if (_currentIcon == icon) return true;
    if (!Platform.isAndroid) return false;

    final previousIcon = _currentIcon;
    _changing = true;

    // Optimistic: update Dart state immediately so UI reflects the change
    _currentIcon = icon;

    try {
      await _channel.invokeMethod('setIcon', {'icon': icon.key})
          .timeout(const Duration(seconds: 3));

      // Persist the choice
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, icon.key);

      return true;
    } catch (e) {
      // Rollback on failure
      _currentIcon = previousIcon;
      debugPrint('DynamicIconService: icon switch failed — $e');
      return false;
    } finally {
      _changing = false;
    }
  }
}
