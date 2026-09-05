import 'package:flutter/material.dart';
import 'noctra_theme_tokens.dart';

/// Global backdrop for Liquid Glass. Screens can keep transparent scaffolds
/// and still share one continuous, layered glass canvas.
class NoctraThemeBackdrop extends StatelessWidget {
  final Widget child;
  const NoctraThemeBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.noctraTokens;
    if (tokens.glassBlurSigma == 0) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0E2444),
            tokens.canvas,
            const Color(0xFF161838)
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -220,
            left: -160,
            child: _LiquidOrb(size: 480, color: Color(0x9068C8FF)),
          ),
          const Positioned(
            bottom: -250,
            right: -180,
            child: _LiquidOrb(size: 520, color: Color(0x808070FF)),
          ),
          const Positioned(
            top: 300,
            right: -150,
            child: _LiquidOrb(size: 330, color: Color(0x6068E8C0)),
          ),
          child,
        ],
      ),
    );
  }
}

class _LiquidOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _LiquidOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, Colors.transparent]),
          ),
        ),
      );
}
