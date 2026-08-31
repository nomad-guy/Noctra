import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio/audio_player_service.dart';
import '../screens/player_sheet.dart';

class PlayerControlsSection extends ConsumerStatefulWidget {
  final bool isDark;
  final AudioPlayerService audioPlayerService;
  final Duration position;
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
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isShuffle,
    required this.loopMode,
    required this.volume,
    required this.masterMode,
  });

  @override
  ConsumerState<PlayerControlsSection> createState() => _PlayerControlsSectionState();
}

class _PlayerControlsSectionState extends ConsumerState<PlayerControlsSection> {
  double? _dragValue;

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentPos = _dragValue != null ? Duration(milliseconds: _dragValue!.toInt()) : widget.position;
    final remaining = widget.duration - currentPos;
    final isDark = widget.isDark;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: isDark ? Colors.white : Colors.black,
            inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
            thumbColor: isDark ? Colors.white : Colors.black,
          ),
          child: Slider(
            value: (_dragValue ?? widget.position.inMilliseconds.toDouble()).clamp(0.0, widget.duration.inMilliseconds.toDouble()),
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
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
              ),
              Text(
                '-${_formatDuration(remaining.isNegative ? Duration.zero : remaining)}',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Playback Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Semantics(
              label: widget.isShuffle ? 'Shuffle enabled' : 'Shuffle disabled',
              button: true,
              child: IconButton(
                tooltip: widget.isShuffle ? 'Shuffle: ON' : 'Shuffle: OFF',
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 22,
                  color: widget.isShuffle ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white30 : Colors.black26),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.audioPlayerService.toggleShuffle();
                },
              ),
            ),
            Semantics(
              label: 'Previous track',
              button: true,
              child: IconButton(
                tooltip: 'Previous Track',
                icon: Icon(Icons.skip_previous_rounded, size: 34, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.audioPlayerService.skipPrevious();
                },
              ),
            ),
            Semantics(
              label: widget.isPlaying ? 'Pause' : 'Play',
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.audioPlayerService.togglePlayPause();
                },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white : Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 32,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
            Semantics(
              label: 'Next track',
              button: true,
              child: IconButton(
                tooltip: 'Next Track',
                icon: Icon(Icons.skip_next_rounded, size: 34, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.audioPlayerService.skipNext();
                },
              ),
            ),
            Semantics(
              label: widget.loopMode == LoopMode.all ? 'Loop all' : (widget.loopMode == LoopMode.one ? 'Loop single' : 'Loop off'),
              button: true,
              child: IconButton(
                tooltip: widget.loopMode == LoopMode.all ? 'Loop: ALL' : (widget.loopMode == LoopMode.one ? 'Loop: ONE' : 'Loop: OFF'),
                icon: Icon(
                  widget.loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  size: 22,
                  color: widget.loopMode != LoopMode.off ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white30 : Colors.black26),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.audioPlayerService.toggleLoopMode();
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
              widget.volume == 0 ? Icons.volume_off_rounded : (widget.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
              size: 20,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: isDark ? Colors.white70 : Colors.black87,
                  inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                  thumbColor: isDark ? Colors.white : Colors.black,
                ),
                child: Slider(
                  value: (widget.volume.isNaN || widget.volume.isInfinite) ? 1.0 : widget.volume.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => widget.audioPlayerService.setVolume(val),
                ),
              ),
            ),
            Text(
              '${(((widget.volume.isNaN || widget.volume.isInfinite) ? 1.0 : widget.volume.clamp(0.0, 1.0)) * 100).toInt()}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}
