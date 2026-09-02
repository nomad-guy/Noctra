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
  /// The latest requested icon — worker processes this, then loops.
  static Completer<IconChangeResult>? _latestCompleter;
  /// All pending completers that need resolution when the batch finishes.
  static final List<Completer<IconChangeResult>> _pendingCompleters = [];

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
          debugPrint(
            'DynamicIconService: native returned unknown icon key "$key" — '
            'launcher state may be inconsistent',
          );
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

    // Set desired state — worker will pick it up
    _desiredIcon = icon;

    // Create a completer for THIS request
    final completer = Completer<IconChangeResult>();

    if (!_workerRunning) {
      // No worker running — start one
      _latestCompleter = completer;
      _startWorker();
    } else {
      // Worker is running — add to pending list
      // When batch completes, all pending callers get resolved
      _pendingCompleters.add(completer);
    }

    return completer.future;
  }

  /// Worker loop: processes the latest desired icon, repeats if more arrive.
  /// Uses clean state transitions to avoid races at shutdown.
  static void _startWorker() async {
    _workerRunning = true;

    while (true) {
      final icon = _desiredIcon;
      if (icon == null) {
        // No pending request — worker is done
        break;
      }

      // Clear desired before starting the operation (single-threaded Dart — safe)
      _desiredIcon = null;

      final previousIcon = _actualIcon;

      try {
        await _channel.invokeMethod('setIcon', {'icon': icon.key});
        _actualIcon = icon;

        // Complete the active request
        if (_latestCompleter != null && !_latestCompleter!.isCompleted) {
          _latestCompleter!.complete(IconChangeResult.applied);
          _latestCompleter = null;
        }
      } catch (e) {
        _actualIcon = previousIcon;
        debugPrint('DynamicIconService: icon switch failed — $e');

        // Complete the active request as failed
        if (_latestCompleter != null && !_latestCompleter!.isCompleted) {
          _latestCompleter!.complete(IconChangeResult.failed);
          _latestCompleter = null;
        }

        // Complete all pending as failed too (they were for the same attempt)
        for (final c in _pendingCompleters) {
          if (!c.isCompleted) {
            c.complete(IconChangeResult.failed);
          }
        }
        _pendingCompleters.clear();

        _workerRunning = false;
        return;
      }

      // After success, loop back to check if _desiredIcon was updated
      // while we were executing (another request may have arrived)
    }

    // Worker finished — resolve pending completers
    // The active completer was already completed above.
    // Pending completers were superseded by the latest successful request.
    for (final c in _pendingCompleters) {
      if (!c.isCompleted) {
        c.complete(IconChangeResult.superseded);
      }
    }
    _pendingCompleters.clear();

    _workerRunning = false;
  }
}
