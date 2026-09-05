import 'dart:math';
import 'package:flutter/material.dart';

class RadarAxisData {
  final String label;
  final double value;

  const RadarAxisData({required this.label, required this.value});
}

class TasteRadarPainter extends CustomPainter {
  final List<RadarAxisData> axes;
  final Color accentColor;
  final Color gridColor;
  final Color textColor;

  TasteRadarPainter({
    required this.axes,
    required this.accentColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 32;
    final int count = axes.length;
    final double angleStep = (2 * pi) / count;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric polygon rings (25%, 50%, 75%, 100%)
    for (int ring = 1; ring <= 4; ring++) {
      final ringRadius = (radius / 4) * ring;
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = -pi / 2 + (i * angleStep);
        final x = center.dx + ringRadius * cos(angle);
        final y = center.dy + ringRadius * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw spokes and labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < count; i++) {
      final angle = -pi / 2 + (i * angleStep);
      final spokeEnd = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, spokeEnd, gridPaint);

      // Label positioning
      final labelRadius = radius + 20;
      final labelPos = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );

      textPainter.text = TextSpan(
        text: axes[i].label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
      textPainter.layout();
      final offset = Offset(
        labelPos.dx - (textPainter.width / 2),
        labelPos.dy - (textPainter.height / 2),
      );
      textPainter.paint(canvas, offset);
    }

    // Draw taste data polygon fill
    final dataPath = Path();
    final List<Offset> points = [];

    for (int i = 0; i < count; i++) {
      final angle = -pi / 2 + (i * angleStep);
      final clampedVal = axes[i].value.clamp(0.05, 1.0);
      final pointRadius = radius * clampedVal;
      final pt = Offset(
        center.dx + pointRadius * cos(angle),
        center.dy + pointRadius * sin(angle),
      );
      points.add(pt);
      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();

    // Fill with semi-transparent accent gradient
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.45),
          accentColor.withValues(alpha: 0.12),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // Stroke border
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(dataPath, borderPaint);

    // Draw vertex glowing dots
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final dotRingPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 5.5, dotRingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TasteRadarPainter oldDelegate) {
    return oldDelegate.axes != axes ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.gridColor != gridColor;
  }
}
