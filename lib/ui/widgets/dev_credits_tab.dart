import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/noir_theme.dart';
import 'glass_card.dart';
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
                    NoctraAppLogo(size: 48, radius: 12, isDark: isDark, showGlow: true),
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
                            onTap: () => _openUrl('https://github.com/nomad-guy'),
                            child: Text(
                              'Nomad Guy (@nomad-guy)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
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
                  'ABOUT NOCTRA',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Noctra is an autonomous, on-device audio platform combining bit-perfect 320kbps CD lossless stream decryption, YouTube Music InnerTube direct extraction, and a private 16-axis neural vector engine that models acoustic affinities in real time with zero external servers.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _devSpecClickableRow('Repository', 'https://github.com/nomad-guy/Noctra', () => _openUrl('https://github.com/nomad-guy/Noctra'), isDark),
                _devSpecRow('License', 'Personal Use & Restricted Inspection', isDark),
                _devSpecRow('Audio Core', 'JioSaavn 320k Lossless + YouTube InnerTube', isDark),
                _devSpecRow('Build Target', 'v1.0.0-RELEASE (arm64-v8a / multi-abi)', isDark),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // License & Permission Card
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INTELLECTUAL PROPERTY & PERMISSION',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Copyright (c) 2026 Nomad Guy. All rights reserved.\nPermission is granted to use the app for personal listening, but strictly prohibited to modify, unpack, tamper, or reverse engineer it.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
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
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devSpecClickableRow(String label, String value, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54),
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
