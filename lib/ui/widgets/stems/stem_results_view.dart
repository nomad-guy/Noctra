import 'package:flutter/material.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../services/audio/audio_stem_separation_service.dart';
import '../../../shared/widgets/glass_card.dart';

class StemResultsView extends StatelessWidget {
  final StemSeparationResult result;
  final String? playingStem;
  final ValueChanged<AudioStem> onPlayStem;
  final VoidCallback onReseparate;

  const StemResultsView({
    super.key,
    required this.result,
    required this.playingStem,
    required this.onPlayStem,
    required this.onReseparate,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;
    final stems = result.stems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 16, color: Colors.greenAccent.shade400),
              const SizedBox(width: 8),
              Text(
                'Separated in ${(result.processingTimeMs / 1000).toStringAsFixed(1)}s '
                'using ${result.modelUsed} model',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stems.length,
            itemBuilder: (context, index) {
              final stem = stems[index];
              final isPlaying = playingStem == stem.name;

              final stemIcons = {
                'vocals': Icons.record_voice_over_rounded,
                'drums': Icons.album_rounded,
                'bass': Icons.surround_sound_rounded,
                'other': Icons.music_note_rounded,
              };

              final stemColors = {
                'vocals': Colors.cyanAccent,
                'drums': Colors.orangeAccent,
                'bass': Colors.purpleAccent,
                'other': Colors.greenAccent,
              };

              return GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: stemColors[stem.name]?.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        stemIcons[stem.name],
                        size: 20,
                        color: stemColors[stem.name],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stem.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tokens.primaryText,
                            ),
                          ),
                          Text(
                            '${(stem.audioFile?.lengthSync() ?? 0) ~/ 1024} KB • ${stem.name}',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill_rounded,
                        size: 32,
                        color: isPlaying
                            ? stemColors[stem.name]
                            : tokens.primaryText,
                      ),
                      onPressed: () => onPlayStem(stem),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onReseparate,
              child: Text(
                'Re-separate with different model',
                style: TextStyle(
                  color: tokens.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
