import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import '../../core/utils/noctra_logger.dart';
import 'app_update_service.dart';

class DigestAccumulator implements Sink<crypto.Digest> {
  final List<crypto.Digest> digests = [];
  @override
  void add(crypto.Digest data) => digests.add(data);
  @override
  void close() {}
}

Future<void> promoteVerifiedFile(File tmp, File finalFile) async {
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

class AppUpdateVerifier {
  static Future<bool> isSignaturePinned(String expectedSha256) async {
    if (kIsWeb) return false;
    if (expectedSha256.isEmpty) return false;
    final want = expectedSha256.toLowerCase();
    try {
      final raw = await AppUpdateService.signingCertChannel
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

  /// Returns [url] only when it is an https URL; otherwise returns the
  /// hard-coded https fallback. Keeps remote-controlled update metadata
  /// from ever routing the app (browser intent, notification tap, or
  /// download) to a non-https or custom-scheme destination.
  static String coerceHttpsDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return url;
    }
    return AppUpdateService.fallbackDownloadUrl;
  }

  static String? extractAssetSha256(String notes, {required String assetName}) {
    if (notes.trim().isEmpty) return null;
    final wanted = assetName.toLowerCase();
    final named = <String>{};
    final anonymous = <String>{};
    final hashRe = RegExp(r'(?:sha256[:=]?\s*)?\b([a-f0-9]{64})\b');
    final lines = notes.split(RegExp(r'[\r\n]+'));
    String? currentContextFile;

    for (final rawLine in lines) {
      final line = rawLine.toLowerCase();
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
            (currentContextFile != null &&
                currentContextFile.contains('.apk'))) {
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

  static Future<bool> isVerifiedInstallCandidate(String filePath) async {
    if (kIsWeb || filePath.isEmpty) return false;
    try {
      final raw = await AppUpdateService.installerCheckChannel
          .invokeMapMethod<String, dynamic>(
              'inspectDownloadedApk', {'filePath': filePath});
      if (raw == null) return false;

      final pkg = raw['packageName'];
      if (pkg != AppUpdateService.expectedApplicationId) {
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
    if (AppUpdateService.pinnedSignerSha256.isEmpty) return true;
    if (signerDigests is! List) return false;
    final want = AppUpdateService.pinnedSignerSha256.toLowerCase();
    return signerDigests.any((d) => d is String && d.toLowerCase() == want);
  }

  static int? _toInt(dynamic v) => v is num ? v.toInt() : null;

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
    if (pa.$2 != null && pb.$2 == null) return -1;
    if (pa.$2 == null && pb.$2 != null) return 1;
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
}
