import 'dart:convert';
import 'dart:io';
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
  static const notifyChannel =
      MethodChannel('com.nomadguy.noctra/update_notify');
  static const Duration _downloadTimeout = Duration(minutes: 10);
  static const int _maxDownloadBytes = 200 * 1024 * 1024; // 200 MB hard cap
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

        // Look for Universal APK asset first
        String downloadUrl = fallbackDownloadUrl;
        String? expectedSha;
        final assets = data['assets'] as List?;
        if (assets != null) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.contains('universal') && name.endsWith('.apk')) {
              downloadUrl =
                  asset['browser_download_url'] as String? ?? downloadUrl;
              // GitHub v3 release assets do not expose a top-level digest
              // field. The release body or release notes usually pin the
              // SHA-256; we surface whatever the publisher included so
              // the in-app installer can refuse a mismatched download.
              final digest =
                  asset['digest'] as String?; // e.g. "sha256:abc123..."
              if (digest != null && digest.startsWith('sha256:')) {
                expectedSha = digest.substring(7);
              }
              break;
            }
          }
          // Fall back: search the release body for a "sha256:" hint
          if (expectedSha == null && notes.isNotEmpty) {
            final m = RegExp(r'sha256:([a-fA-F0-9]{64})').firstMatch(notes);
            if (m != null) expectedSha = m.group(1);
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
  /// totalBytes may be -1 when the Content-Length header is absent.
  static Future<String?> downloadAndVerifyApk(
    AppUpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = Uri.tryParse(info.downloadUrl);
    if (uri == null) {
      NoctraLogger.w('Refusing APK download: invalid URL');
      return null;
    }
    if (!_trustedReleaseHosts.contains(uri.host) &&
        !uri.host.endsWith('.github.com')) {
      NoctraLogger.w('Refusing APK download from untrusted host: ${uri.host}');
      return null;
    }

    final client = http.Client();
    try {
      final req = http.Request('GET', uri);
      final resp = await client.send(req).timeout(_downloadTimeout);
      if (resp.statusCode != 200) {
        NoctraLogger.w('APK download HTTP ${resp.statusCode}');
        return null;
      }
      // Refuse to write more than the hard cap even if Content-Length
      // is missing or misreported.
      final declared = resp.contentLength ?? -1;
      if (declared > _maxDownloadBytes) {
        NoctraLogger.w('APK too large: $declared bytes');
        return null;
      }

      // P0: refuse installs when no SHA-256 is published. The
      // contract change to AppUpdateInfo.expectedSha256 makes the
      // digest required at compile time, but we double-check here
      // so that any future caller of this helper that constructs an
      // AppUpdateInfo by hand still gets refused.
      if (info.expectedSha256.isEmpty ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(info.expectedSha256)) {
        NoctraLogger.w('APK install refused: missing or invalid SHA-256');
        return null;
      }

      final dir = await getTemporaryDirectory();
      final tmp =
          File('${dir.path}/noctra-update-${info.latestVersion}.apk.part');
      final finalFile =
          File('${dir.path}/noctra-update-${info.latestVersion}.apk');

      // Stream the body to disk while collecting bytes for the hash.
      final sink = tmp.openWrite();
      final accumulator = <int>[];
      int received = 0;
      try {
        await for (final chunk in resp.stream) {
          if (received + chunk.length > _maxDownloadBytes) {
            await sink.close();
            await tmp.delete();
            NoctraLogger.w('APK exceeded max size, aborted');
            return null;
          }
          accumulator.addAll(chunk);
          received += chunk.length;
          onProgress?.call(received, declared >= 0 ? declared : received);
        }
        await sink.close();
        final hex = crypto.sha256.convert(accumulator).toString();

        if (hex.toLowerCase() != info.expectedSha256.toLowerCase()) {
          await tmp.delete();
          NoctraLogger.w(
              'APK SHA-256 mismatch (expected=${info.expectedSha256}, got=$hex)');
          return null;
        }
        if (finalFile.existsSync()) finalFile.deleteSync();
        await tmp.rename(finalFile.path);
        return finalFile.path;
      } catch (e) {
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
    } finally {
      client.close();
    }
  }

  /// Verify the running APK's signing certificate against an expected
  /// SHA-256 digest. Stub: the real implementation reads the certificate
  /// from the platform `PackageManager` on Android. The placeholder is
  /// kept here so callers can guard installs today.
  static Future<bool> isSignaturePinned(String expectedSha256) async {
    if (kIsWeb) return false;
    try {
      // Production: call into the platform channel to read the
      // installed package's signing certificate and compare.
      // For now, refuse all un-pinned certs.
      return false;
    } catch (_) {
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

  static bool _isVersionNewer(String latest, String current) {
    try {
      final reg = RegExp(r'(\d+)\.(\d+)\.(\d+)');
      final mLatest = reg.firstMatch(latest);
      final mCurrent = reg.firstMatch(current);
      if (mLatest == null || mCurrent == null) return false;

      final lMajor = int.parse(mLatest.group(1)!);
      final lMinor = int.parse(mLatest.group(2)!);
      final lPatch = int.parse(mLatest.group(3)!);

      final cMajor = int.parse(mCurrent.group(1)!);
      final cMinor = int.parse(mCurrent.group(2)!);
      final cPatch = int.parse(mCurrent.group(3)!);

      if (lMajor != cMajor) return lMajor > cMajor;
      if (lMinor != cMinor) return lMinor > cMinor;
      return lPatch > cPatch;
    } catch (_) {
      return false;
    }
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
