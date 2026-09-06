import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/platform/noctra_capabilities.dart';
import '../../features/discovery/infrastructure/jiosaavn_pure_engine.dart';

/// Single unified client for track resolution, search, and decryption across all platforms.
///
/// Seamlessly uses pure-Dart engines ([JioSaavnPureEngine]) everywhere (Windows, Linux,
/// macOS, iOS, Android, and Web), with native Android acceleration when available.
class NativeResolverClient {
  NativeResolverClient._();

  static const MethodChannel _channel =
      MethodChannel('com.nomadguy.noctra/native_resolver');

  /// Searches songs with pure Dart fallback across all platforms.
  static Future<List<Map<String, dynamic>>> searchJioSaavn(
    String query, {
    int limit = 20,
  }) async {
    if (!kIsWeb && NoctraCapabilities.supportsNativeResolver) {
      try {
        final res = await _channel.invokeMethod<List<dynamic>>(
          'searchJioSaavn',
          {'query': query, 'limit': limit},
        );
        if (res != null && res.isNotEmpty) {
          return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return await JioSaavnPureEngine.searchSongs(query, limit: limit);
  }

  /// Resolves 320kbps track stream with pure Dart fallback.
  static Future<String?> resolve320k(
    String title,
    String artist, {
    Duration? timeBudget,
  }) async {
    final pure = await JioSaavnPureEngine.resolveTrackStream(
      title,
      artist,
      timeBudget: timeBudget,
    );
    if (pure != null && pure.isNotEmpty && !pure.contains('preview')) {
      return pure;
    }

    if (!kIsWeb && NoctraCapabilities.supportsNativeResolver) {
      try {
        return await _channel.invokeMethod<String>(
          'resolve320k',
          {'title': title, 'artist': artist},
        );
      } catch (_) {}
    }
    return null;
  }

  /// Decrypts encrypted media URL with pure Dart fallback.
  static Future<String?> decryptUrl(String encUrl) async {
    final pure = JioSaavnPureEngine.decryptMediaUrl(encUrl);
    if (pure != null && pure.isNotEmpty) return pure;

    if (!kIsWeb && NoctraCapabilities.supportsNativeResolver) {
      try {
        final res = await _channel.invokeMethod<String>(
          'decryptUrl',
          {'encryptedUrl': encUrl},
        );
        if (res != null && res.isNotEmpty) return res;
      } catch (_) {}
    }
    return null;
  }

  /// Asks the native engine to extract an InnerTube stream URL for [videoId].
  static Future<String?> extractInnerTube(String videoId) async {
    if (kIsWeb || !NoctraCapabilities.supportsNativeResolver) return null;
    try {
      return await _channel
          .invokeMethod<String>('extractInnerTube', {'videoId': videoId});
    } catch (_) {
      return null;
    }
  }

  /// Fetches radio tracks for [videoId].
  static Future<List<dynamic>?> fetchRadio(String videoId) async {
    if (kIsWeb || !NoctraCapabilities.supportsNativeResolver) return null;
    try {
      return await _channel
          .invokeListMethod('fetchRadio', {'videoId': videoId});
    } catch (_) {
      return null;
    }
  }
}
