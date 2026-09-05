import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/platform/noctra_capabilities.dart';

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

/// Internal request with its own completer for latest-wins queue.
class _IconRequest {
  final NoctraAppIcon icon;
  final Completer<IconChangeResult> completer;
  _IconRequest(this.icon, this.completer);
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
  /// Queue of icon requests with their completers. Worker pops from front.
  static final List<_IconRequest> _requestQueue = [];

  /// Initialize on app startup — single native call that reconciles state
  /// and returns the actual icon. Android is the source of truth.
  static Future<void> init() async {
    if (!NoctraCapabilities.supportsLauncherIcons) {
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
    if (!NoctraCapabilities.supportsLauncherIcons) {
      return IconChangeResult.failed;
    }

    final completer = Completer<IconChangeResult>();
    _requestQueue.add(_IconRequest(icon, completer));

    if (!_workerRunning) {
      _startWorker();
    }
    // If worker is already running, it will pick up the new request
    // when it finishes the current one (latest-wins: intermediate
    // requests are superseded).

    return completer.future;
  }

  /// Worker loop: processes requests from the queue with latest-wins semantics.
  /// When multiple requests arrive during processing, only the most recent
  /// one that hasn't started yet gets applied; the rest are superseded.
  static void _startWorker() async {
    _workerRunning = true;

    while (_requestQueue.isNotEmpty) {
      // Take the latest request (discard earlier pending ones)
      final request = _requestQueue.removeLast();

      // Supersede any remaining queued requests
      for (final stale in _requestQueue) {
        if (!stale.completer.isCompleted) {
          stale.completer.complete(IconChangeResult.superseded);
        }
      }
      _requestQueue.clear();

      final previousIcon = _actualIcon;

      try {
        await _channel.invokeMethod('setIcon', {'icon': request.icon.key});
        _actualIcon = request.icon;

        if (!request.completer.isCompleted) {
          request.completer.complete(IconChangeResult.applied);
        }
      } catch (e) {
        _actualIcon = previousIcon;
        debugPrint('DynamicIconService: icon switch failed — $e');

        if (!request.completer.isCompleted) {
          request.completer.complete(IconChangeResult.failed);
        }
      }
    }

    _workerRunning = false;
  }
}
