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

/// Result of an icon change request.
enum IconChangeResult {
  /// The icon was successfully applied by Android.
  applied,
  /// The request was superseded by a newer request (latest-wins).
  superseded,
  /// The icon change failed on Android side.
  failed,
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
/// Architecture:
/// - Android PackageManager is the single source of truth
/// - On init: single reconcileAndInit call that verifies + returns actual icon
/// - On change: setIcon with transactional rollback on Android side
/// - Dart maintains desired/actual state for UI, but never overrides Android truth
/// - Latest-wins: only the final requested icon is applied
class DynamicIconService {
  static const _channel = MethodChannel('com.nomadguy.noctra/launcher_icon');

  /// The icon that Android currently has enabled (source of truth on startup).
  static NoctraAppIcon _actualIcon = NoctraAppIcon.defaultIcon;
  static NoctraAppIcon get currentIcon => _actualIcon;

  /// Whether initialization completed successfully.
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  // ---- Worker state ----
  static bool _workerRunning = false;
  static NoctraAppIcon? _desiredIcon;
  static Completer<IconChangeResult>? _activeCompleter;
  static Completer<IconChangeResult>? _pendingCompleter;

  /// Initialize on app startup — single native call that reconciles state
  /// and returns the actual icon. Android is the source of truth.
  static Future<void> init() async {
    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }
    try {
      final key = await _channel.invokeMethod<String>('reconcileAndInit');
      if (key != null) {
        final parsed = NoctraAppIconX.fromKey(key);
        if (parsed != null) {
          _actualIcon = parsed;
        } else {
          // Native returned unknown key — this is an error, not a valid state
          debugPrint(
            'DynamicIconService: native returned unknown icon key "$key" — '
            'launcher state may be inconsistent',
          );
          // Keep the default; the native side should have handled this
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('DynamicIconService: reconcileAndInit failed — $e');
      _actualIcon = NoctraAppIcon.defaultIcon;
      _initialized = true;
    }
  }

  /// Request an icon change using latest-wins semantics.
  ///
  /// Returns a Future that completes with:
  /// - [IconChangeResult.applied] if this icon was successfully applied
  /// - [IconChangeResult.superseded] if a newer request replaced this one
  /// - [IconChangeResult.failed] if the operation failed on Android
  static Future<IconChangeResult> setIcon(NoctraAppIcon icon) async {
    if (_actualIcon == icon) return IconChangeResult.applied;
    if (!Platform.isAndroid) return IconChangeResult.failed;

    // Set desired state
    _desiredIcon = icon;

    if (!_workerRunning) {
      // No worker running — start one and give caller a fresh completer
      _activeCompleter = Completer<IconChangeResult>();
      _startWorker();
      return _activeCompleter!.future;
    }

    // Worker is running — new caller gets a pending completer
    // When the worker finishes the batch, pending callers will be resolved
    // based on whether their icon ended up being the final one applied
    final completer = Completer<IconChangeResult>();
    _pendingCompleter = completer;
    return completer.future;
  }

  /// Worker loop: processes the latest desired icon, repeats if more arrive.
  static void _startWorker() async {
    _workerRunning = true;

    while (_desiredIcon != null) {
      final icon = _desiredIcon!;
      _desiredIcon = null;

      final previousIcon = _actualIcon;

      try {
        await _channel.invokeMethod('setIcon', {'icon': icon.key});
        _actualIcon = icon;
      } catch (e) {
        _actualIcon = previousIcon;
        debugPrint('DynamicIconService: icon switch failed — $e');

        // The active request failed
        if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
          _activeCompleter!.complete(IconChangeResult.failed);
          _activeCompleter = null;
        }

        // Pending requests also failed (same attempt)
        if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
          _pendingCompleter!.complete(IconChangeResult.failed);
          _pendingCompleter = null;
        }

        _workerRunning = false;
        return;
      }

      // Success — complete the active request
      if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
        _activeCompleter!.complete(IconChangeResult.applied);
        _activeCompleter = null;
      }
    }

    // Worker finished. Complete pending request.
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      // Check if the pending icon matches what we ended up with
      if (_pendingCompleter != _activeCompleter) {
        // This was a superseded request
        _pendingCompleter!.complete(IconChangeResult.superseded);
      } else {
        _pendingCompleter!.complete(
          _actualIcon == _desiredIcon
              ? IconChangeResult.applied
              : IconChangeResult.failed,
        );
      }
      _pendingCompleter = null;
    }

    _workerRunning = false;
  }
}
