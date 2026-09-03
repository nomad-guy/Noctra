import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/noctra_logger.dart';
import '../../ui/widgets/glass_card.dart';

/// Atomically promote a fully-verified `.part` file to its final name.
/// Two concurrent verified downloads of the same version target the same
/// final path; delete-then-rename interleavings can collide (rename onto
/// an existing file fails on some platforms), so retry briefly. Content
/// is identical for every attempt that reaches this point (same digest),
/// so whichever rename lands last is correct.
Future<void> _promoteVerifiedFile(File tmp, File finalFile) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      if (finalFile.existsSync()) finalFile.deleteSync();
      await tmp.rename(finalFile.path);
      return;
    } on FileSystemException {
      if (attempt == 2) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

/// Collects the [Digest] produced by a chunked hash conversion without
/// buffering the hashed bytes themselves.
class _DigestAccumulator implements Sink<crypto.Digest> {
  final List<crypto.Digest> digests = [];
  @override
  void add(crypto.Digest data) => digests.add(data);
  @override
  void close() {}
}

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  /// SHA-256 of the APK asset extracted from the GitHub release.
  /// Required — install MUST be refused when this is missing. Trusting
  /// an APK without a pinned digest would defeat the entire update
  /// security model.
  final String expectedSha256;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.expectedSha256,
  });
}

class AppUpdateService {
  static const String _releaseApiUrl =
      'https://api.github.com/repos/nomad-guy/Noctra/releases/latest';
  static const String fallbackDownloadUrl =
      'https://github.com/nomad-guy/Noctra/releases/latest/download/noctra-universal-release.apk';
  static const String fallbackDownloadAssetName =
      'noctra-universal-release.apk';
  static const String expectedApplicationId = 'com.nomadguy.noctra';
  static const installerCheckChannel =
      MethodChannel('com.nomadguy.noctra/installer_check');

  /// Absolute signer pin: lower-case SHA-256 of the signing certificate
  /// that genuine Noctra release APKs MUST carry.
  ///
  /// Leave empty to rely on SIGNER CONTINUITY alone — every update must
  /// be signed by the same key as the currently installed app. To enable
  /// absolute pinning (so even the currently installed build must be
  /// genuine and every update must match the pinned key), set this to
  /// the production keystore certificate digest:
  ///
  ///     keytool -list -v -keystore noctra-release.keystore
  ///     → "SHA256: ..." (colons/whitespace removed, lower-case)
  ///
  /// Mutable only so tests can exercise both modes; production ships
  /// with the owner's chosen value.
  static String pinnedSignerSha256 = '';

  /// Returns the current device ABI identifier ('arm64-v8a', 'armeabi-v7a',
  /// 'x86_64', or 'universal' on Web / unknown architecture).
  static String get currentDeviceAbi {
    if (kIsWeb) return 'universal';
    try {
      final abi = Abi.current();
      if (abi == Abi.androidArm64) return 'arm64-v8a';
      if (abi == Abi.androidArm) return 'armeabi-v7a';
      if (abi == Abi.androidX64) return 'x86_64';
    } catch (_) {}
    return 'universal';
  }

  static const notifyChannel =
      MethodChannel('com.nomadguy.noctra/update_notify');
  static const _signingCertChannel =
      MethodChannel('com.nomadguy.noctra/signing_cert');
  static const Duration _downloadTimeout = Duration(minutes: 10);

  /// Inactivity guard while streaming the body — if no bytes arrive for
  /// this long the download is treated as stalled and aborted. (The
  /// overall 10-minute [_downloadTimeout] deadline already bounds the
  /// whole operation across redirect hops.)
  static const Duration _readIdleTimeout = Duration(seconds: 30);
  static const int _defaultMaxDownloadBytes = 200 * 1024 * 1024;

  /// 200 MB hard cap on APK size — applied to the declared Content-Length
  /// AND incrementally while streaming. Test seam; production always uses
  /// the 200 MB default.
  @visibleForTesting
  static int maxDownloadBytes = _defaultMaxDownloadBytes;

