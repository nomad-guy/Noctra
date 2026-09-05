import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/noctra_logger.dart';
import 'app_update_service.dart';
import 'app_update_verifier.dart';

class AvailableRelease {
  final String tag;
  final String version;
  final String releaseNotes;
  final String publishedAt;
  final String downloadUrl;
  final String expectedSha256;
  final String assetName;
  final bool isCurrent;
  final bool isOlder;

  const AvailableRelease({
    required this.tag,
    required this.version,
    required this.releaseNotes,
    required this.publishedAt,
    required this.downloadUrl,
    required this.expectedSha256,
    required this.assetName,
    required this.isCurrent,
    required this.isOlder,
  });
}

class AppUpdateRollbackService {
  static const String releasesUrl =
      'https://api.github.com/repos/nomad-guy/Noctra/releases';
  static const Duration timeout = Duration(seconds: 6);

  static Future<List<AvailableRelease>> fetchAvailableReleases({
    required String currentVersion,
  }) async {
    final cleanCurrent = currentVersion.replaceFirst(RegExp(r'^v'), '').trim();
    final List<AvailableRelease> results = [];

    try {
      final res = await http.get(
        Uri.parse(releasesUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(timeout);

      if (res.statusCode != 200) return results;

      final list = jsonDecode(res.body);
      if (list is! List) return results;

      final deviceAbi = AppUpdateService.currentDeviceAbi;

      for (final item in list) {
        if (item is! Map) continue;
        final tag = (item['tag_name'] as String?) ?? '';
        final cleanVer = tag.replaceFirst(RegExp(r'^v'), '').trim();
        if (cleanVer.isEmpty) continue;

        final publishedAt = (item['published_at'] as String?)?.split('T').first ?? '';
        final notes = (item['body'] as String?) ?? '';
        final assets = (item['assets'] as List?) ?? const [];

        final apkAsset = _selectApkAsset(assets, deviceAbi);
        if (apkAsset == null) continue;

        final assetName = (apkAsset['name'] as String?) ?? '';
        final downloadUrl = (apkAsset['browser_download_url'] as String?) ?? '';
        if (downloadUrl.isEmpty) continue;

        final sha256 = await _resolveSha256(assets, notes, assetName);

        final cmp = AppUpdateVerifier.compareVersions(cleanVer, cleanCurrent);

        results.add(AvailableRelease(
          tag: tag,
          version: cleanVer,
          releaseNotes: notes,
          publishedAt: publishedAt,
          downloadUrl: downloadUrl,
          expectedSha256: sha256,
          assetName: assetName,
          isCurrent: cmp == 0,
          isOlder: cmp < 0,
        ));
      }
    } catch (e) {
      NoctraLogger.w('Failed to fetch releases for rollback: $e');
    }

    return results;
  }

  static Map<String, dynamic>? _selectApkAsset(
      List<dynamic> assets, String abi) {
    String pattern = 'arm64-v8a';
    if (abi == 'armeabi-v7a') pattern = 'armeabi-v7a';
    if (abi == 'x86_64') pattern = 'x86_64';
    if (abi == 'universal') pattern = 'universal';

    // 1. Try exact ABI
    for (final a in assets) {
      if (a is Map) {
        final name = (a['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.apk') && name.contains(pattern)) {
          return Map<String, dynamic>.from(a);
        }
      }
    }
    // 2. Try universal fallback
    for (final a in assets) {
      if (a is Map) {
        final name = (a['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.apk') && name.contains('universal')) {
          return Map<String, dynamic>.from(a);
        }
      }
    }
    // 3. First .apk
    for (final a in assets) {
      if (a is Map) {
        final name = (a['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.apk')) return Map<String, dynamic>.from(a);
      }
    }
    return null;
  }

  static Future<String> _resolveSha256(
      List<dynamic> assets, String notes, String assetName) async {
    // 1. Check SHA256SUMS.txt
    for (final a in assets) {
      if (a is Map && (a['name'] as String?) == 'SHA256SUMS.txt') {
        final url = a['browser_download_url'] as String?;
        if (url != null && url.isNotEmpty) {
          try {
            final res = await http.get(Uri.parse(url)).timeout(timeout);
            if (res.statusCode == 200) {
              final pattern = RegExp('([a-fA-F0-9]{64})\\s+.*${RegExp.escape(assetName)}');
              final match = pattern.firstMatch(res.body);
              if (match != null) return match.group(1)!;
            }
          } catch (_) {}
        }
      }
    }

    // 2. Check release notes body
    final extracted = AppUpdateVerifier.extractAssetSha256(notes, assetName: assetName);
    if (extracted != null && extracted.isNotEmpty) return extracted;

    return '';
  }

  static void showRollbackDialog(
    BuildContext context,
    AvailableRelease release, {
    required bool isDark,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rollback to ${release.tag}?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'This will download and install ${release.tag} (${release.assetName}).\n\n'
          'Android Notice: If your device blocks direct in-place downgrade, uninstall the current version first and tap the APK in your Downloads folder to install.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: const Text('Download & Rollback',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
