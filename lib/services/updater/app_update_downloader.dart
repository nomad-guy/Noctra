import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/noctra_logger.dart';
import 'app_update_service.dart';
import 'app_update_verifier.dart';

class AppUpdateDownloader {
  static const Duration _downloadTimeout = Duration(minutes: 10);
  static const Duration _readIdleTimeout = Duration(seconds: 30);
  static const int _defaultMaxDownloadBytes = 200 * 1024 * 1024;

  static int maxDownloadBytes = _defaultMaxDownloadBytes;

  static int get defaultMaxDownloadBytes => _defaultMaxDownloadBytes;

  static const List<String> _trustedReleaseHosts = [
    'github.com',
    'objects.githubusercontent.com',
    'api.github.com',
  ];

  static bool Function(Uri uri) isTrustedDownloadUri =
      _defaultIsTrustedDownloadUri;

  static bool Function(Uri uri) get defaultIsTrustedDownloadUri =>
      _defaultIsTrustedDownloadUri;

  static Future<Directory> Function() updateTempDirProvider =
      getTemporaryDirectory;

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

    Directory dir;
    try {
      dir = await updateTempDirProvider();
    } catch (e) {
      NoctraLogger.w('Could not resolve temp directory', e);
      return null;
    }

    final attempt =
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';
    final tmp =
        File('${dir.path}/noctra-update-${info.latestVersion}.$attempt.part');
    final finalFile =
        File('${dir.path}/noctra-update-${info.latestVersion}.apk');

    final client = HttpClient();
    try {
      return await _downloadWithRedirects(
          client, initial, tmp, finalFile, info, onProgress);
    } catch (e) {
      NoctraLogger.w('APK download failed: $e');
      if (tmp.existsSync()) {
        try {
          tmp.deleteSync();
        } catch (_) {}
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> _downloadWithRedirects(
    HttpClient client,
    Uri initial,
    File tmp,
    File finalFile,
    AppUpdateInfo info,
    void Function(int received, int total)? onProgress,
  ) async {
    final deadline = DateTime.now().add(_downloadTimeout);
    var current = initial;
    for (int hop = 0; hop <= 5; hop++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        NoctraLogger.w('APK download timed out');
        return null;
      }
      final req = await client.getUrl(current).timeout(remaining);
      req.followRedirects = false;
      req.maxRedirects = 0;
      req.headers.set(HttpHeaders.userAgentHeader, 'Noctra-Update/1.0');
      final resp = await req.close().timeout(remaining);

      if (resp.statusCode >= 300 && resp.statusCode < 400) {
        final loc = resp.headers.value(HttpHeaders.locationHeader);
        await _drainQuietly(resp);
        if (loc == null) {
          NoctraLogger.w('APK redirect without Location header');
          return null;
        }
        final next = current.resolve(loc);
        if (!isTrustedDownloadUri(next)) {
          NoctraLogger.w(
              'APK redirect to untrusted host refused: ${next.host}');
          return null;
        }
        current = next;
        continue;
      }

      if (resp.statusCode != 200) {
        await _drainQuietly(resp);
        NoctraLogger.w('APK download HTTP ${resp.statusCode}');
        return null;
      }

      final declared = resp.contentLength;
      if (declared > maxDownloadBytes) {
        await _drainQuietly(resp);
        NoctraLogger.w('APK too large: $declared bytes');
        return null;
      }

      final sink = tmp.openWrite();
      final digestAccumulator = DigestAccumulator();
      final hashConverter =
          crypto.sha256.startChunkedConversion(digestAccumulator);
      int received = 0;
      try {
        await for (final chunk in resp.timeout(_readIdleTimeout)) {
          if (received + chunk.length > maxDownloadBytes) {
            await sink.close();
            await tmp.delete();
            NoctraLogger.w('APK exceeded max size, aborted');
            return null;
          }
          hashConverter.add(chunk);
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, declared >= 0 ? declared : -1);
        }
        hashConverter.close();
        await sink.flush();
        await sink.close();
        final hex = digestAccumulator.digests.single.toString();
        if (hex.toLowerCase() != info.expectedSha256.toLowerCase()) {
          await tmp.delete();
          NoctraLogger.w(
              'APK SHA-256 mismatch (expected=${info.expectedSha256}, got=$hex)');
          return null;
        }
        await promoteVerifiedFile(tmp, finalFile);
        return finalFile.path;
      } catch (e) {
        try { hashConverter.close(); } catch (_) {}
        try { await sink.close(); } catch (_) {}
        if (tmp.existsSync()) {
          try { tmp.deleteSync(); } catch (_) {}
        }
        NoctraLogger.e('APK download failed', e);
        return null;
      }
    }
    NoctraLogger.w('APK download exceeded max redirects');
    return null;
  }

  static Future<void> _drainQuietly(HttpClientResponse resp) async {
    try {
      await for (final _ in resp) {}
    } catch (_) {}
  }
}
