import 'dart:math';
import 'package:flutter/material.dart';

/// Painter for the retro synthwave scene (sun, mountains, grid).
///
/// Extracted from the widget file so both stay ≤300 LOC. The scene
/// recolors with the active theme: [accent] drives the sun glow, wave
/// stroke, grid lines and horizon; [isLiquidGlass] swaps the Noir
/// chrome/silver palette for the Liquid Glass sapphire palette.
class ProperSynthwavePainter extends CustomPainter {
  final double progress;
  final List<double> mountainHeights;
  final double bassEnergy;
  final bool isPlaying;
  final bool isDark;
  final Color accent;
  final bool isLiquidGlass;

  ProperSynthwavePainter({
    required this.progress,
    required this.mountainHeights,
    required this.bassEnergy,
    required this.isPlaying,
    required this.isDark,
    required this.accent,
    required this.isLiquidGlass,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final horizonY = h * 0.44;
    final vp = Offset(w / 2, horizonY);

    // 1. Sky: Noir black/white chrome, or Liquid Glass sapphire.
    final Rect skyRect = Rect.fromLTWH(0, 0, w, horizonY);
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLiquidGlass
            ? [const Color(0xFF0A1D36), const Color(0xFF1E4A78)]
            : (isDark
                ? const [Color(0xFF000000), Color(0xFF141414)]
                : const [Color(0xFFE5E5E5), Color(0xFFC0C0C0)]),
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // 2. Silver Chrome Sun / Horizon Orb
    final double sunRadius = (h * 0.28) + (bassEnergy * 10.0).clamp(0.0, 18.0);
    final Offset sunCenter = Offset(w / 2, horizonY);
    final Rect sunRect = Rect.fromCircle(center: sunCenter, radius: sunRadius);

    final Paint sunPaint = Paint()
      ..shader = RadialGradient(
        colors: isLiquidGlass
            ? [
                const Color(0xFFEAF6FF),
                accent,
                const Color(0xFF2E6FA8),
              ]
            : (isDark
                ? const [Color(0xFFFFFFFF), Color(0xFF9E9E9E), Color(0xFF424242)]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFB0B0B0),
                    Color(0xFF757575),
                  ]),
      ).createShader(sunRect);

    canvas.save();
    canvas.clipRect(skyRect);
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Horizontal Slats across the Sun (Synthwave aesthetic)
    final Paint slatPaint = Paint()
      ..color = isLiquidGlass
          ? const Color(0xFF0A1D36)
          : (isDark ? const Color(0xFF000000) : const Color(0xFFDCDCDC));
    for (int i = 1; i <= 6; i++) {
      final slatY = horizonY - (i * (sunRadius / 7));
      final slatH = 1.2 + (i * 0.8);
      canvas.drawRect(
          Rect.fromLTWH(sunCenter.dx - sunRadius, slatY, sunRadius * 2, slatH),
          slatPaint);
    }
    canvas.restore();

    // 3. High-Visibility Audio Wave Mountains (Dual-Layer)
    final Path waveBgPath = Path()..moveTo(0, horizonY);
    final Path waveFgPath = Path()..moveTo(0, horizonY);
    const int pts = 24;

    for (int i = 0; i <= pts; i++) {
      final double x = (w * (i / pts));
      final double normI = (i / pts);
      final double peakFactor = sin(normI * pi);
      final double audioBump = isPlaying
          ? ((mountainHeights[i % 16] * 1.5) * peakFactor +
              (bassEnergy * 8.0 * peakFactor))
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

    // Draw Background Wave Layer (muted accent)
    final Paint waveBgPaint = Paint()
      ..color = isLiquidGlass
          ? accent.withValues(alpha: 0.30)
          : (isDark ? const Color(0x66757575) : const Color(0x66A0A0A0))
      ..style = PaintingStyle.fill;
    canvas.drawPath(waveBgPath, waveBgPaint);

    // Draw Foreground Wave Layer
    final Paint waveFgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLiquidGlass
            ? [accent.withValues(alpha: 0.95), const Color(0x351E4A78)]
            : (isDark
                ? const [Color(0xD0E0E0E0), Color(0x801A1A1A)]
                : const [Color(0xD0FFFFFF), Color(0x808E8E93)]),
      ).createShader(Rect.fromLTWH(0, 0, w, horizonY));
    canvas.drawPath(waveFgPath, waveFgPaint);

    final Paint waveStrokePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(waveFgPath, waveStrokePaint);

    // 4. Ground Perspective Grid
    final Rect groundRect = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    final Paint groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isLiquidGlass
            ? [const Color(0xFF1A3B63), const Color(0xFF0B1A30)]
            : (isDark
                ? const [Color(0xFF101010), Color(0xFF000000)]
                : const [Color(0xFFC8C8C8), Color(0xFFEEEEEE)]),
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    // Perspective Vertical Lines (theme accent)
    final silverColor = isLiquidGlass
        ? accent
        : (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2C2C2E));
    final Paint linePaint = Paint()
      ..color = silverColor.withValues(alpha: isPlaying ? 0.65 : 0.35)
      ..strokeWidth = 1.4;

    const int numVLines = 20;
    for (int i = 0; i <= numVLines; i++) {
      final double bottomX = w * (i / numVLines);
      canvas.drawLine(vp, Offset(bottomX, h), linePaint);
    }

    // Perspective Forward Moving Horizontal Lines
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

    // 5. Razor-Sharp Horizon Laser Line
    final horizonPaint = Paint()
      ..color = accent
      ..strokeWidth = 2.4;
    canvas.drawLine(Offset(0, horizonY), Offset(w, horizonY), horizonPaint);
  }

  @override
  bool shouldRepaint(covariant ProperSynthwavePainter oldDelegate) => true;
}
