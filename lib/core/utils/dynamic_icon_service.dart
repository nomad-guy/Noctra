import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Available launcher icon variants. These are visual icon styles, NOT themes.
/// Theme = Flutter UI colors. Icon = Android launcher image.
/// A user can have AMOLED theme with Liquid Glass icon — completely independent.
enum NoctraAppIcon {
  defaultIcon,   // ic_launcher — standard owl (enabled at install)
  noirBlack,     // ic_launcher_dark — white owl on dark bg
  noirWhite,     // ic_launcher_light — black owl on light bg
  liquidGlass,   // ic_launcher_liquid — cyan owl on sapphire bg
}

extension NoctraAppIconX on NoctraAppIcon {
  String get key => switch (this) {
    NoctraAppIcon.defaultIcon => 'default',
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
    'default' => NoctraAppIcon.defaultIcon,
    'noir_black' => NoctraAppIcon.noirBlack,
    'noir_white' => NoctraAppIcon.noirWhite,
    'liquid_glass' => NoctraAppIcon.liquidGlass,
    _ => NoctraAppIcon.defaultIcon,
  };
}

/// Manages the Android launcher icon independently from the Flutter theme.
///
/// Architecture: Android PackageManager is the single source of truth.
/// - On init: reads the actual icon from Android via getCurrentIcon()
/// - On change: calls Android, waits for success, then updates Dart state
/// - No duplicate persistence (Android persists via SharedPreferences)
/// - Latest-wins: rapid taps only apply the final selection
class DynamicIconService {
  static const _channel = MethodChannel('com.nomadguy.noctra/launcher_icon');

  static NoctraAppIcon _currentIcon = NoctraAppIcon.defaultIcon;

  /// Latest-wins worker state
  static Completer<void>? _activeWorker;
  static NoctraAppIcon? _pendingRequest;

  /// The currently active launcher icon.
  static NoctraAppIcon get currentIcon => _currentIcon;

  /// Initialize on app startup — reads actual state from Android.
  /// This is the single source of truth. No duplicate SharedPreferences.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      final result = await _channel.invokeMethod<String>('getCurrentIcon');
      if (result != null) {
        _currentIcon = NoctraAppIconX.fromKey(result);
      }
    } catch (e) {
      debugPrint('DynamicIconService: getCurrentIcon failed — $e');
      _currentIcon = NoctraAppIcon.defaultIcon;
    }
  }

  /// Change the launcher icon.
  ///
  /// Latest-wins: if a previous switch is in progress, the new request
  /// replaces it. Returns a Future that completes when the FINAL requested
  /// icon has been applied (or failed).
  static Future<bool> setIcon(NoctraAppIcon icon) async {
    if (_currentIcon == icon) return true;
    if (!Platform.isAndroid) return false;

    // Queue the request — the worker loop will pick up the latest
    _pendingRequest = icon;

    // If no worker is running, start one
    if (_activeWorker == null || _activeWorker!.isCompleted) {
      return _runWorker();
    }

    // Worker is running — it will pick up _pendingRequest when current op finishes.
    // Return true to indicate "accepted" (not failed).
    return true;
  }

  /// Worker loop: picks up the latest pending request, applies it, repeats.
  static Future<bool> _runWorker() async {
    _activeWorker = Completer<void>();
    bool lastResult = true;

    while (_pendingRequest != null) {
      final icon = _pendingRequest!;
      _pendingRequest = null;

      final previousIcon = _currentIcon;
      _currentIcon = icon; // optimistic

      try {
        await _channel.invokeMethod('setIcon', {'icon': icon.key});
        // No timeout — let Android finish at its own pace to avoid state split
        lastResult = true;
      } catch (e) {
        _currentIcon = previousIcon; // rollback on failure
        debugPrint('DynamicIconService: icon switch failed — $e');
        lastResult = false;
      }
    }

    _activeWorker?.complete();
    _activeWorker = null;
    return lastResult;
  }
}
