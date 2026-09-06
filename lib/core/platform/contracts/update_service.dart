import 'dart:async';

/// Detailed information about a published application release.
class UpdateReleaseInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final String? expectedSha256;
  final DateTime? publishedAt;
  final String platformTarget;

  const UpdateReleaseInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    this.expectedSha256,
    this.publishedAt,
    required this.platformTarget,
  });
}

/// Outcome of checking for updates.
class UpdateCheckResult {
  final bool hasUpdate;
  final UpdateReleaseInfo? release;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.release,
    this.errorMessage,
  });

  static const noUpdate = UpdateCheckResult(hasUpdate: false);
}

/// Status of the update installation attempt.
enum UpdateInstallStatus {
  success,
  cancelled,
  storeRedirect,
  unsupported,
  failed,
}

/// Outcome of an update installation operation.
class UpdateInstallResult {
  final UpdateInstallStatus status;
  final String? message;

  const UpdateInstallResult(this.status, {this.message});

  static const success = UpdateInstallResult(UpdateInstallStatus.success);
  static const unsupported = UpdateInstallResult(UpdateInstallStatus.unsupported);
}

/// Abstract contract for platform-specific update providers.
abstract interface class UpdateProvider {
  /// Queries whether an update is available for the current platform.
  Future<UpdateCheckResult> checkForUpdates({required String currentVersion});

  /// Installs or facilitates installation of the verified release.
  Future<UpdateInstallResult> performUpdate(
    UpdateReleaseInfo release, {
    void Function(double progress)? onProgress,
  });
}
