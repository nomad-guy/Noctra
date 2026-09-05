import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/noctra_logger.dart';
import 'app_update_service.dart';
import 'app_update_transfer.dart';

/// Downloads a verified update APK.
///
/// Responsibilities kept here: input validation, the per-artifact
/// single-flight map, and temp-file naming. The actual byte-range
/// transfer/resume/verification state machine lives in
/// [AppUpdateTransfer].
class AppUpdateDownloader {
  static const Duration downloadTimeout = Duration(minutes: 10);
  static const Duration readIdleTimeout = Duration(seconds: 30);
  static const int _defaultMaxDownloadBytes = 200 * 1024 * 1024;

  static int maxDownloadBytes = _defaultMaxDownloadBytes;

  static int get defaultMaxDownloadBytes => _defaultMaxDownloadBytes;

  static const List<String> _trustedReleaseHosts = [
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
    'githubusercontent.com',
    'api.github.com',
  ];

  static bool Function(Uri uri) isTrustedDownloadUri =
      _defaultIsTrustedDownloadUri;

  static bool Function(Uri uri) get defaultIsTrustedDownloadUri =>
      _defaultIsTrustedDownloadUri;

  static Future<Directory> Function() updateTempDirProvider =
      getTemporaryDirectory;

  /// In-flight single-flight map keyed by expected SHA-256 so concurrent
  /// requests for the same artifact issue exactly one network download.
  static final Map<String, Future<String?>> _inFlight = {};

  static bool _defaultIsTrustedDownloadUri(Uri uri) {
    if (uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    for (final trusted in _trustedReleaseHosts) {
      if (host == trusted || host.endsWith('.$trusted')) return true;
    }
    return false;
  }

  static Future<String?> downloadAndVerifyApk(
    AppUpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final initial = Uri.tryParse(info.downloadUrl);
    if (initial == null) {
      NoctraLogger.w('Refusing APK download: invalid URL');
      return null;
    }
    if (!isTrustedDownloadUri(initial)) {
      NoctraLogger.w(
          'Refusing APK download from untrusted host: ${initial.host}');
      return null;
    }
    if (info.expectedSha256.isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(info.expectedSha256)) {
      NoctraLogger.w('APK install refused: missing or invalid SHA-256');
      return null;
    }

    final key = info.expectedSha256.toLowerCase();
    final active = _inFlight[key];
    if (active != null) {
      NoctraLogger.w('APK download already in flight; sharing result');
      return active;
    }

    final future = _runDownload(initial, info, key, onProgress);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      // Only clear when this exact future is still the map entry, so a
      // newer attempt is never clobbered.
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  static Future<String?> _runDownload(
    Uri initial,
    AppUpdateInfo info,
    String key,
    void Function(int received, int total)? onProgress,
  ) async {
    Directory dir;
    try {
      dir = await updateTempDirProvider();
    } catch (e) {
      NoctraLogger.w('Could not resolve temp directory', e);
      return null;
    }
    final tag = key.substring(0, 16);
    final tmp = File('${dir.path}/noctra-update-$tag.part');
    final finalFile = File('${dir.path}/noctra-update-$tag.apk');

    final transfer = AppUpdateTransfer(
      overallTimeout: downloadTimeout,
      readIdleTimeout: readIdleTimeout,
      maxBytes: maxDownloadBytes,
      isTrusted: isTrustedDownloadUri,
      onProgress: onProgress,
    );
    final client = HttpClient();
    try {
      return await transfer.run(
        client: client,
        initial: initial,
        tmp: tmp,
        finalFile: finalFile,
        expectedSha256: info.expectedSha256,
      );
    } finally {
      client.close(force: true);
    }
  }
}
