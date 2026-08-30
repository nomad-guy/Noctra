import 'package:flutter/material.dart';

class NoctraAppLogo extends StatelessWidget {
  final double size;
  final double radius;
  final bool isDark;
  final bool showGlow;

  const NoctraAppLogo({
    super.key,
    this.size = 32,
    this.radius = 8,
    required this.isDark,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.18);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: (size > 60) ? 1.5 : 1.0),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.18),
                  blurRadius: size * 0.4,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(size * 0.72, size * 0.72),
        painter: _NoctraEmblemPainter(isDark: isDark),
      ),
    );
  }
}

class _NoctraEmblemPainter extends CustomPainter {
  final bool isDark;

  const _NoctraEmblemPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final fgColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final w = size.width;
    final h = size.height;

    // 1. Sleek Crescent Moon / Acoustic Arc
    final moonPaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final moonPath = Path();
    moonPath.moveTo(w * 0.48, h * 0.10);
    moonPath.cubicTo(w * 0.18, h * 0.12, w * 0.08, h * 0.40, w * 0.12, h * 0.65);
    moonPath.cubicTo(w * 0.16, h * 0.88, w * 0.40, h * 0.94, w * 0.62, h * 0.88);
    moonPath.cubicTo(w * 0.38, h * 0.82, w * 0.26, h * 0.62, w * 0.26, h * 0.50);
    moonPath.cubicTo(w * 0.26, h * 0.32, w * 0.36, h * 0.20, w * 0.48, h * 0.10);
    moonPath.close();
    canvas.drawPath(moonPath, moonPaint);

    // 2. Center-Right Acoustic Sound Pillar (Stylized 'N' Diagonal Apex)
    final barPaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pillarPath = Path();
    pillarPath.moveTo(w * 0.46, h * 0.28);
    pillarPath.lineTo(w * 0.58, h * 0.28);
    pillarPath.lineTo(w * 0.78, h * 0.72);
    pillarPath.lineTo(w * 0.66, h * 0.72);
    pillarPath.close();
    canvas.drawPath(pillarPath, barPaint);

    // 3. Right Soundwave Aperture Node
    final nodePaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final rightBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.76, h * 0.32, w * 0.12, h * 0.44),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(rightBar, nodePaint);

    // 4. Harmonic Pulse Point
    final pulsePaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.52, h * 0.82), w * 0.05, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _NoctraEmblemPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
