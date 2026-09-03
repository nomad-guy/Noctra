import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';

class NoctraAppLogo extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final tokens = context.noctraTokens;

    final bgColor = tokens.canvas;
    final borderColor = tokens.subtleBorder;
    final glowColor = themeMode.isLiquidGlass
        ? const Color(0xFF7EC8FF).withValues(alpha: 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.18));
    final shadowColor = themeMode.isLiquidGlass
        ? const Color(0xFF7EC8FF).withValues(alpha: 0.20)
        : (isDark
            ? Colors.black.withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.08));

    // Pick the right themed PNG variant
    final String logoAsset;
    switch (themeMode) {
      case NoirThemeMode.noirWhite:
        logoAsset = 'assets/images/logo_noctra_noir_white.png';
        break;
      case NoirThemeMode.liquidGlass:
        logoAsset = 'assets/images/logo_noctra_liquid_glass.png';
        break;
      case NoirThemeMode.noirBlack:
        logoAsset = 'assets/images/logo_noctra_noir_black.png';
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: borderColor, width: (size > 60) ? 1.5 : 1.0),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: glowColor,
                  blurRadius: size * 0.4,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Image.asset(
          logoAsset,
          width: size * 0.78,
          height: size * 0.78,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            Icons.music_note_rounded,
            size: size * 0.5,
            color: tokens.primaryText,
          ),
        ),
      ),
    );
  }
}
