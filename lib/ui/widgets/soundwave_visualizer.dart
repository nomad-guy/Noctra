import 'dart:math';
import 'package:flutter/material.dart';

class SoundwaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final int barCount;

  const SoundwaveVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
    this.barCount = 28,
  });

  @override
  State<SoundwaveVisualizer> createState() => _SoundwaveVisualizerState();
}

class _SoundwaveVisualizerState extends State<SoundwaveVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.barCount,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 2.5,
              height: 4.0,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.barCount,
              (i) {
                final wave = sin((_controller.value * 2 * pi) + (i * 0.45)).abs();
                final height = (wave * 26 + 4).clamp(4.0, 32.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 2.5,
                  height: height,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
