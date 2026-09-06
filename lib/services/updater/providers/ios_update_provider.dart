import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/platform/contracts/update_service.dart';

/// iOS update provider adhering to Apple App Store distribution policies.
///
/// Never attempts APK/binary side-loading on iOS devices.
class IOSUpdateProvider implements UpdateProvider {
  final String? appStoreUrl;

  const IOSUpdateProvider({this.appStoreUrl});

  @override
  Future<UpdateCheckResult> checkForUpdates({required String currentVersion}) async {
    // In production iOS builds, versioning is managed via TestFlight / App Store.
    return UpdateCheckResult.noUpdate;
  }

  @override
  Future<UpdateInstallResult> performUpdate(
    UpdateReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    if (appStoreUrl != null) {
      final uri = Uri.tryParse(appStoreUrl!);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return const UpdateInstallResult(UpdateInstallStatus.storeRedirect);
      }
    }
    return UpdateInstallResult.unsupported;
  }
}
