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
    if (song == null) return const SizedBox.shrink();

    final isPlaying = isPlayingAsync.value ?? false;
    final position = positionAsync.value ?? Duration.zero;
    final duration = song.duration.inMilliseconds > 0 ? song.duration : const Duration(minutes: 3, seconds: 30);
    final remaining = duration - position;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
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
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200) {
            ref.read(audioPlayerServiceProvider).skipNext();
          } else if (velocity > 200) {
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
        child: GlassCard(
          radius: 20,
          padding: EdgeInsets.zero,
          isHighlighted: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              LiveAudioWave(
                                isPlaying: isPlaying,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 8,
                                barCount: 3,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Equalizer Sheet Button
                    IconButton(
                      icon: Icon(
                        Icons.equalizer_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      tooltip: 'Equalizer',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const EqualizerSheet(),
                        );
                      },
                    ),
                    // Favorite Toggle
                    IconButton(
                      icon: Icon(
                        ref.watch(musicRepositoryProvider).isFavorite(song.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 20,
                        color: ref.watch(musicRepositoryProvider).isFavorite(song.id) ? Colors.redAccent : (isDark ? Colors.white60 : Colors.black54),
                      ),
                      onPressed: () => ref.read(musicRepositoryProvider).toggleFavorite(song),
                    ),
                    // Play / Pause Button
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                        size: 32,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: () => ref.read(audioPlayerServiceProvider).togglePlayPause(),
                    ),
                  ],
                ),
              ),

              // Embedded Micro Progress Slider
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
