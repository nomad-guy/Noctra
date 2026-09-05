import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../widgets/player_controls_section.dart';
import 'player/player_bottom_actions.dart';
import 'player/player_display_container.dart';
import 'player/player_header.dart';
import 'player/player_studio_chips.dart';
import 'player/player_track_info_bar.dart';

export 'player/player_display_container.dart'
    show PlayerDisplayMode, playerDisplayModeProvider;
export 'player/player_studio_chips.dart'
    show StudioMasterMode, studioMasterModeProvider;

class PlayerSheet extends ConsumerWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;
    final audioPlayerService = ref.watch(audioPlayerServiceProvider);
    final repo = ref.watch(musicRepositoryProvider);
    final song = ref.watch(currentSongStreamProvider).value;
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final duration = audioPlayerService.player.duration ?? Duration.zero;
    final masterMode = ref.watch(studioMasterModeProvider);
    final displayMode = ref.watch(playerDisplayModeProvider);

    if (song == null) return const SizedBox.shrink();
    final isDownloaded = repo.downloads.any((d) => d.id == song.id);
    final screenH = MediaQuery.of(context).size.height;
    final heroH = displayMode == PlayerDisplayMode.lyrics
        ? (screenH * 0.38).clamp(260.0, 340.0)
        : (screenH * 0.30).clamp(200.0, 280.0);

    double dragStartY = 0;
    return GestureDetector(
      onVerticalDragStart: (d) => dragStartY = d.localPosition.dy,
      onVerticalDragEnd: (d) {
        final velocity = d.primaryVelocity ?? 0;
        if (velocity > 400 && dragStartY < 80) Navigator.of(context).pop();
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenH * 0.96),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: themeMode.isLiquidGlass
                ? null
                : tokens.surface.withValues(alpha: 0.96),
            gradient: themeMode.isLiquidGlass
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.surfaceVariant.withValues(alpha: 0.94),
                      tokens.canvas.withValues(alpha: 0.88),
                      tokens.secondaryAccent.withValues(alpha: 0.18),
                    ],
                  )
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: tokens.subtleBorder),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: tokens.secondaryText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                PlayerHeader(isDark: isDark),
                const SizedBox(height: 14),
                PlayerDisplayContainer(
                  song: song,
                  isPlaying: isPlaying,
                  isDark: isDark,
                  heroHeight: heroH,
                ),
                const SizedBox(height: 20),
                PlayerTrackInfoBar(
                  song: song,
                  isDownloaded: isDownloaded,
                ),
                const SizedBox(height: 16),
                const PlayerStudioChips(),
                const SizedBox(height: 20),
                PlayerControlsSection(
                  isDark: isDark,
                  isPlaying: isPlaying,
                  duration: duration,
                  volume: ref.watch(volumeStreamProvider).value ?? 1.0,
                  isShuffle: audioPlayerService.player.shuffleModeEnabled,
                  loopMode: audioPlayerService.player.loopMode,
                  audioPlayerService: audioPlayerService,
                  masterMode: masterMode,
                ),
                const SizedBox(height: 20),
                PlayerBottomActions(song: song),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
