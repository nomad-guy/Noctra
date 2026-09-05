import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/noctra_logger.dart';
import 'app_update_cadence.dart';
import 'app_update_downloader.dart';
import 'app_update_release_scan.dart';
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
      // Legacy x86 devices have no Abi constant in this SDK; they map
      // to 'universal' and select the universal artifact when present.
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

  static Future<int?> _resolveCurrentVersionCode() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber.trim());
    } catch (_) {
      return null;
    }
  }

  static String get currentVersion => _cachedCurrentVersion ?? 'v0.0.0';

  static String coerceHttpsDownloadUrl(String url) =>
      AppUpdateVerifier.coerceHttpsDownloadUrl(url);

  /// Whether notifications may be shown. Android 13+ requires the
  /// POST_NOTIFICATIONS runtime permission; if it was denied at
  /// first-run we re-ask here (contextual) but never block on it.
  static Future<bool> notificationsAllowed() async {
    if (kIsWeb) return false;
    try {
      var status = await Permission.notification.status;
      if (status.isDenied && !status.isPermanentlyDenied) {
        status = await Permission.notification.request();
      }
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<void> notifyUpdateAvailable() async {
    if (kIsWeb || _notifiedThisSession) return;
    try {
      if (!await AppUpdateCadence.shouldAutoCheckNow()) return;
      final info = await checkForUpdate();
      AppUpdateCadence.recordCheck();
      NoctraLogger.i(
          'Update auto-check: hasUpdate=${info.hasUpdate} '
          'latest=${info.latestVersion}');
      if (!info.hasUpdate) return;
      _notifiedThisSession = true;
      if (!await notificationsAllowed()) {
        NoctraLogger.w(
            'Update notification suppressed: notifications not granted');
        return;
      }
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
        return _noUpdateInfo();
      }
    }

    final current = await _resolveCurrentVersion();
    final currentCode = await _resolveCurrentVersionCode();
    final scan = await AppUpdateReleaseScan.scan(
      installedVersion: current,
      installedVersionCode: currentCode,
    );

    if (scan == null || !scan.hasUpdate) {
      return AppUpdateInfo(
        hasUpdate: false,
        currentVersion: current,
        latestVersion: current,
        releaseNotes: '',
        downloadUrl: scan?.downloadUrl ?? fallbackDownloadUrl,
        expectedSha256: '',
      );
    }

    if (scan.expectedSha256.isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$')
            .hasMatch(scan.expectedSha256)) {
      NoctraLogger.w(
          'Refusing update ${scan.latestVersion}: no valid SHA-256 digest');
      return AppUpdateInfo(
        hasUpdate: false,
        currentVersion: current,
        latestVersion: current,
        releaseNotes: '',
        downloadUrl: scan.downloadUrl,
        expectedSha256: '',
      );
    }

    return AppUpdateInfo(
      hasUpdate: true,
      currentVersion: current,
      latestVersion: scan.latestVersion,
      releaseNotes: scan.releaseNotes,
      downloadUrl: AppUpdateVerifier.coerceHttpsDownloadUrl(
          scan.downloadUrl),
      expectedSha256: scan.expectedSha256,
    );
  }

  static Future<AppUpdateInfo> _noUpdateInfo() async {
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
      builder: (context) => InAppUpdateModalContent(info: info, isDark: isDark),
    );
  }
}
