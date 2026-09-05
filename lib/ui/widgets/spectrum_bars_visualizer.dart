import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/audio/audio_visualizer_service.dart';

class SpectrumBarsVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;
  final int barCount;

  const SpectrumBarsVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
    this.height = 136,
    this.barCount = 32,
  });

  @override
  State<SpectrumBarsVisualizer> createState() => _SpectrumBarsVisualizerState();
}

class _SpectrumBarsVisualizerState extends State<SpectrumBarsVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription? _fftSub;
  final List<double> _currentHeights = List.filled(32, 0.20);
  final List<double> _peakHeights = List.filled(32, 0.25);
  List<double> _latestFft = List.filled(32, 0.3);

  late bool _isPlaying;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isPlaying;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(_tickVisualizer);
    _controller.repeat();

    _fftSub = AudioVisualizerService().fftStream.listen((fftData) {
      if (fftData.isNotEmpty) {
        _latestFft = fftData;
      }
    });
    AudioVisualizerService().subscribe();
    if (!widget.isPlaying) _controller.stop();
  }

  @override
  void didUpdateWidget(SpectrumBarsVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isPlaying = widget.isPlaying;
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isPlaying && _controller.isAnimating) {
            _controller.stop();
          }
        });
      }
    }
  }

  void _tickVisualizer() {
    final double t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (int i = 0; i < widget.barCount; i++) {
      if (!_isPlaying) {
        _currentHeights[i] = max(0.06, _currentHeights[i] * 0.90);
        _peakHeights[i] = max(0.06, _peakHeights[i] * 0.90);
        continue;
      }

      final double fftVal = i < _latestFft.length ? _latestFft[i] : 0.3;
      final double wave1 = sin(t * 7.5 + (i * 0.42)) * 0.35 + 0.5;
      final double wave2 = cos(t * 3.8 + (i * 0.25)) * 0.25 + 0.5;
      final double subBass = (sin(t * 9.0) * 0.3 + 0.7);

      double target = (fftVal * 0.65 + wave1 * 0.35 + wave2 * 0.25) * subBass;
      target = target.clamp(0.12, 0.96);

      _currentHeights[i] += (target - _currentHeights[i]) * 0.42;

      if (_currentHeights[i] > _peakHeights[i]) {
        _peakHeights[i] = _currentHeights[i];
      } else {
        _peakHeights[i] = max(_currentHeights[i], _peakHeights[i] - 0.014);
      }
    }
  }

  @override
  void dispose() {
    AudioVisualizerService().unsubscribe();
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
          return SizedBox(
            width: double.infinity,
            height: widget.height,
            child: CustomPaint(
              size: Size(double.infinity, widget.height),
              painter: _SpectrumBarsPainter(
                currentHeights: _currentHeights,
                peakHeights: _peakHeights,
                isPlaying: widget.isPlaying,
                color: widget.color,
                barCount: widget.barCount,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpectrumBarsPainter extends CustomPainter {
  final List<double> currentHeights;
  final List<double> peakHeights;
  final bool isPlaying;
  final Color color;
  final int barCount;

  _SpectrumBarsPainter({
    required this.currentHeights,
    required this.peakHeights,
    required this.isPlaying,
    required this.color,
    required this.barCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double totalW = size.width;
    final double maxH = size.height;
    if (totalW <= 0 || maxH <= 0) return;

    const double spacing = 3.5;
    final double barW = (totalW - (spacing * (barCount - 1))) / barCount;
    final double baselineY = maxH * 0.95;

    for (int i = 0; i < barCount; i++) {
      final double x = i * (barW + spacing);
      final double barH = (currentHeights[i] * (maxH * 0.88)).clamp(6.0, maxH * 0.92);
      final double peakH = (peakHeights[i] * (maxH * 0.88)).clamp(6.0, maxH * 0.92);

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baselineY - barH, barW, barH),
        const Radius.circular(3),
      );

      final Paint barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            color.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromLTWH(x, baselineY - barH, barW, barH));

      canvas.drawRRect(barRect, barPaint);

      if (isPlaying) {
        final double peakY = baselineY - peakH - 3.0;
        final Paint peakPaint = Paint()
          ..color = color.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, peakY, barW, 2.5), const Radius.circular(1.5)),
          peakPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumBarsPainter oldDelegate) => true;
}
