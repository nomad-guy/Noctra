import '../../core/utils/noctra_logger.dart';
import 'app_update_service.dart';
import 'app_update_verifier.dart';

/// Outcome of scanning the GitHub release for an applicable update.
class UpdateScanResult {
  final bool hasUpdate;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String expectedSha256;

  const UpdateScanResult({
    required this.hasUpdate,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.expectedSha256,
  });
}

/// Fallback scan path used when the structured release manifest is absent
/// (older releases): ABI-name matching against release assets, SHA-256
/// either from the asset digest field or extracted unambiguously from the
/// release notes. Refuses to return an update when no digest can be
/// pinned, and coerces the download URL back to HTTPS.
class AppUpdateLegacyScan {
  static const String fallbackAssetName = 'noctra-universal-release.apk';

  static UpdateScanResult noUpdate() => const UpdateScanResult(
        hasUpdate: false,
        latestVersion: '',
        releaseNotes: '',
        downloadUrl: '',
        expectedSha256: '',
      );

  static UpdateScanResult scan(
      String tag, String notes, List<dynamic> assets, String installedVersion) {
    final abi = AppUpdateService.currentDeviceAbi;
    var downloadUrl = AppUpdateService.fallbackDownloadUrl;
    String? expectedSha;
    String? matchedName;

    Map<String, dynamic>? selected;
    if (abi != 'universal') {
      for (final a in assets) {
        if (a is Map) {
          final name = ((a['name'] as String?) ?? '').toLowerCase();
          if (name.endsWith('.apk') && _nameMatchesAbi(name, abi)) {
            selected = Map<String, dynamic>.from(a);
            break;
          }
        }
      }
    }
    if (selected == null) {
      for (final a in assets) {
        if (a is Map) {
          final name = ((a['name'] as String?) ?? '').toLowerCase();
          if (name.contains('universal') && name.endsWith('.apk')) {
            selected = Map<String, dynamic>.from(a);
            break;
          }
        }
      }
    }
    if (selected == null) {
      for (final a in assets) {
        if (a is Map) {
          final name = ((a['name'] as String?) ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            selected = Map<String, dynamic>.from(a);
            break;
          }
        }
      }
    }
    if (selected != null) {
      downloadUrl =
          (selected['browser_download_url'] as String?) ?? downloadUrl;
      matchedName = ((selected['name'] as String?) ?? '').toLowerCase();
      final digest = selected['digest'] as String?;
      if (digest != null && digest.startsWith('sha256:')) {
        expectedSha = digest.substring(7);
      }
    }
    if (expectedSha == null && notes.isNotEmpty) {
      expectedSha = AppUpdateVerifier.extractAssetSha256(notes,
          assetName: matchedName ?? fallbackAssetName);
    }
    downloadUrl = AppUpdateVerifier.coerceHttpsDownloadUrl(downloadUrl);
    final newer = AppUpdateVerifier.compareVersions(tag, installedVersion) > 0;
    if (newer && (expectedSha == null || expectedSha.isEmpty)) {
      NoctraLogger.w(
          'Refusing update $tag: no unambiguous SHA-256 digest published');
      return noUpdate();
    }
    if (!newer) return noUpdate();
    return UpdateScanResult(
      hasUpdate: true,
      latestVersion: tag,
      releaseNotes: notes,
      downloadUrl: downloadUrl,
      expectedSha256: expectedSha ?? '',
    );
  }

  static bool _nameMatchesAbi(String name, String abi) {
    if (name.contains(abi)) return true;
    if (abi == 'arm64-v8a' &&
        (name.contains('arm64') || name.contains('arm64-v8a'))) {
      return true;
    }
    if (abi == 'armeabi-v7a' &&
        (name.contains('armeabi') || name.contains('armv7'))) {
      return true;
    }
    if (abi == 'x86_64' && name.contains('x86_64')) return true;
    if (abi == 'x86' && name.contains('x86')) return true;
    return false;
  }
}
