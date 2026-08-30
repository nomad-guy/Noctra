import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../ui/widgets/glass_card.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class AppUpdateService {
  static const String currentVersion = 'v1.0.4';
  static const String _releaseApiUrl = 'https://api.github.com/repos/nomad-guy/Noctra/releases/latest';
  static const String fallbackDownloadUrl = 'https://github.com/nomad-guy/Noctra/releases/latest/download/noctra-universal-release.apk';

  static Future<AppUpdateInfo> checkForUpdate() async {
    try {
      final res = await http.get(
        Uri.parse(_releaseApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final latestTag = (data['tag_name'] as String?) ?? currentVersion;
        final notes = (data['body'] as String?) ?? 'Performance optimizations and stability improvements.';

        // Look for Universal APK asset first
        String downloadUrl = fallbackDownloadUrl;
        final assets = data['assets'] as List?;
        if (assets != null) {
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.contains('universal') && name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
              break;
            }
          }
        }

        final isNewer = _isVersionNewer(latestTag, currentVersion);
        return AppUpdateInfo(
          hasUpdate: isNewer,
          currentVersion: currentVersion,
          latestVersion: latestTag,
          releaseNotes: notes,
          downloadUrl: downloadUrl,
        );
      }
    } catch (_) {}

    return const AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseNotes: '',
      downloadUrl: fallbackDownloadUrl,
    );
  }

  static bool _isVersionNewer(String latest, String current) {
    try {
      final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.parse).toList();
      final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.parse).toList();
      for (int i = 0; i < cleanLatest.length && i < cleanCurrent.length; i++) {
        if (cleanLatest[i] > cleanCurrent[i]) return true;
        if (cleanLatest[i] < cleanCurrent[i]) return false;
      }
      return cleanLatest.length > cleanCurrent.length;
    } catch (_) {
      return latest != current;
    }
  }

  static void showUpdateModal(BuildContext context, AppUpdateInfo info, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        child: Icon(Icons.system_update_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.hasUpdate ? 'New Version Available' : 'App is Up to Date',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                          ),
                          Text(
                            'Installed: ${info.currentVersion} • Latest: ${info.latestVersion}',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (info.hasUpdate) ...[
                Text(
                  'RELEASE HIGHLIGHTS',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 8),
                GlassCard(
                  radius: 14,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    info.releaseNotes.isNotEmpty ? info.releaseNotes : 'Performance optimizations and UI enhancements.',
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download Universal APK', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      final uri = Uri.parse(info.downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ] else ...[
                GlassCard(
                  radius: 14,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.greenAccent.shade400, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You are running the latest official build of Noctra (${info.currentVersion}).',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
