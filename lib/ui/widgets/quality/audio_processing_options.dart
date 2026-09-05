import 'package:flutter/material.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../services/audio/stream_quality_service.dart';
import '../../../shared/widgets/glass_card.dart';

class AudioProcessingTogglesCard extends StatelessWidget {
  final bool normalizeVolume;
  final bool gaplessPlayback;
  final NoctraThemeTokens tokens;
  final ValueChanged<bool> onNormalizeVolumeChanged;
  final ValueChanged<bool> onGaplessPlaybackChanged;

  const AudioProcessingTogglesCard({
    super.key,
    required this.normalizeVolume,
    required this.gaplessPlayback,
    required this.tokens,
    required this.onNormalizeVolumeChanged,
    required this.onGaplessPlaybackChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          _buildToggle(
            'Volume Normalization',
            'Balance volume levels across tracks',
            normalizeVolume,
            tokens,
            onNormalizeVolumeChanged,
          ),
          const Divider(height: 8),
          _buildToggle(
            'Gapless Playback',
            'Seamless transitions between tracks',
            gaplessPlayback,
            tokens,
            onGaplessPlaybackChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    bool value,
    NoctraThemeTokens tokens,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.primaryText,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: tokens.accent,
          ),
        ],
      ),
    );
  }
}

class EstimatedFileSizeCard extends StatelessWidget {
  final NoctraThemeTokens tokens;

  const EstimatedFileSizeCard({super.key, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: StreamQuality.values.map((q) {
          final sizeMB = StreamQualityService.estimateFileSizeMB(240, q);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  q.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.primaryText,
                  ),
                ),
                Text(
                  q == StreamQuality.hiRes
                      ? '~${sizeMB.toStringAsFixed(0)} MB'
                      : '~${sizeMB.toStringAsFixed(1)} MB',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.secondaryText,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
