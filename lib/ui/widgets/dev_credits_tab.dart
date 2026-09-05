import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/noir_theme.dart';
import '../../services/updater/app_update_service.dart';
import '../../shared/widgets/glass_card.dart';

import 'noctra_app_logo.dart';

class DevCreditsTab extends StatelessWidget {
  final bool isDark;

  const DevCreditsTab({super.key, required this.isDark});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Developer & Project Card
          GlassCard(
            radius: 18,
            isHighlighted: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NoctraAppLogo(
                        size: 48, radius: 12, isDark: isDark, showGlow: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Noctra Audio Platform',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () =>
                                _openUrl('https://github.com/nomad-guy'),
                            child: Text(
                              'Nomad Guy (@nomad-guy)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                color: isDark
                                    ? NoirColors.blackTextSecondary
                                    : NoirColors.whiteTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'ABOUT NOCTRA (FOSS)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Noctra is a Free and Open Source (FOSS) on-device music platform featuring a two-stage neural recommender (MLP + MMR), SQLite telemetry, hardware DSP effects, and dual Noir aesthetic.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark
                        ? NoirColors.blackTextSecondary
                        : NoirColors.whiteTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _devSpecClickableRow(
                    'Repository',
                    'github.com/nomad-guy/Noctra',
                    () => _openUrl('https://github.com/nomad-guy/Noctra'),
                    isDark),
                _devSpecRow('License', 'GNU GPL v3.0 (FOSS)', isDark),
                _devSpecRow(
                    'Audio Engine', 'Adaptive high-fidelity playback', isDark),
                _devSpecRow(
                    'Recommender', 'On-Device MLP + MMR (Pure Dart)', isDark),
                _devSpecRow(
                    'Telemetry', 'Local SQLite WAL (Zero Cloud)', isDark),
                _devSpecRow('Version',
                    '${AppUpdateService.currentVersion} (Build 7)', isDark),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // License & Legal Disclaimer Card
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEGAL DISCLAIMER & FOSS LICENSE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Noctra is licensed under the GNU General Public License v3.0 (GPL-3.0).\n\nNoctra does not host, store, or redistribute any media files. All streams and lyrics are resolved on-device from public web endpoints for personal, educational, and research use.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: isDark
                        ? NoirColors.blackTextSecondary
                        : NoirColors.whiteTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _devSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devSpecClickableRow(
      String label, String value, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  decoration: TextDecoration.underline,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
