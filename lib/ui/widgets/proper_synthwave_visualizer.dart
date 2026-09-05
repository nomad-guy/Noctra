import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/audio/audio_visualizer_service.dart';
import 'proper_synthwave_painter.dart';

class ProperSynthwaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final bool isDark;
  final double height;

  /// Active theme accent. Noir Black = white, Noir White = black, Liquid
  /// Glass = the glass-blue accent. Used for the sun glow, wave stroke,
  /// grid lines and horizon so the scene recolors with the theme.
  final Color accent;

  /// When true the scene is drawn with the Liquid Glass sapphire palette
  /// instead of the Noir chrome palette.
  final bool isLiquidGlass;

  const ProperSynthwaveVisualizer({
    super.key,
    required this.isPlaying,
    required this.isDark,
    this.accent = const Color(0xFF7EC8FF),
    this.isLiquidGlass = false,
    this.height = 160,
  });

  @override
  State<ProperSynthwaveVisualizer> createState() =>
      _ProperSynthwaveVisualizerState();
}

class _ProperSynthwaveVisualizerState
    extends State<ProperSynthwaveVisualizer>
    with SingleTickerProviderStateMixin {
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
        _mountainPeakHeights[i] =
            (_mountainPeakHeights[i] * 0.60 + w * 0.40).clamp(2.0, 32.0);
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
              painter: ProperSynthwavePainter(
                progress: _controller.value,
                mountainHeights: _mountainPeakHeights,
                bassEnergy: _bassEnergy,
                isPlaying: widget.isPlaying,
                isDark: widget.isDark,
                accent: widget.accent,
                isLiquidGlass: widget.isLiquidGlass,
              ),
            ),
          );
        },
      ),
    );
  }
}
