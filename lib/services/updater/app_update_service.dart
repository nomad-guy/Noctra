import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/utils/noctra_logger.dart';
import 'app_update_downloader.dart';
import 'app_update_verifier.dart';
import 'widgets/in_app_update_sheet.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
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
  static const notifyChannel =
      MethodChannel('com.nomadguy.noctra/update_notify');
  static const signingCertChannel =
      MethodChannel('com.nomadguy.noctra/signing_cert');

  static String pinnedSignerSha256 = '';

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

  static int get maxDownloadBytes => AppUpdateDownloader.maxDownloadBytes;
  static set maxDownloadBytes(int value) =>
      AppUpdateDownloader.maxDownloadBytes = value;

  static int get defaultMaxDownloadBytes =>
      AppUpdateDownloader.defaultMaxDownloadBytes;

  static bool Function(Uri uri) get isTrustedDownloadUri =>
      AppUpdateDownloader.isTrustedDownloadUri;
  static set isTrustedDownloadUri(bool Function(Uri uri) value) =>
      AppUpdateDownloader.isTrustedDownloadUri = value;

  static bool Function(Uri uri) get defaultIsTrustedDownloadUri =>
      AppUpdateDownloader.defaultIsTrustedDownloadUri;

  static Future<Directory> Function() get updateTempDirProvider =>
      AppUpdateDownloader.updateTempDirProvider;
  static set updateTempDirProvider(Future<Directory> Function() value) =>
      AppUpdateDownloader.updateTempDirProvider = value;

  static bool _notifiedThisSession = false;
  static String? _cachedCurrentVersion;

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

  static String get currentVersion => _cachedCurrentVersion ?? 'v0.0.0';

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
    if (!kIsWeb && pinnedSignerSha256.isNotEmpty) {
      final pinned =
          await AppUpdateVerifier.isSignaturePinned(pinnedSignerSha256);
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

        String downloadUrl = fallbackDownloadUrl;
        String? expectedSha;
        String? matchedAssetName;
        final assets = data['assets'] as List?;
        if (assets != null) {
          final targetAbi = currentDeviceAbi;
          Map<String, dynamic>? selectedAsset;

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

          if (expectedSha == null && notes.isNotEmpty) {
            expectedSha = AppUpdateVerifier.extractAssetSha256(notes,
                assetName: matchedAssetName ?? fallbackDownloadAssetName);
          }
        }

        final current = await _resolveCurrentVersion();
        final isNewer =
            AppUpdateVerifier.compareVersions(latestTag, current) > 0;
        if (isNewer && (expectedSha == null || expectedSha.isEmpty)) {
          NoctraLogger.w(
              'Refusing update $latestTag: no SHA-256 digest published');
          return AppUpdateInfo(
            hasUpdate: false,
            currentVersion: current,
            latestVersion: current,
            releaseNotes: '',
            downloadUrl: fallbackDownloadUrl,
            expectedSha256: expectedSha ?? '',
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

  static Future<String?> downloadAndVerifyApk(
    AppUpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) =>
      AppUpdateDownloader.downloadAndVerifyApk(info, onProgress: onProgress);

  static Future<bool> isSignaturePinned(String expectedSha256) =>
      AppUpdateVerifier.isSignaturePinned(expectedSha256);

  static Future<bool> isVerifiedInstallCandidate(String filePath) =>
      AppUpdateVerifier.isVerifiedInstallCandidate(filePath);

  static String? extractAssetSha256(String notes,
          {required String assetName}) =>
      AppUpdateVerifier.extractAssetSha256(notes, assetName: assetName);

  static int compareVersions(String a, String b) =>
      AppUpdateVerifier.compareVersions(a, b);

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

  static void showUpdateModal(
      BuildContext context, AppUpdateInfo info, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          InAppUpdateModalContent(info: info, isDark: isDark),
    );
  }
}
