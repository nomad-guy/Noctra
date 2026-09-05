import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/platform/noctra_capabilities.dart';

/// Platform-boundary client for the native Kotlin resolver channel
/// (`com.nomadguy.noctra/native_resolver`).
///
/// Widgets and application services must call this client (or a higher-level
/// resolver) instead of constructing [MethodChannel] themselves. On platforms
/// without the native engine ([NoctraCapabilities.supportsNativeResolver]) it
/// returns `null` — callers fall back to Dart-side resolution.
class NativeResolverClient {
  NativeResolverClient._();

  static const MethodChannel _channel =
      MethodChannel('com.nomadguy.noctra/native_resolver');

  /// Asks the native engine to extract an InnerTube stream URL for
  /// [videoId]. Returns null when unavailable/unsupported/failed — never
  /// throws.
  static Future<String?> extractInnerTube(String videoId) async {
    if (kIsWeb || !NoctraCapabilities.supportsNativeResolver) return null;
    try {
      return await _channel
          .invokeMethod<String>('extractInnerTube', {'videoId': videoId});
    } catch (_) {
      return null;
    }
  }
}
