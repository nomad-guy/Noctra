import 'dart:async';
import '../../../../core/platform/contracts/update_service.dart';
import '../app_update_service.dart';

/// Android update provider handling verified APK downloads and system package install intents.
class AndroidUpdateProvider implements UpdateProvider {
  @override
  Future<UpdateCheckResult> checkForUpdates({required String currentVersion}) async {
    try {
      final info = await AppUpdateService.checkForUpdate();
      if (!info.hasUpdate) return UpdateCheckResult.noUpdate;

      return UpdateCheckResult(
        hasUpdate: true,
        release: UpdateReleaseInfo(
          version: info.latestVersion,
          changelog: info.releaseNotes,
          downloadUrl: info.downloadUrl,
          expectedSha256: info.expectedSha256,
          platformTarget: 'android',
        ),
      );
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        errorMessage: 'Failed to check for updates: $e',
      );
    }
  }

  @override
  Future<UpdateInstallResult> performUpdate(
    UpdateReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final info = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '',
        latestVersion: release.version,
        releaseNotes: release.changelog,
        downloadUrl: release.downloadUrl,
        expectedSha256: release.expectedSha256 ?? '',
      );

      final filePath = await AppUpdateService.downloadAndVerifyApk(
        info,
        onProgress: onProgress != null
            ? (received, total) {
                if (total > 0) onProgress(received / total);
              }
            : null,
      );

      if (filePath == null) {
        return const UpdateInstallResult(
          UpdateInstallStatus.failed,
          message: 'Download or verification failed',
        );
      }

      return UpdateInstallResult.success;
    } catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.failed,
        message: 'Install failed: $e',
      );
    }
  }
}
