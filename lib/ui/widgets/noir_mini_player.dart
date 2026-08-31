import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _seekMode = false;
  double _seekStartX = 0.0;
  Duration _seekStartPosition = Duration.zero;
  Duration _liveSeekPosition = Duration.zero;
  DateTime _lastSeekTime = DateTime(0);
  static const double _seekSensitivity = 0.5; // seconds per logical pixel
  static const int _seekThrottleMs = 50; // min ms between seek() calls

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlayerSheet(),
    );
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
    final displayPosition = _seekMode ? _liveSeekPosition : position;
    final remaining = duration - displayPosition;

    final accentColor = isDark ? Colors.cyanAccent : Colors.deepPurpleAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _seekMode ? null : () => _openPlayer(context),
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -200) {
            _openPlayer(context);
          } else if (v > 200) {
            ref.read(audioPlayerServiceProvider).stopAndDismiss();
          }
        },
        // Long press activates seek mode
        onLongPressStart: (details) {
          final pos = ref.read(positionStreamProvider).value ?? Duration.zero;
          setState(() {
            _seekMode = true;
            _seekStartX = details.globalPosition.dx;
            _seekStartPosition = pos;
            _liveSeekPosition = pos;
          });
          HapticFeedback.mediumImpact();
        },
        onLongPressEnd: (_) => setState(() => _seekMode = false),
        onLongPressMoveUpdate: (details) {
          if (!_seekMode) return;
          final dx = details.globalPosition.dx - _seekStartX;
          final delta = Duration(milliseconds: (dx * _seekSensitivity * 1000).toInt());
          final raw = _seekStartPosition + delta;
          final clamped = raw < Duration.zero ? Duration.zero : (raw > duration ? duration : raw);
          setState(() => _liveSeekPosition = clamped);
          // M-R5-02: Throttle seek() calls to avoid audio jitter from queued moves
          final now = DateTime.now();
          if (now.difference(_lastSeekTime).inMilliseconds >= _seekThrottleMs) {
            _lastSeekTime = now;
            ref.read(audioPlayerServiceProvider).seek(clamped);
          }
        },
        // Normal horizontal drag (NOT in seek mode) = skip
        onHorizontalDragEnd: (details) {
          if (_seekMode) return;
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -300) {
            ref.read(audioPlayerServiceProvider).skipNext();
          } else if (velocity > 300) {
            ref.read(audioPlayerServiceProvider).skipPrevious();
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
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 46, height: 46,
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
                      child: song.artworkUrl != null
                          ? Image.network(song.artworkUrl!, fit: BoxFit.cover, cacheWidth: 150, cacheHeight: 150,
                              errorBuilder: (c, e, st) => Icon(Icons.music_note_outlined, color: isDark ? Colors.white54 : Colors.black54))
                          : Icon(Icons.music_note_outlined, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (_seekMode) ...[
                          Icon(Icons.swap_horiz_rounded, size: 10, color: accentColor),
                          const SizedBox(width: 3),
                          Text(_formatDuration(displayPosition),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor)),
                        ] else ...[
                          LiveAudioWave(isPlaying: isPlaying, color: isDark ? Colors.white70 : Colors.black87, height: 8, barCount: 3),
                          const SizedBox(width: 4),
                          Expanded(child: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: isDark ? NoirColors.blackTextSecondary : NoirColors.whiteTextSecondary))),
                        ],
                      ]),
                    ]),
                  ),
                  IconButton(
                    icon: Icon(Icons.equalizer_rounded, size: 20, color: isDark ? Colors.white60 : Colors.black54),
                    tooltip: 'Equalizer',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => const EqualizerSheet());
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      ref.watch(musicRepositoryProvider).isFavorite(song.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 20,
                      color: ref.watch(musicRepositoryProvider).isFavorite(song.id) ? Colors.redAccent : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(musicRepositoryProvider).toggleFavorite(song);
                    },
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      size: 32, color: isDark ? Colors.white : Colors.black),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(audioPlayerServiceProvider).togglePlayPause();
                    },
                  ),
                ]),
              ),
              // Progress bar — turns accent when seeking
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Column(children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: _seekMode ? 3.0 : 2.0,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: _seekMode ? 6.0 : 4.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                      activeTrackColor: _seekMode ? accentColor : (isDark ? Colors.white : Colors.black),
                      inactiveTrackColor: _seekMode ? accentColor.withValues(alpha: 0.25) : (isDark ? Colors.white24 : Colors.black12),
                      thumbColor: _seekMode ? accentColor : (isDark ? Colors.white : Colors.black),
                    ),
                    child: Slider(
                      value: displayPosition.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                      max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      onChanged: (v) {
                        final newPos = Duration(milliseconds: v.toInt());
                        setState(() => _liveSeekPosition = newPos);
                        ref.read(audioPlayerServiceProvider).seek(newPos);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_formatDuration(displayPosition),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _seekMode ? accentColor : (isDark ? Colors.white54 : Colors.black54))),
                      if (_seekMode) Text('SEEKING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: accentColor))
                      else Text('-${_formatDuration(remaining)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
