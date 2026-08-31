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

  @override
  void initState() {
    super.initState();
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
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !widget.isPlaying && _controller.isAnimating) {
            _controller.stop();
          }
        });
      }
    }
  }

  void _applyTick() {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (widget.isPlaying) {
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

    final horizonY = h * 0.46;
    final vp = Offset(w / 2, horizonY);

    final Rect skyRect = Rect.fromLTWH(0, 0, w, horizonY);
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark ? [const Color(0xFF050010), const Color(0xFF260447)] : [const Color(0xFFEDE8F8), const Color(0xFFD0C3E6)],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final double sunRadius = (h * 0.27) + (bassEnergy * 8.0).clamp(0.0, 14.0);
    final Offset sunCenter = Offset(w / 2, horizonY);
    final Rect sunRect = Rect.fromCircle(center: sunCenter, radius: sunRadius);

    final Paint sunPaint = Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFF007F), Color(0xFFFF8C00)]).createShader(sunRect);

    canvas.save();
    canvas.clipRect(skyRect);
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    final Paint slatPaint = Paint()..color = isDark ? const Color(0xFF120326) : const Color(0xFFD0C3E6);
    for (int i = 1; i <= 6; i++) {
      final slatY = horizonY - (i * (sunRadius / 7));
      final slatH = 1.0 + (i * 1.0);
      canvas.drawRect(Rect.fromLTWH(sunCenter.dx - sunRadius, slatY, sunRadius * 2, slatH), slatPaint);
    }
    canvas.restore();

    final Path mountainPath = Path();
    mountainPath.moveTo(0, horizonY);
    const int pts = 16;
    for (int i = 0; i <= pts; i++) {
      final double x = (w * (i / pts));
      final double bump = isPlaying ? (mountainHeights[i % 16] * sin((i / pts) * pi)) : 2.0;
      final double y = horizonY - 4.0 - bump;
      mountainPath.lineTo(x, y);
    }
    mountainPath.lineTo(w, horizonY);
    mountainPath.close();

    final Paint mountainPaint = Paint()..color = isDark ? const Color(0xFF130026) : const Color(0xFF9072B0);
    canvas.drawPath(mountainPath, mountainPaint);

    final Rect groundRect = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    final Paint groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark ? [const Color(0xFF0F001F), const Color(0xFF000000)] : [const Color(0xFFCFBFE3), const Color(0xFFF7F7F9)],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    final gridColor = isDark ? const Color(0xFF00F0FF) : const Color(0xFF7000FF);
    final Paint linePaint = Paint()..color = gridColor.withValues(alpha: isPlaying ? 0.75 : 0.40)..strokeWidth = 1.4;

    const int numVLines = 18;
    for (int i = 0; i <= numVLines; i++) {
      final double bottomX = w * (i / numVLines);
      canvas.drawLine(vp, Offset(bottomX, h), linePaint);
    }

    const int numHLines = 10;
    for (int i = 0; i < numHLines; i++) {
      final double norm = ((i + progress) % numHLines) / numHLines;
      final double eased = pow(norm, 2.5).toDouble();
      final double lineY = horizonY + (eased * (h - horizonY));
      final double alpha = (norm * 0.90).clamp(0.0, 0.95);
      final hPaint = Paint()..color = gridColor.withValues(alpha: alpha)..strokeWidth = 1.0 + (norm * 2.0);
      canvas.drawLine(Offset(0, lineY), Offset(w, lineY), hPaint);
    }

    final horizonPaint = Paint()..color = const Color(0xFFFF007F).withValues(alpha: 0.95)..strokeWidth = 2.4;
    canvas.drawLine(Offset(0, horizonY), Offset(w, horizonY), horizonPaint);
  }

  @override
  bool shouldRepaint(covariant _ProperSynthwavePainter oldDelegate) => true;
}
