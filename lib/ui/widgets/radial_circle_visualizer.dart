import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/audio/audio_visualizer_service.dart';

class RadialCircleVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final String? imageUrl;
  final double size;

  const RadialCircleVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
    this.imageUrl,
    this.size = 140,
  });

  @override
  State<RadialCircleVisualizer> createState() => _RadialCircleVisualizerState();
}

class _RadialCircleVisualizerState extends State<RadialCircleVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription? _fftSub;
  final List<double> _spikes = List.filled(48, 0.05);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(_applyDecay);
    if (widget.isPlaying) _controller.repeat();

    _fftSub = AudioVisualizerService().fftStream.listen((fftData) {
      if (!mounted || !widget.isPlaying) return;
      setState(() {
        for (int i = 0; i < 48; i++) {
          final fftIdx = (i * fftData.length) ~/ 48;
          final raw = fftData[fftIdx % fftData.length];
          final target = (raw * 1.5).clamp(0.04, 0.95);
          if (target > _spikes[i]) {
            _spikes[i] += (target - _spikes[i]) * 0.70;
          }
        }
      });
    });
  }

  void _applyDecay() {
    for (int i = 0; i < 48; i++) {
      _spikes[i] = max(0.04, _spikes[i] * 0.88);
    }
  }

  @override
  void didUpdateWidget(covariant RadialCircleVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _fftSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size + 48, widget.size + 48),
            painter: _RadialCirclePainter(
              spikes: _spikes,
              progress: _controller.value,
              isPlaying: widget.isPlaying,
              color: widget.color,
            ),
            child: SizedBox(
              width: widget.size + 48,
              height: widget.size + 48,
              child: Center(
                child: ClipOval(
                  child: Image.network(
                    widget.imageUrl ?? '',
                    width: widget.size - 20,
                    height: widget.size - 20,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: widget.size - 20,
                      height: widget.size - 20,
                      color: widget.color.withValues(alpha: 0.15),
                      child: Icon(Icons.music_note_rounded, color: widget.color),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadialCirclePainter extends CustomPainter {
  final List<double> spikes;
  final double progress;
  final bool isPlaying;
  final Color color;

  _RadialCirclePainter({
    required this.spikes,
    required this.progress,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) - 20;
    const numSpikes = 48;

    for (int i = 0; i < numSpikes; i++) {
      final angle = (i / numSpikes) * 2 * pi + (progress * 2 * pi);
      final amp = isPlaying ? (spikes[i] * 22.0 + 3.0) : 2.5;

      final startX = center.dx + (baseRadius * cos(angle));
      final startY = center.dy + (baseRadius * sin(angle));
      final endX = center.dx + ((baseRadius + amp) * cos(angle));
      final endY = center.dy + ((baseRadius + amp) * sin(angle));

      final paint = Paint()
        ..color = color.withValues(alpha: isPlaying ? (0.45 + (spikes[i] * 0.50)) : 0.25)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialCirclePainter oldDelegate) {
    return oldDelegate.spikes != spikes ||
        oldDelegate.color != color ||
        oldDelegate.isPlaying != isPlaying;
  }
}
