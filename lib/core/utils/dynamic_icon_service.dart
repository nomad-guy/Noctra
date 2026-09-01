import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Available launcher icon variants. These are visual icon styles, NOT themes.
/// Theme = Flutter UI colors. Icon = Android launcher image.
enum NoctraAppIcon {
  defaultIcon,
  noirBlack,
  noirWhite,
  liquidGlass,
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

  /// Parse from Android key. Returns null for unknown keys (no silent default).
  static NoctraAppIcon? fromKey(String? key) => switch (key) {
    'default' => NoctraAppIcon.defaultIcon,
    'noir_black' => NoctraAppIcon.noirBlack,
    'noir_white' => NoctraAppIcon.noirWhite,
    'liquid_glass' => NoctraAppIcon.liquidGlass,
    _ => null,
  };
}

/// Manages the Android launcher icon independently from the Flutter theme.
///
/// Architecture: Android PackageManager is the single source of truth.
/// - On init: calls reconcileAndInit() which reconciles + returns actual icon
/// - On change: calls setIcon, waits for completion, updates state
/// - No duplicate persistence (Android persists via SharedPreferences)
/// - Latest-wins: only the final requested icon is applied
class DynamicIconService {
  static const _channel = MethodChannel('com.nomadguy.noctra/launcher_icon');

  /// The currently active launcher icon (read from Android on init).
  static NoctraAppIcon _currentIcon = NoctraAppIcon.defaultIcon;
  static NoctraAppIcon get currentIcon => _currentIcon;

  // ---- Worker state ----
  static bool _workerRunning = false;
  static Completer<void>? _pendingCompleter;
  static NoctraAppIcon? _desiredIcon;

  /// Initialize on app startup — single native call that reconciles state
  /// and returns the actual icon. Android is the source of truth.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      final key = await _channel.invokeMethod<String>('reconcileAndInit');
      if (key != null) {
        _currentIcon = NoctraAppIconX.fromKey(key) ?? NoctraAppIcon.defaultIcon;
      }
    } catch (e) {
      debugPrint('DynamicIconService: reconcileAndInit failed — $e');
      _currentIcon = NoctraAppIcon.defaultIcon;
    }
  }

  /// Request an icon change. Returns a Future that completes when the
  /// FINAL requested icon has been applied (latest-wins).
  ///
  /// Every caller gets a Future that resolves to the outcome of the
  /// last request in the queue, not their individual request.
  static Future<bool> setIcon(NoctraAppIcon icon) async {
    if (_currentIcon == icon) return true;
    if (!Platform.isAndroid) return false;

    // Set desired state — worker will pick it up
    _desiredIcon = icon;

    // If worker isn't running, start it
    if (!_workerRunning) {
      return _runWorker();
    }

    // Worker is running — it will process _desiredIcon when current op finishes.
    // Return a Future that completes when the worker finishes this batch.
    _pendingCompleter ??= Completer<void>();
    return _pendingCompleter!.future.then((_) => _currentIcon == icon);
  }

  /// Worker loop: processes the latest desired icon, repeats if more requests arrive.
  static Future<bool> _runWorker() async {
    _workerRunning = true;
    bool lastSuccess = true;

    while (_desiredIcon != null) {
      final icon = _desiredIcon!;
      _desiredIcon = null;

      final previousIcon = _currentIcon;

      try {
        await _channel.invokeMethod('setIcon', {'icon': icon.key});
        _currentIcon = icon;
        lastSuccess = true;
      } catch (e) {
        _currentIcon = previousIcon;
        debugPrint('DynamicIconService: icon switch failed — $e');
        lastSuccess = false;
      }
    }

    _workerRunning = false;

    // Complete any waiting callers
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete();
      _pendingCompleter = null;
    }

    return lastSuccess;
  }
}
