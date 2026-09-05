import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/utils/noctra_logger.dart';
import 'app_update_downloader.dart';
import 'app_update_legacy_scan.dart';
import 'app_update_manifest.dart';
import 'app_update_manifest_signature.dart';
import 'app_update_service.dart';

/// Fetches the latest GitHub release and resolves the right artifact:
/// a structured release manifest asset first, the legacy
/// release-notes/asset scan as fallback. All network seams are
/// injectable so the module is deterministic under test.
class AppUpdateReleaseScan {
  static const String releaseApiUrl =
      'https://api.github.com/repos/nomad-guy/Noctra/releases/latest';
  static const Duration apiTimeout = Duration(seconds: 5);
  static const Duration manifestTimeout = Duration(seconds: 8);
  static const int maxManifestBytes = 64 * 1024;

  /// GitHub API seam (default hits the real endpoint).
  static Future<http.Response> Function(Uri uri, {Duration timeout}) apiGet =
      _defaultApiGet;

  /// Manifest-asset content seam (default: per-hop validated fetch).
  static Future<String?> Function(Uri uri) manifestFetcher =
      _defaultManifestFetcher;

  /// Signature seam so signature failures are deterministic under test.
  static Future<bool> Function({
    required String manifest,
    required String detachedSignature,
  }) verifyManifestSignature = AppUpdateManifestSignature.verify;

  static Future<http.Response> _defaultApiGet(Uri uri,
      {Duration timeout = apiTimeout}) {
    return http.get(uri,
        headers: {'Accept': 'application/vnd.github.v3+json'}).timeout(timeout);
  }

  /// Runs the full scan. Returns null when the release feed is
  /// unreachable or malformed (caller maps that to "no update").
  static Future<UpdateScanResult?> scan({
    required String installedVersion,
    int? installedVersionCode,
  }) async {
    final http.Response res;
    try {
      res = await apiGet(Uri.parse(releaseApiUrl));
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final tag = (data['tag_name'] as String?) ?? 'v0.0.0';
    final notes = (data['body'] as String?) ??
        'Performance optimizations and stability improvements.';
    final assets = (data['assets'] as List?) ?? const [];

    final manifestAsset =
        _firstAssetNamed(assets, ReleaseManifest.manifestAssetName);
    if (manifestAsset != null) {
      final signatureAsset =
          _firstAssetNamed(assets, ReleaseManifest.manifestSignatureAssetName);
      final manifest = await _tryFetchManifest(manifestAsset,
          signatureAsset: signatureAsset);
      if (manifest != null) {
        final pkg = ReleaseManifest.selectForAbi(manifest, deviceAbi);
        if (pkg == null) {
          NoctraLogger.w('Release manifest has no package for ABI $deviceAbi '
              '(and no universal fallback)');
          return AppUpdateLegacyScan.noUpdate();
        }
        final uri = ReleaseManifest.downloadUriFor(pkg.file);
        final newer = ReleaseManifest.isNewerThan(manifest,
            installedVersion: installedVersion,
            installedVersionCode: installedVersionCode);
        if (uri == null) {
          NoctraLogger.w('Release manifest carries an unsafe filename');
          return AppUpdateLegacyScan.noUpdate();
        }
        if (!newer) return AppUpdateLegacyScan.noUpdate();
        return UpdateScanResult(
          hasUpdate: true,
          latestVersion: manifest.version,
          releaseNotes: notes,
          downloadUrl: uri.toString(),
          expectedSha256: pkg.sha256,
        );
      }
      if (AppUpdateManifestSignature.isConfigured) {
        NoctraLogger.w('Signed update manifest could not be verified');
        return AppUpdateLegacyScan.noUpdate();
      }
    }

    return AppUpdateLegacyScan.scan(tag, notes, assets, installedVersion);
  }

  static Map<String, dynamic>? _firstAssetNamed(
      List<dynamic> assets, String wanted) {
    for (final a in assets) {
      if (a is Map) {
        final name = (a['name'] as String?) ?? '';
        if (name == wanted) return Map<String, dynamic>.from(a);
      }
    }
    return null;
  }

  /// Validated fetch of the manifest asset: HTTPS + trusted host on
  /// every redirect hop, bounded response size, monotonic timeout.
  static Future<String?> _defaultManifestFetcher(Uri initial) async {
    final client = HttpClient();
    try {
      var current = initial;
      for (int hop = 0; hop <= 5; hop++) {
        final req = await client.getUrl(current).timeout(manifestTimeout);
        req.followRedirects = false;
        req.maxRedirects = 0;
        final resp = await req.close().timeout(manifestTimeout);
        if (resp.statusCode >= 300 && resp.statusCode < 400) {
          final loc = resp.headers.value(HttpHeaders.locationHeader);
          await _drainQuietly(resp);
          if (loc == null) return null;
          final next = current.resolve(loc);
          if (!AppUpdateDownloader.isTrustedDownloadUri(next)) return null;
          current = next;
          continue;
        }
        if (resp.statusCode != 200) {
          await _drainQuietly(resp);
          return null;
        }
        final bytes = <int>[];
        await for (final chunk in resp.timeout(manifestTimeout)) {
          bytes.addAll(chunk);
          if (bytes.length > maxManifestBytes) return null;
        }
        return utf8.decode(bytes, allowMalformed: false);
      }
      return null;
    } catch (e) {
      NoctraLogger.w('Manifest fetch failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<ReleaseManifest?> _tryFetchManifest(
    Map<String, dynamic> asset, {
    Map<String, dynamic>? signatureAsset,
  }) async {
    final rawUrl = (asset['browser_download_url'] as String?) ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !AppUpdateDownloader.isTrustedDownloadUri(uri)) {
      NoctraLogger.w('Manifest asset URL refused: untrusted');
      return null;
    }
    try {
      final body = await manifestFetcher(uri);
      if (body == null) return null;
      if (AppUpdateManifestSignature.isConfigured) {
        if (signatureAsset == null) return null;
        final rawSignatureUrl =
            (signatureAsset['browser_download_url'] as String?) ?? '';
        final signatureUri = Uri.tryParse(rawSignatureUrl);
        if (signatureUri == null ||
            !AppUpdateDownloader.isTrustedDownloadUri(signatureUri)) {
          return null;
        }
        final detachedSignature = await manifestFetcher(signatureUri);
        if (detachedSignature == null ||
            !await verifyManifestSignature(
              manifest: body,
              detachedSignature: detachedSignature,
            )) {
          return null;
        }
      }
      return ReleaseManifest.parse(body);
    } catch (e) {
      NoctraLogger.w('Manifest parse failed: $e');
      return null;
    }
  }

  static Future<void> _drainQuietly(HttpClientResponse resp) async {
    try {
      await for (final _ in resp) {}
    } catch (_) {}
  }

  static String get deviceAbi => AppUpdateService.currentDeviceAbi;
}
