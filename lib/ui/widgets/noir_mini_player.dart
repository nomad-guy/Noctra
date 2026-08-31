import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../screens/player_sheet.dart';
import 'equalizer_sheet.dart';
import 'glass_card.dart';
import 'live_audio_wave.dart';

class NoirMiniPlayer extends ConsumerStatefulWidget {
  const NoirMiniPlayer({super.key});

  @override
  ConsumerState<NoirMiniPlayer> createState() => _NoirMiniPlayerState();
}

class _NoirMiniPlayerState extends ConsumerState<NoirMiniPlayer> {
  String? _dismissedSongId;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final currentSongAsync = ref.watch(currentSongStreamProvider);
    final isPlayingAsync = ref.watch(isPlayingStreamProvider);
    final positionAsync = ref.watch(positionStreamProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;

    final song = currentSongAsync.value;
    final isPlaying = isPlayingAsync.value ?? false;

    if (isPlaying && _dismissedSongId != null) {
      _dismissedSongId = null;
    }

    if (song == null || (!isPlaying && _dismissedSongId == song.id)) return const SizedBox.shrink();

    final position = positionAsync.value ?? Duration.zero;
    final duration = song.duration.inMilliseconds > 0 ? song.duration : const Duration(minutes: 3, seconds: 30);
    final remaining = duration - position;

    return Dismissible(
      key: ValueKey('mini_player_${song.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        setState(() => _dismissedSongId = song.id);
        ref.read(audioPlayerServiceProvider).stopAndDismiss();
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Row(
          children: [
            Icon(Icons.stop_circle_outlined, size: 24, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 8),
            Text(
              'Swipe to Close',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Swipe to Close',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 8),
            Icon(Icons.stop_circle_outlined, size: 24, color: isDark ? Colors.white70 : Colors.black87),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: GlassCard(
          radius: 20,
          padding: EdgeInsets.zero,
          isHighlighted: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const PlayerSheet(),
                  );
                },
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < -200) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const PlayerSheet(),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                  child: Row(
                    children: [
                      // Album Art Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 46,
                          height: 46,
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
                          child: song.artworkUrl != null
                              ? Image.network(
                                  song.artworkUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 150,
                                  cacheHeight: 150,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.music_note_outlined,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                )
                              : Icon(
                                  Icons.music_note_outlined,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Equalizer Quick Button with Live Dynamic Audio Wave
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        tooltip: 'Equalizer FX',
                        icon: LiveAudioWave(
                          isPlaying: isPlaying,
                          color: isDark ? Colors.white : Colors.black,
                          height: 16,
                          barCount: 4,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const EqualizerSheet(),
                          );
                        },
                      ),
                      // Previous Button
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: Icon(
                          Icons.skip_previous_rounded,
                          size: 22,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () => ref.read(audioPlayerServiceProvider).skipPrevious(),
                      ),
                      // Play/Pause Main Button
                      GestureDetector(
                        onTap: () => ref.read(audioPlayerServiceProvider).togglePlayPause(),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 22,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      // Next Button
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: Icon(
                          Icons.skip_next_rounded,
                          size: 22,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () => ref.read(audioPlayerServiceProvider).skipNext(),
                      ),
                    ],
                  ),
                ),
              ),
              // Dynamic Time-Coded Micro Progress Bar & Timers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                        activeTrackColor: isDark ? Colors.white : Colors.black,
                        inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
                        thumbColor: isDark ? Colors.white : Colors.black,
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                        max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                        onChanged: (v) => ref.read(audioPlayerServiceProvider).seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                          Text('-${_formatDuration(remaining)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
