import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../providers/app_providers.dart';
import '../../services/audio/audio_player_service.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../screens/player/player_studio_chips.dart';

class PlayerControlsSection extends ConsumerWidget {
  final bool isDark;
  final AudioPlayerService audioPlayerService;
  final Duration duration;
  final bool isPlaying;
  final bool isShuffle;
  final LoopMode loopMode;
  final double volume;
  final StudioMasterMode masterMode;

  const PlayerControlsSection({
    super.key,
    required this.isDark,
    required this.audioPlayerService,
    required this.duration,
    required this.isPlaying,
    required this.isShuffle,
    required this.loopMode,
    required this.volume,
    required this.masterMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.noctraTokens;

    return Column(
      children: [
        // Only the seek progress subscribes to the position stream; the rest
        // of this section (buttons, volume) stays stable between position
        // ticks and is only rebuilt on song/state changes.
        _SeekProgress(duration: duration, audioPlayerService: audioPlayerService),
        const SizedBox(height: 12),

        // Playback Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Semantics(
              label: isShuffle ? context.tr(L10nKeys.shuffleOn) : context.tr(L10nKeys.shuffleOff),
              button: true,
              child: IconButton(
                tooltip: isShuffle ? context.tr(L10nKeys.shuffleOn) : context.tr(L10nKeys.shuffleOff),
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 22,
                  color: isShuffle ? tokens.accent : tokens.tertiaryText,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  audioPlayerService.toggleShuffle();
                },
              ),
            ),
            Semantics(
              label: context.tr(L10nKeys.previousTrack),
              button: true,
              child: IconButton(
                tooltip: context.tr(L10nKeys.previousTrack),
                icon: Icon(Icons.skip_previous_rounded, size: 34, color: tokens.primaryText),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  audioPlayerService.skipPrevious();
                },
              ),
            ),
            Semantics(
              label: isPlaying ? context.tr(L10nKeys.paused) : context.tr(L10nKeys.playing),
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  audioPlayerService.togglePlayPause();
                },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.accent,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 32,
                    color: tokens.canvas,
                  ),
                ),
              ),
            ),
            Semantics(
              label: context.tr(L10nKeys.nextTrack),
              button: true,
              child: IconButton(
                tooltip: context.tr(L10nKeys.nextTrack),
                icon: Icon(Icons.skip_next_rounded, size: 34, color: tokens.primaryText),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  audioPlayerService.skipNext();
                },
              ),
            ),
            Semantics(
              label: loopMode == LoopMode.all ? context.tr(L10nKeys.loopAll) : (loopMode == LoopMode.one ? context.tr(L10nKeys.loopOne) : context.tr(L10nKeys.loopOff)),
              button: true,
              child: IconButton(
                tooltip: loopMode == LoopMode.all ? context.tr(L10nKeys.loopAll) : (loopMode == LoopMode.one ? context.tr(L10nKeys.loopOne) : context.tr(L10nKeys.loopOff)),
                icon: Icon(
                  loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  size: 22,
                  color: loopMode != LoopMode.off ? tokens.secondaryAccent : tokens.tertiaryText,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  audioPlayerService.toggleLoopMode();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Volume Scroller Row
        Row(
          children: [
            Icon(
              volume == 0 ? Icons.volume_off_rounded : (volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
              size: 20,
              color: tokens.secondaryText,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: tokens.secondaryAccent,
                  inactiveTrackColor: tokens.subtleBorder,
                  thumbColor: tokens.accent,
                ),
                child: Slider(
                  value: (volume.isNaN || volume.isInfinite) ? 1.0 : volume.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => audioPlayerService.setVolume(val),
                ),
              ),
            ),
            Text(
              '${(((volume.isNaN || volume.isInfinite) ? 1.0 : volume.clamp(0.0, 1.0)) * 100).toInt()}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.secondaryText),
            ),
          ],
        ),
      ],
    );
  }
}

/// Seek slider + timestamps. Watches [positionStreamProvider] locally so
/// per-tick position updates only rebuild this small subtree — never the
/// artwork/lyrics/visualizer/control buttons around it.
class _SeekProgress extends ConsumerStatefulWidget {
  final AudioPlayerService audioPlayerService;
  final Duration duration;

  const _SeekProgress({
    required this.audioPlayerService,
    required this.duration,
  });

  @override
  ConsumerState<_SeekProgress> createState() => _SeekProgressState();
}

class _SeekProgressState extends ConsumerState<_SeekProgress> {
  double? _dragValue;

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final currentPos = _dragValue != null ? Duration(milliseconds: _dragValue!.toInt()) : position;
    final remaining = widget.duration - currentPos;
    final tokens = context.noctraTokens;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: tokens.accent,
            inactiveTrackColor: tokens.subtleBorder,
            thumbColor: tokens.accent,
          ),
          child: Slider(
            value: (_dragValue ?? position.inMilliseconds.toDouble()).clamp(0.0, widget.duration.inMilliseconds.toDouble()),
            max: widget.duration.inMilliseconds.toDouble() > 0 ? widget.duration.inMilliseconds.toDouble() : 1.0,
            onChanged: (val) => setState(() => _dragValue = val),
            onChangeEnd: (val) {
              HapticFeedback.selectionClick();
              widget.audioPlayerService.seek(Duration(milliseconds: val.toInt()));
              setState(() => _dragValue = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(currentPos),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.secondaryText),
              ),
              Text(
                '-${_formatDuration(remaining.isNegative ? Duration.zero : remaining)}',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: tokens.tertiaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