  @visibleForTesting
  static int get defaultMaxDownloadBytes => _defaultMaxDownloadBytes;
  static const List<String> _trustedReleaseHosts = [
    'github.com',
    'objects.githubusercontent.com',
    'api.github.com',
  ];
  static bool _notifiedThisSession = false;
  static String? _cachedCurrentVersion;

  /// Read the running app version at runtime instead of hard-coding it.
  static Future<String> _resolveCurrentVersion() async {
    if (_cachedCurrentVersion != null) return _cachedCurrentVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.isNotEmpty ? 'v${info.version}' : 'v0.0.0';
      _cachedCurrentVersion = v;
      return v;
    } catch (_) {
      return 'v0.0.0';
    }
  }

  /// Synchronous accessor for the cached runtime version. Returns
  /// `v0.0.0` until [_resolveCurrentVersion] has run.
  static String get currentVersion => _cachedCurrentVersion ?? 'v0.0.0';

  /// Silently checks GitHub and fires a system notification if a newer version exists.
  static Future<void> notifyUpdateAvailable() async {
    if (kIsWeb || _notifiedThisSession) return;
    try {
      final info = await checkForUpdate();
      if (!info.hasUpdate) return;
      _notifiedThisSession = true;
      await notifyChannel.invokeMethod('showUpdateNotification', {
        'title': 'Noctra ${info.latestVersion} is out',
        'body': 'Tap to download the latest update.',
        'url': info.downloadUrl,
      });
    } catch (_) {}
  }

  static Future<AppUpdateInfo> checkForUpdate() async {
    // When an absolute pin is configured, refuse to even consult the
    // release feed unless the RUNNING app is itself signed by the pinned
    // certificate — a repackaged build must not be able to self-update.
    if (!kIsWeb && pinnedSignerSha256.isNotEmpty) {
      final pinned = await isSignaturePinned(pinnedSignerSha256);
      if (!pinned) {
        NoctraLogger.w(
            'Refusing update check: installed app is not signed by the '
            'pinned certificate');
        return AppUpdateInfo(
          hasUpdate: false,
          currentVersion: await _resolveCurrentVersion(),
          latestVersion: '',
          releaseNotes: '',
          downloadUrl: '',
          expectedSha256: '',
        );
      }
    }
    try {
      final res = await http.get(
        Uri.parse(_releaseApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final latestTag = (data['tag_name'] as String?) ?? 'v0.0.0';
        final notes = (data['body'] as String?) ??
            'Performance optimizations and stability improvements.';

        // Select optimal APK asset: prefer device architecture (e.g. arm64-v8a: ~23.9MB vs universal: ~62MB)
        // Fall back to universal APK if no ABI-specific asset is published.
        String downloadUrl = fallbackDownloadUrl;
        String? expectedSha;
        String? matchedAssetName;
        final assets = data['assets'] as List?;
        if (assets != null) {
          final targetAbi = currentDeviceAbi;
          Map<String, dynamic>? selectedAsset;

          // 1. First priority: device ABI matching asset (e.g. 'arm64-v8a' or 'arm64')
          if (targetAbi != 'universal') {
            for (final a in assets) {
              if (a is Map) {
                final name = (a['name'] as String? ?? '').toLowerCase();
                if (name.endsWith('.apk') &&
                    (name.contains(targetAbi) ||
                        (targetAbi == 'arm64-v8a' && (name.contains('arm64') || name.contains('arm64-v8a'))) ||
                        (targetAbi == 'armeabi-v7a' && (name.contains('armeabi') || name.contains('armv7'))) ||
                        (targetAbi == 'x86_64' && name.contains('x86_64')))) {
                  selectedAsset = Map<String, dynamic>.from(a);
                  break;
                }
              }
            }
          }

          // 2. Second priority: universal APK
          if (selectedAsset == null) {
            for (final a in assets) {
              if (a is Map) {
                final name = (a['name'] as String? ?? '').toLowerCase();
                if (name.contains('universal') && name.endsWith('.apk')) {
                  selectedAsset = Map<String, dynamic>.from(a);
                  break;
                }
              }
            }
          }

          // 3. Third priority: any standalone .apk
          if (selectedAsset == null) {
            for (final a in assets) {
              if (a is Map) {
                final name = (a['name'] as String? ?? '').toLowerCase();
                if (name.endsWith('.apk')) {
                  selectedAsset = Map<String, dynamic>.from(a);
                  break;
                }
              }
            }
          }

          if (selectedAsset != null) {
            downloadUrl =
                selectedAsset['browser_download_url'] as String? ?? downloadUrl;
            matchedAssetName =
                (selectedAsset['name'] as String? ?? '').toLowerCase();
            final digest = selectedAsset['digest'] as String?;
            if (digest != null && digest.startsWith('sha256:')) {
              expectedSha = digest.substring(7);
            }
          }

          // Fall back: search the release body for the SHA-256 that is
          // EXPLICITLY associated with this APK's filename. A bare
          // "first sha256 found" match is ambiguous when a release ships
          // several artifacts (universal + per-ABI), so a lone hash is
          // only accepted when the body pins exactly one hash total;
          // any ambiguity refuses the update.
          if (expectedSha == null && notes.isNotEmpty) {
            expectedSha = extractAssetSha256(notes,
                assetName: matchedAssetName ?? fallbackDownloadAssetName);
          }
        }

        final current = await _resolveCurrentVersion();
        final isNewer = _isVersionNewer(latestTag, current);
        // Refuse to advertise an update if no SHA-256 digest was
        // published. Without a pinned hash, SHA-256 verification
        // cannot be enforced, and a compromised release would bypass
        // the entire trust model. `hasUpdate: false` here means the
        // user will not see the in-app installer at all.
        if (isNewer && (expectedSha == null || expectedSha.isEmpty)) {
          NoctraLogger.w(
              'Refusing update $latestTag: no SHA-256 digest published');
          return AppUpdateInfo(
            hasUpdate: false,
            currentVersion: current,
            latestVersion: current,
            releaseNotes: '',
            downloadUrl: fallbackDownloadUrl,
            expectedSha256: expectedSha ?? '', // empty → never matches
          );
        }
        return AppUpdateInfo(
          hasUpdate: isNewer,
          currentVersion: current,
          latestVersion: latestTag,
          releaseNotes: notes,
          downloadUrl: downloadUrl,
          expectedSha256: expectedSha ?? '',
        );
      }
    } catch (_) {}

    final current = await _resolveCurrentVersion();
    return AppUpdateInfo(
      hasUpdate: false,
      currentVersion: current,
      latestVersion: current,
      releaseNotes: '',
      downloadUrl: fallbackDownloadUrl,
      expectedSha256: '',
    );
  }

  /// Download an APK from [info.downloadUrl], verify it against
  /// [info.expectedSha256] if present, and write it to a private
  /// directory. Returns the local file path on success and `null`
  /// when verification fails or the URL is not on a trusted host.
  /// `onProgress` is invoked with (bytesReceived, totalBytes) where
  /// totalBytes is -1 when the Content-Length header is absent (the UI
  /// renders an indeterminate bar in that case — never a fabricated size).
  ///
  /// Redirection is handled hop-by-hop with the Dart [HttpClient] so that
  /// EVERY hop destination (not just the initial URL) is validated against
  /// the trusted-host allowlist. The http package's own client follows
  /// redirects internally, which would silently accept a malicious
  /// redirect chain after the first host check.
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

    // P0: refuse installs when no SHA-256 is published. The digest is
    // required by AppUpdateInfo's contract, but double-check here so any
    // hand-built AppUpdateInfo still gets refused.
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
    // Unique .part per download attempt: two concurrent downloads (or a
    // retry racing a previous attempt) must never share a partial file,
    // or one could truncate/corrupt the other mid-write. Microseconds can
    // collide when attempts start in the same tick, so add randomness.
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
      // Transport-level failure (connection reset, DNS, timeout, HTTP
      // parser errors). The UI calls this without a try/catch, so it must
      // never throw — convert to a clean refusal and clean up the part.
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
    try {
      final deadline = DateTime.now().add(_downloadTimeout);
      var current = initial;
      for (int hop = 0; hop <= 5; hop++) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          NoctraLogger.w('APK download timed out');
          return null;
        }
        final req = await client.getUrl(current).timeout(remaining);
        // We validate every redirect hop ourselves, so disable the
        // client's silent auto-following for this request.
        req.followRedirects = false;
        req.maxRedirects = 0;
        req.headers.set(HttpHeaders.userAgentHeader, 'Noctra-Update/1.0');
        final resp = await req.close().timeout(remaining);

        if (resp.statusCode >= 300 && resp.statusCode < 400) {
          final loc = resp.headers.value(HttpHeaders.locationHeader);
          // Drain so the connection can be reused/closed cleanly.
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

        // Refuse to write more than the hard cap even if Content-Length
        // is missing or misreported.
        final declared = resp.contentLength; // -1 when absent
        if (declared > maxDownloadBytes) {
          await _drainQuietly(resp);
          NoctraLogger.w('APK too large: $declared bytes');
          return null;
        }

        final sink = tmp.openWrite();
        // Streaming SHA-256: hash each chunk as it arrives — the APK is
        // never accumulated in RAM (200 MB × 2 in memory was the previous
        // design's peak).
        final digestAccumulator = _DigestAccumulator();
        final hashConverter =
            crypto.sha256.startChunkedConversion(digestAccumulator);
        int received = 0;
        try {
          // 30 s inactivity guard: a stalled upstream must not hold the
          // download (and the modal) open forever.
          await for (final chunk in resp.timeout(_readIdleTimeout)) {
            if (received + chunk.length > maxDownloadBytes) {
              await sink.close();
              await tmp.delete();
              NoctraLogger.w('APK exceeded max size, aborted');
              return null;
            }
            hashConverter.add(chunk);
            sink.add(
                chunk); // write the body to disk (hash alone is not an APK)
            received += chunk.length;
            // Unknown length → report -1 so the UI shows an
            // indeterminate bar instead of a fabricated total.
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
          await _promoteVerifiedFile(tmp, finalFile);
          return finalFile.path;
        } catch (e) {
          try {
            hashConverter.close();
          } catch (_) {}
          try {
            await sink.close();
          } catch (_) {}
          if (tmp.existsSync()) {
            try {
              tmp.deleteSync();
            } catch (_) {}
          }
          NoctraLogger.e('APK download failed', e);
          return null;
        }
      }
      NoctraLogger.w('APK download exceeded max redirects');
      return null;
    } finally {
      // Caller owns the client lifecycle and closes it unconditionally.
    }
  }

  /// Best-effort drain of a response body we are deliberately discarding
  /// (redirect / error / oversize). Never throws: some servers declare a
  /// Content-Length they never deliver, which would otherwise surface as
  /// a spurious stream error while we are only trying to free the socket.
  static Future<void> _drainQuietly(HttpClientResponse resp) async {
    try {
      await for (final _ in resp) {}
    } catch (_) {}
  }

  /// Trust check applied to the initial download URL AND to every
  /// redirect destination. HTTPS-only, host must be in or under one of
  /// the trusted release hosts (exact or subdomain match on the parsed
  /// host — never a substring of the full URL).
  @visibleForTesting
  static bool Function(Uri uri) isTrustedDownloadUri =
      _defaultIsTrustedDownloadUri;

  /// The production trust predicate — exposed so tests can restore it
  /// after swapping in a loopback override.
  @visibleForTesting
  static bool Function(Uri uri) get defaultIsTrustedDownloadUri =>
      _defaultIsTrustedDownloadUri;

  /// Test seam for the temporary directory (production uses
  /// path_provider, which is unavailable in pure unit tests).
  @visibleForTesting
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

  /// Verify the running APK's signing certificate against an expected
  /// SHA-256 digest. Returns true only when the platform reports a
  /// signing certificate whose SHA-256 matches [expectedSha256]
  /// (case-insensitive, lower-case normalised).
  ///
  /// The native side (MainActivity.SIGNING_CERT_CHANNEL) reads the
  /// installed package's signing certificate(s) via PackageManager:
  ///   - Android 9+ → GET_SIGNING_CERTIFICATES → signingInfo
  ///   - Android 7-8 → GET_SIGNATURES → info.signatures
  /// and returns a list of SHA-256 hex strings. A match on any of
  /// them counts as pinned (so signing-certificate rotation through
  /// signingCertificateHistory is tolerated).
  ///
  /// Any error (channel missing, PackageManager exception,
  /// malformed response, or empty list) is treated as "not pinned"
  /// and the caller MUST refuse the install. The default-deny
  /// behaviour is intentional: silently returning true would let a
  /// downgraded or repackaged APK slip through.
  static Future<bool> isSignaturePinned(String expectedSha256) async {
    if (kIsWeb) return false;
    if (expectedSha256.isEmpty) return false;
    final want = expectedSha256.toLowerCase();
    try {
      final raw = await _signingCertChannel
          .invokeMethod<List<dynamic>>('getInstalledSigningCertSha256');
      if (raw == null) return false;
      for (final entry in raw) {
        if (entry is String && entry.toLowerCase() == want) return true;
      }
      return false;
    } catch (e) {
      NoctraLogger.w('Signing cert lookup failed: $e');
      return false;
    }
  }

  static Future<void> checkForUpdateManually(BuildContext context,
      [bool isDark = true]) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Checking for new releases...'),
        duration: Duration(seconds: 1)));
    final info = await checkForUpdate();
    if (context.mounted) {
      showUpdateModal(context, info, isDark);
    }
  }

  static bool _isVersionNewer(String latest, String current) =>
      compareVersions(latest, current) > 0;

  /// Extract the SHA-256 that belongs to [assetName] from GitHub release
  /// notes, with an EXPLICIT filename → hash association.
  ///
  /// Rules (fail closed):
  ///  * hashes appearing on a line that also names the asset are
  ///    candidates for that asset;
  ///  * exactly one distinct candidate for [assetName] → accept;
  ///  * no candidate but the body contains exactly ONE hash total →
  ///    accept (single-artifact releases often omit the filename);
  ///  * anything else (multiple named hashes, several anonymous hashes)
  ///    → null: the update is refused rather than risk hashing a
  ///    different artifact.
  @visibleForTesting
  static String? extractAssetSha256(String notes, {required String assetName}) {
    if (notes.trim().isEmpty) return null;
    final wanted = assetName.toLowerCase();
    final named = <String>{};
    final anonymous = <String>{};
    // Note: inline (?i) flags are unsupported by the Dart VM RegExp used
    // here, so the haystack is lower-cased before matching.
    final hashRe = RegExp(r'(?:sha256[:=]?\s*)?\b([a-f0-9]{64})\b');
    final lines = notes.split(RegExp(r'[\r\n]+'));
    String? currentContextFile;

    for (final rawLine in lines) {
      final line = rawLine.toLowerCase();
      // Track current artifact context when a line introduces an .apk filename
      if (line.contains('.apk')) {
        currentContextFile = line;
      }

      for (final m in hashRe.allMatches(line)) {
        final hash = m.group(1)!;
        final isLineMatched = line.contains(wanted);
        final isContextMatched =
            currentContextFile != null && currentContextFile.contains(wanted);

        if (isLineMatched || isContextMatched) {
          named.add(hash);
        } else if (line.contains('.apk') ||
            (currentContextFile != null && currentContextFile.contains('.apk'))) {
          // This hash is associated with another named artifact, not an orphan.
        } else {
          anonymous.add(hash);
        }
      }
    }
    if (named.length == 1) return named.single;
    if (named.isEmpty && anonymous.length == 1) return anonymous.single;
    NoctraLogger.w(
        'Refusing update: release notes SHA-256 association is ambiguous '
        '(named=${named.length}, anonymous=${anonymous.length})');
    return null;
  }

  /// Verify the DOWNLOADED APK before it reaches the installer. The
  /// platform inspects the archive itself (package name, version,
  /// signing-cert digests, plus the installed version). Install is
  /// refused unless ALL of these hold:
  ///  1. package id is Noctra's;
  ///  2. the archive's signer matches the currently installed app's
  ///     signer (continuity), AND — when [pinnedSignerSha256] is set —
  ///     matches that absolute pin;
  ///  3. the archive versionCode is strictly newer than the installed
  ///     versionCode (defence in depth; the OS enforces this too).
  /// Fail-closed on any platform error or missing field.
  static Future<bool> isVerifiedInstallCandidate(String filePath) async {
    if (kIsWeb || filePath.isEmpty) return false;
    try {
      final raw = await installerCheckChannel.invokeMapMethod<String, dynamic>(
          'inspectDownloadedApk', {'filePath': filePath});
      if (raw == null) return false;

      final pkg = raw['packageName'];
      if (pkg != expectedApplicationId) {
        NoctraLogger.w('Refusing install: unexpected package "$pkg"');
        return false;
      }
      if (raw['matchesInstalledSigner'] != true) {
        NoctraLogger.w(
            'Refusing install: APK signer does not match installed app');
        return false;
      }
      if (!_signerDigestsMatchPin(raw['signerDigests'])) {
        NoctraLogger.w(
            'Refusing install: APK signer does not match the pinned cert');
        return false;
      }

      final archiveVersion = _toInt(raw['versionCode']);
      final installedVersion = _toInt(raw['installedVersionCode']);
      if (archiveVersion == null || installedVersion == null) {
        NoctraLogger.w('Refusing install: missing versionCode data');
        return false;
      }
      if (archiveVersion <= installedVersion) {
        NoctraLogger.w(
            'Refusing install: not an upgrade (archive $archiveVersion '
            '<= installed $installedVersion)');
        return false;
      }
      return true;
    } catch (e) {
      NoctraLogger.w('APK pre-install inspection failed: $e');
      return false;
    }
  }

  static bool _signerDigestsMatchPin(dynamic signerDigests) {
    if (pinnedSignerSha256.isEmpty) return true; // continuity only
    if (signerDigests is! List) return false;
    final want = pinnedSignerSha256.toLowerCase();
    return signerDigests.any((d) => d is String && d.toLowerCase() == want);
  }

  static int? _toInt(dynamic v) => v is num ? v.toInt() : null;

  /// Release-tag comparison. Accepts an optional leading `v`, a
  /// `+build` suffix, a `-prerelease` suffix (pre-releases sort older
  /// than their release), and any number of numeric dot-components
  /// (`1.2.3.4` is valid). Returns >0 when [a] is newer than [b], <0
  /// when older, 0 when equal.
  ///
  /// Unparseable input returns 0 — a garbage `latest` tag can never be
  /// advertised as an upgrade, and a malformed installed version can
  /// never silently block or force a downgrade. Fail closed.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    final pa = _parseSemver(a);
    final pb = _parseSemver(b);
    if (pa == null || pb == null) return 0;
    final depth = pa.$1.length > pb.$1.length ? pa.$1.length : pb.$1.length;
    for (int i = 0; i < depth; i++) {
      final x = i < pa.$1.length ? pa.$1[i] : 0;
      final y = i < pb.$1.length ? pb.$1[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    // Equal numeric core: a release beats its own pre-release.
    if (pa.$2 != null && pb.$2 == null) return -1; // a is pre-release
    if (pa.$2 == null && pb.$2 != null) return 1; // b is pre-release
    return 0;
  }

  static (List<int>, String?)? _parseSemver(String raw) {
    final m = RegExp(
            r'^[vV]?(\d+(?:\.\d+)*)(?:-([0-9A-Za-z.\-]+))?(?:\+[0-9A-Za-z.\-]+)?$')
        .firstMatch(raw.trim());
    if (m == null) return null;
    final nums = m.group(1)!.split('.').map(int.parse).toList();
    return (nums, m.group(2));
  }

  static void showUpdateModal(
      BuildContext context, AppUpdateInfo info, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _InAppUpdateModalContent(info: info, isDark: isDark),
    );
  }
}

