import 'dart:convert';
import 'app_update_verifier.dart';

/// Release-manifest model + strict parser.
///
/// The manifest is published as a GitHub release asset
/// (`noctra-update-manifest.json`) and carries, per ABI, the artifact
/// filename and its pinned SHA-256. The download URL is NEVER read from
/// the manifest: it is always derived from a hard-coded GitHub release
/// download base, so remote metadata cannot redirect the app anywhere.
class ReleaseManifest {
  static const String manifestAssetName = 'noctra-update-manifest.json';
  static const String manifestSignatureAssetName =
      'noctra-update-manifest.json.sig';
  static const String releaseDownloadBase =
      'https://github.com/nomad-guy/Noctra/releases/latest/download/';
  static const int maxManifestChars = 64 * 1024;

  static const Set<String> knownAbis = {
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
    'x86',
    'universal',
  };

  final String version;
  final int? versionCode;
  final int? minimumAndroid;
  final Map<String, ReleaseManifestPackage> packages;

  const ReleaseManifest({
    required this.version,
    required this.packages,
    this.versionCode,
    this.minimumAndroid,
  });

  /// Strict parse. Returns null (fail closed) on any violation.
  static ReleaseManifest? parse(String raw) {
    if (raw.isEmpty || raw.length > maxManifestChars) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final versionRaw = decoded['version'];
    if (versionRaw is! String || versionRaw.trim().isEmpty) return null;
    final version = versionRaw.trim();

    final versionCode = decoded['versionCode'];
    if (versionCode != null && (versionCode is! num || versionCode <= 0)) {
      return null;
    }
    final minimumAndroid = decoded['minimumAndroid'];
    if (minimumAndroid != null &&
        (minimumAndroid is! num || minimumAndroid <= 0)) {
      return null;
    }

    final packagesRaw = decoded['packages'];
    if (packagesRaw is! Map<String, dynamic> || packagesRaw.isEmpty) {
      return null;
    }

    final packages = <String, ReleaseManifestPackage>{};
    for (final entry in packagesRaw.entries) {
      final abiKey = entry.key.trim().toLowerCase();
      if (!knownAbis.contains(abiKey)) return null;
      if (entry.value is! Map<String, dynamic>) return null;
      final pkg = ReleaseManifestPackage.tryParse(
          Map<String, dynamic>.from(entry.value as Map));
      if (pkg == null) return null;
      packages[abiKey] = pkg;
    }
    if (packages.isEmpty) return null;
    return ReleaseManifest(
      version: version,
      versionCode: versionCode?.toInt(),
      minimumAndroid: minimumAndroid?.toInt(),
      packages: packages,
    );
  }

  /// Exact ABI match first, then the universal fallback, then nothing.
  /// An unknown/unsupported device ABI therefore falls back to the
  /// universal artifact only when the publisher provided one.
  static ReleaseManifestPackage? selectForAbi(
      ReleaseManifest manifest, String deviceAbi) {
    final abi = deviceAbi.trim().toLowerCase();
    final exact = manifest.packages[abi];
    if (exact != null) return exact;
    return manifest.packages['universal'];
  }

  /// Derives the download URL from the pinned base + a validated bare
  /// filename. Returns null when [fileName] is not a safe .apk basename.
  static Uri? downloadUriFor(String fileName) {
    if (fileName.isEmpty || fileName.length > 255) return null;
    if (fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName.contains('..')) {
      return null;
    }
    if (!fileName.toLowerCase().endsWith('.apk')) return null;
    return Uri.parse('$releaseDownloadBase$fileName');
  }

  /// Update decision: a strictly-newer semver wins; an equal semver is
  /// still an update when the published versionCode exceeds the
  /// installed build number. Everything else is not an update.
  static bool isNewerThan(
    ReleaseManifest manifest, {
    required String installedVersion,
    int? installedVersionCode,
  }) {
    final delta =
        AppUpdateVerifier.compareVersions(manifest.version, installedVersion);
    if (delta > 0) return true;
    if (delta < 0) return false;
    if (manifest.versionCode != null &&
        installedVersionCode != null &&
        manifest.versionCode! > installedVersionCode) {
      return true;
    }
    return false;
  }
}

class ReleaseManifestPackage {
  final String file;
  final String sha256;

  const ReleaseManifestPackage({required this.file, required this.sha256});

  static final RegExp _sha256Re = RegExp(r'^[a-fA-F0-9]{64}$');

  static ReleaseManifestPackage? tryParse(Map<String, dynamic> raw) {
    final file = raw['file'];
    final sha256 = raw['sha256'];
    if (file is! String || sha256 is! String) return null;
    final safeFile = file.trim();
    if (safeFile.isEmpty ||
        safeFile.contains('/') ||
        safeFile.contains('\\') ||
        safeFile.contains('..') ||
        !safeFile.toLowerCase().endsWith('.apk')) {
      return null;
    }
    final safeSha = sha256.trim();
    if (!_sha256Re.hasMatch(safeSha)) return null;
    return ReleaseManifestPackage(
        file: safeFile, sha256: safeSha.toLowerCase());
  }
}
