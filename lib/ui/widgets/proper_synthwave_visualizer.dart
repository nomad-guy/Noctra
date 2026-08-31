import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/audio/audio_visualizer_service.dart';

class ProperSynthwaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final bool isDark;
  final double height;

  const ProperSynthwaveVisualizer({
    super.key,
    required this.isPlaying,
    required this.isDark,
    this.height = 160,
  });

  @override
  State<ProperSynthwaveVisualizer> createState() => _ProperSynthwaveVisualizerState();
}

class _ProperSynthwaveVisualizerState extends State<ProperSynthwaveVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription? _fftSub;
  final List<double> _mountainPeakHeights = List.filled(16, 4.0);
  double _bassEnergy = 0.4;

  late bool _isPlaying;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isPlaying;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(_applyTick);
    _controller.repeat();

    _fftSub = AudioVisualizerService().fftStream.listen((fftData) {
      if (!mounted) return;
      if (fftData.isNotEmpty) {
        _bassEnergy = ((fftData[0] + fftData[1] + fftData[2]) / 3.0) * 1.8;
      }
      for (int i = 0; i < 16 && (i * 2) < fftData.length; i++) {
        final mag = (fftData[i * 2] * 28.0).clamp(2.0, 32.0);
        if (mag > _mountainPeakHeights[i]) {
          _mountainPeakHeights[i] += (mag - _mountainPeakHeights[i]) * 0.75;
        }
      }
    });
    AudioVisualizerService().subscribe();
    if (!widget.isPlaying) _controller.stop();
  }

  @override
  void didUpdateWidget(ProperSynthwaveVisualizer oldWidget) {
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

  void _applyTick() {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (_isPlaying) {
      final pulse = (sin(t * 8.5) * 0.35 + 0.65).clamp(0.2, 1.2);
      _bassEnergy = (_bassEnergy * 0.60 + pulse * 0.40).clamp(0.1, 1.4);
      for (int i = 0; i < 16; i++) {
        final w = (sin(t * 6.0 + i * 0.45) * 0.45 + 0.55) * 20.0;
        _mountainPeakHeights[i] = (_mountainPeakHeights[i] * 0.60 + w * 0.40).clamp(2.0, 32.0);
      }
    } else {
      _bassEnergy = max(0.0, _bassEnergy * 0.88);
      for (int i = 0; i < 16; i++) {
        _mountainPeakHeights[i] = max(0.0, _mountainPeakHeights[i] * 0.85);
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
              painter: _ProperSynthwavePainter(
                progress: _controller.value,
                mountainHeights: _mountainPeakHeights,
                bassEnergy: _bassEnergy,
                isPlaying: widget.isPlaying,
                isDark: widget.isDark,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProperSynthwavePainter extends CustomPainter {
  final double progress;
  final List<double> mountainHeights;
  final double bassEnergy;
  final bool isPlaying;
  final bool isDark;

  _ProperSynthwavePainter({
    required this.progress,
    required this.mountainHeights,
    required this.bassEnergy,
    required this.isPlaying,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final horizonY = h * 0.44;
    final vp = Offset(w / 2, horizonY);

    // 1. Black & Silver Noir Sky
    final Rect skyRect = Rect.fromLTWH(0, 0, w, horizonY);
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF000000), const Color(0xFF141414)]
            : [const Color(0xFFE5E5E5), const Color(0xFFC0C0C0)],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // 2. Silver Chrome Sun / Horizon Orb
    final double sunRadius = (h * 0.28) + (bassEnergy * 10.0).clamp(0.0, 18.0);
    final Offset sunCenter = Offset(w / 2, horizonY);
    final Rect sunRect = Rect.fromCircle(center: sunCenter, radius: sunRadius);

    final Paint sunPaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [const Color(0xFFFFFFFF), const Color(0xFF9E9E9E), const Color(0xFF424242)]
            : [const Color(0xFFFFFFFF), const Color(0xFFB0B0B0), const Color(0xFF757575)],
      ).createShader(sunRect);

    canvas.save();
    canvas.clipRect(skyRect);
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Horizontal Slats across the Sun (Synthwave aesthetic)
    final Paint slatPaint = Paint()..color = isDark ? const Color(0xFF000000) : const Color(0xFFDCDCDC);
    for (int i = 1; i <= 6; i++) {
      final slatY = horizonY - (i * (sunRadius / 7));
      final slatH = 1.2 + (i * 0.8);
      canvas.drawRect(Rect.fromLTWH(sunCenter.dx - sunRadius, slatY, sunRadius * 2, slatH), slatPaint);
    }
    canvas.restore();

    // 3. High-Visibility Audio Wave Mountains (Dual-Layer: Silver Shadow + Pure White Peak)
    final Path waveBgPath = Path()..moveTo(0, horizonY);
    final Path waveFgPath = Path()..moveTo(0, horizonY);
    const int pts = 24;

    for (int i = 0; i <= pts; i++) {
      final double x = (w * (i / pts));
      final double normI = (i / pts);
      final double peakFactor = sin(normI * pi);
      final double audioBump = isPlaying
          ? ((mountainHeights[i % 16] * 1.5) * peakFactor + (bassEnergy * 8.0 * peakFactor))
          : 4.0 * peakFactor;

      final double yBg = horizonY - 4.0 - (audioBump * 0.65);
      final double yFg = horizonY - 6.0 - audioBump;

      waveBgPath.lineTo(x, yBg);
      waveFgPath.lineTo(x, yFg);
    }
    waveBgPath.lineTo(w, horizonY);
    waveBgPath.close();
    waveFgPath.lineTo(w, horizonY);
    waveFgPath.close();

    // Draw Background Wave Layer (Muted Silver)
    final Paint waveBgPaint = Paint()
      ..color = isDark ? const Color(0x66757575) : const Color(0x66A0A0A0)
      ..style = PaintingStyle.fill;
    canvas.drawPath(waveBgPath, waveBgPaint);

    // Draw Foreground Wave Layer (Silver Gradient Fill + Bright White Outline)
    final Paint waveFgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xD0E0E0E0), const Color(0x801A1A1A)]
            : [const Color(0xD0FFFFFF), const Color(0x808E8E93)],
      ).createShader(Rect.fromLTWH(0, 0, w, horizonY));
    canvas.drawPath(waveFgPath, waveFgPaint);

    final Paint waveStrokePaint = Paint()
      ..color = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(waveFgPath, waveStrokePaint);

    // 4. Ground Perspective Grid (Jet Black to Charcoal Ground)
    final Rect groundRect = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    final Paint groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF101010), const Color(0xFF000000)]
            : [const Color(0xFFC8C8C8), const Color(0xFFEEEEEE)],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    // Perspective Vertical Lines (Silver)
    final silverColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2C2C2E);
    final Paint linePaint = Paint()
      ..color = silverColor.withValues(alpha: isPlaying ? 0.65 : 0.35)
      ..strokeWidth = 1.4;

    const int numVLines = 20;
    for (int i = 0; i <= numVLines; i++) {
      final double bottomX = w * (i / numVLines);
      canvas.drawLine(vp, Offset(bottomX, h), linePaint);
    }

    // Perspective Forward Moving Horizontal Lines (Silver)
    const int numHLines = 12;
    for (int i = 0; i < numHLines; i++) {
      final double norm = ((i + progress) % numHLines) / numHLines;
      final double eased = pow(norm, 2.8).toDouble();
      final double lineY = horizonY + (eased * (h - horizonY));
      final double alpha = (norm * 0.95).clamp(0.0, 0.95);
      final hPaint = Paint()
        ..color = silverColor.withValues(alpha: alpha)
        ..strokeWidth = 1.0 + (norm * 2.2);
      canvas.drawLine(Offset(0, lineY), Offset(w, lineY), hPaint);
    }

    // 5. Razor-Sharp Metallic Silver Horizon Laser Line
    final horizonPaint = Paint()
      ..color = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A)
      ..strokeWidth = 2.4;
    canvas.drawLine(Offset(0, horizonY), Offset(w, horizonY), horizonPaint);
  }

  @override
  bool shouldRepaint(covariant _ProperSynthwavePainter oldDelegate) => true;
}
