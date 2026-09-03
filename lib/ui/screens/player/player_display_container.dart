import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../data/models/song_model.dart';
import '../../widgets/ambient_glow_art.dart';
import '../../widgets/lyrics_view.dart';
import '../../widgets/player_visualizer_selector.dart';
import '../../widgets/proper_synthwave_visualizer.dart';
import '../../widgets/radial_circle_visualizer.dart';
import '../../widgets/spectrum_bars_visualizer.dart';

enum PlayerDisplayMode {
  artwork,
  spectrumBars,
  radialCircle,
  synthwaveGrid,
  lyrics
}

final playerDisplayModeProvider =
    StateProvider<PlayerDisplayMode>((ref) => PlayerDisplayMode.artwork);

class PlayerDisplayContainer extends ConsumerWidget {
  final Song song;
  final bool isPlaying;
  final bool isDark;
  final double heroHeight;

  const PlayerDisplayContainer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.isDark,
    required this.heroHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.noctraTokens;
    final displayMode = ref.watch(playerDisplayModeProvider);

    return Column(
      children: [
        PlayerVisualizerSelector(
          isDark: isDark,
          currentMode: displayMode,
        ),
        const SizedBox(height: 14),
        Container(
          height: heroHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: tokens.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tokens.subtleBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _buildVisualizerContent(
                displayMode, song, isPlaying, isDark, heroHeight),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualizerContent(PlayerDisplayMode mode, Song song,
      bool isPlaying, bool isDark, double height) {
    switch (mode) {
      case PlayerDisplayMode.lyrics:
        return LyricsView(song: song);
      case PlayerDisplayMode.spectrumBars:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SpectrumBarsVisualizer(
            isPlaying: isPlaying,
            color: isDark ? Colors.white : Colors.black,
            height: height - 24,
          ),
        );
      case PlayerDisplayMode.radialCircle:
        return Center(
          child: RadialCircleVisualizer(
            isPlaying: isPlaying,
            color: isDark ? Colors.white : Colors.black,
            imageUrl: song.artworkUrl,
            size: height * 0.7,
          ),
        );
      case PlayerDisplayMode.synthwaveGrid:
        return ProperSynthwaveVisualizer(
          isPlaying: isPlaying,
          isDark: isDark,
          height: height,
        );
      case PlayerDisplayMode.artwork:
        return Center(
          child: AmbientGlowArt(
            imageUrl: song.artworkUrl,
            isPlaying: isPlaying,
            isDark: isDark,
            size: height * 0.75,
            radius: 20,
          ),
        );
    }
  }
}
