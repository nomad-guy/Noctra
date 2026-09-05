import 'package:flutter/material.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../services/audio/stream_quality_service.dart';
import '../../../shared/widgets/glass_card.dart';

class StreamQualityOptionsCard extends StatelessWidget {
  final StreamQuality selectedQuality;
  final NoctraThemeTokens tokens;
  final ValueChanged<StreamQuality> onSelect;

  const StreamQualityOptionsCard({
    super.key,
    required this.selectedQuality,
    required this.tokens,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: StreamQuality.values.map((q) {
          final isSelected = selectedQuality == q;
          return InkWell(
            onTap: () => onSelect(q),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: isSelected ? tokens.accent : tokens.secondaryText,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: tokens.primaryText,
                          ),
                        ),
                        if (q != StreamQuality.hiRes)
                          Text(
                            '${q.bitrate} kbps • ${q.codec.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.secondaryText,
                            ),
                          )
                        else
                          Text(
                            'Lossless • ${q.codec.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AudioCodecOptionsCard extends StatelessWidget {
  final AudioCodec selectedCodec;
  final NoctraThemeTokens tokens;
  final ValueChanged<AudioCodec> onSelect;

  const AudioCodecOptionsCard({
    super.key,
    required this.selectedCodec,
    required this.tokens,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: AudioCodec.values.map((c) {
          final isSelected = selectedCodec == c;
          return InkWell(
            onTap: () => onSelect(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: isSelected ? tokens.accent : tokens.secondaryText,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: tokens.primaryText,
                          ),
                        ),
                        Text(
                          c.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
