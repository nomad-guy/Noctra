import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../screens/player_sheet.dart';
import 'equalizer_sheet.dart';
import 'glass_card.dart';
import 'live_audio_wave.dart';

class NoirMiniPlayer extends ConsumerWidget {
  const NoirMiniPlayer({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSongAsync = ref.watch(currentSongStreamProvider);
    final isPlayingAsync = ref.watch(isPlayingStreamProvider);
    final positionAsync = ref.watch(positionStreamProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == NoirThemeMode.noirBlack;

    final song = currentSongAsync.value;
    if (song == null) return const SizedBox.shrink();

    final isPlaying = isPlayingAsync.value ?? false;
    final position = positionAsync.value ?? Duration.zero;
    final duration = song.duration.inMilliseconds > 0 ? song.duration : const Duration(minutes: 3, seconds: 30);
    final remaining = duration - position;

    return Dismissible(
      key: ValueKey('mini_player_${song.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        ref.read(audioPlayerServiceProvider).stopAndDismiss();
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isDark ? const Color(0x33FF453A) : const Color(0x22FF3B30),
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
          color: isDark ? const Color(0x33FF453A) : const Color(0x22FF3B30),
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
                onHorizontalDragEnd: (details) {
                  final vx = details.primaryVelocity ?? 0;
                  if (vx < -200) {
                    ref.read(audioPlayerServiceProvider).skipNext();
                  } else if (vx > 200) {
                    ref.read(audioPlayerServiceProvider).skipPrevious();
                  }
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${_formatDuration(position)} / ${_formatDuration(duration)}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Equalizer Quick Button with Live Dynamic Audio Wave
                      IconButton(
                        tooltip: 'Equalizer FX',
                        icon: LiveAudioWave(
                          isPlaying: isPlaying,
                          color: isDark ? Colors.white : Colors.black,
                          height: 18,
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
                        icon: Icon(
                          Icons.skip_previous_rounded,
                          size: 24,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () {
                          ref.read(audioPlayerServiceProvider).skipPrevious();
                        },
                      ),
                      // Play/Pause Main Button
                      GestureDetector(
                        onTap: () {
                          ref.read(audioPlayerServiceProvider).togglePlayPause();
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 24,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      // Next Button
                      IconButton(
                        icon: Icon(
                          Icons.skip_next_rounded,
                          size: 24,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () {
                          ref.read(audioPlayerServiceProvider).skipNext();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Time & Seek Bar (Isolated from Sheet Opening Gesture)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTrackColor: isDark ? Colors.white : Colors.black,
                          inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                          thumbColor: isDark ? Colors.white : Colors.black,
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (val) {
                            ref.read(audioPlayerServiceProvider).seek(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),
                    ),
                    Text(
                      '-${_formatDuration(remaining.isNegative ? Duration.zero : remaining)}',
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
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
