import 'dart:math';
import 'package:flutter/material.dart';

class LiveAudioWave extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;
  final int barCount;

  const LiveAudioWave({
    super.key,
    required this.isPlaying,
    required this.color,
    this.height = 16,
    this.barCount = 4,
  });

  @override
  State<LiveAudioWave> createState() => _LiveAudioWaveState();
}

class _LiveAudioWaveState extends State<LiveAudioWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LiveAudioWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) _controller.repeat(reverse: true);
      } else {
        if (_controller.isAnimating) {
          _controller.animateTo(0.0, duration: const Duration(milliseconds: 150)).then((_) {
            if (mounted && !widget.isPlaying) _controller.stop();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return SizedBox(
        height: widget.height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.barCount, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 2.2,
              height: widget.height * 0.35,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            height: widget.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.barCount, (i) {
                final wave = sin((_controller.value * 2 * pi) + (i * 1.3)).abs();
                final minH = widget.height * 0.25;
                final barH = minH + (widget.height - minH) * wave;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 2.2,
                  height: barH.clamp(2.0, widget.height),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
