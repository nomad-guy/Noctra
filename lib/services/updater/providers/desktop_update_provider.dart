import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/platform/contracts/update_service.dart';
import '../app_update_service.dart';

/// Desktop update provider for Windows and Linux environments.
class DesktopUpdateProvider implements UpdateProvider {
  final String platform; // 'windows' or 'linux'

  const DesktopUpdateProvider({this.platform = 'windows'});

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
          platformTarget: platform,
        ),
      );
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        errorMessage: 'Failed to check for desktop updates: $e',
      );
    }
  }

  @override
  Future<UpdateInstallResult> performUpdate(
    UpdateReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.tryParse(release.downloadUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return UpdateInstallResult.success;
      }
      return const UpdateInstallResult(
        UpdateInstallStatus.failed,
        message: 'Could not launch release URL',
      );
    } catch (e) {
      return UpdateInstallResult(
        UpdateInstallStatus.failed,
        message: 'Desktop update failed: $e',
      );
    }
  }
}