class _InAppUpdateModalContent extends StatefulWidget {
  final AppUpdateInfo info;
  final bool isDark;

  const _InAppUpdateModalContent({required this.info, required this.isDark});

  @override
  State<_InAppUpdateModalContent> createState() =>
      _InAppUpdateModalContentState();
}

class _InAppUpdateModalContentState extends State<_InAppUpdateModalContent> {
  bool _isDownloading = false;
  double _progress = 0.0;
  double _downloadedMb = 0.0;
  // Nullable: null means the server did not send a Content-Length
  // header, in which case the progress indicator must be indeterminate
  // rather than dividing by a fabricated constant.
  double? _totalMb;
  String? _errorMessage;

  Future<void> _startInAppUpdate() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _downloadedMb = 0.0;
      _totalMb = null;
      _errorMessage = null;
    });

    // P0 #1: route through the single verified download path. The
    // previous version opened a raw http.Client here and wrote to
    // disk without ever comparing the file's SHA-256 to the pinned
    // digest. The button below is also wired to this same method.
    final filePath = await AppUpdateService.downloadAndVerifyApk(
      widget.info,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _downloadedMb = received / (1024 * 1024);
          if (total < 0) {
            _totalMb = null;
            // Indeterminate: pulse the value. Without this the bar
            // would have nothing to advance on a server that omits
            // Content-Length.
            _progress = (_progress + 0.04).clamp(0.0, 0.95);
          } else {
            _totalMb = total / (1024 * 1024);
            _progress = (received / total).clamp(0.0, 1.0);
          }
        });
      },
    );

    if (!mounted) return;

    if (filePath == null) {
      setState(() {
        _isDownloading = false;
        _errorMessage =
            'Update verification failed or download was blocked. Tap external download below.';
      });
      return;
    }

    // Gate the installer on APK identity + signer continuity. The SHA-256
    // already proved the bytes match the published digest; this proves the
    // artifact really is Noctra's, signed by the same key as the installed
    // app, BEFORE the OS package installer is invoked.
    final verified =
        await AppUpdateService.isVerifiedInstallCandidate(filePath);
    if (!verified) {
      // Fail closed: never hand an unverified artifact to the installer.
      try {
        final f = File(filePath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Update package verification failed. The update was not installed.';
        });
      }
      return;
    }

    // Trigger native package installer
    final ok = await AppUpdateService.notifyChannel
        .invokeMethod('installApk', {'filePath': filePath});

    if (ok != true && mounted) {
      setState(() {
        _isDownloading = false;
        _errorMessage =
            'Could not trigger native installer. Tap external download below.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final info = widget.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      child: Icon(Icons.system_update_rounded,
                          size: 20,
                          color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.hasUpdate
                              ? 'New Version Available'
                              : 'App is Up to Date',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black),
                        ),
                        Text(
                          'Installed: ${info.currentVersion} • Latest: ${info.latestVersion}',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (info.hasUpdate) ...[
              Text(
                'RELEASE HIGHLIGHTS',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 8),
              GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(14),
                child: Text(
                  info.releaseNotes.isNotEmpty
                      ? info.releaseNotes
                      : 'Performance optimizations and UI enhancements.',
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(height: 18),
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progress >= 1.0
                          ? 'Launching system installer...'
                          : 'Downloading update (${(_progress * 100).toInt()}%)',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    Text(
                      _totalMb == null
                          ? '${_downloadedMb.toStringAsFixed(1)} MB'
                          : '${_downloadedMb.toStringAsFixed(1)} MB / ${_totalMb!.toStringAsFixed(1)} MB',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else ...[
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.redAccent)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('Update Now (Direct In-App)',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    onPressed: _startInAppUpdate,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                    label: const Text('Or download APK from browser',
                        style: TextStyle(fontSize: 11.5)),
                    onPressed: () async {
                      final uri = Uri.parse(info.downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ] else ...[
              GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent.shade400, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are running the latest official build of Noctra (${info.currentVersion}).',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
