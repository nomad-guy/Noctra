import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

enum NoirThemeMode {
  noirBlack,
  noirWhite,
  noirAmoled,
  liquidGlass,
}

extension NoirThemeModeX on NoirThemeMode {
  bool get isDark => this != NoirThemeMode.noirWhite;
  bool get isAmoled => this == NoirThemeMode.noirAmoled;
  bool get isLiquidGlass => this == NoirThemeMode.liquidGlass;
  bool get isWhite => this == NoirThemeMode.noirWhite;
}

/// Semantic design tokens shared by every surface in the app. Widgets should
/// read these from Theme.of(context) instead of branching on raw black/white
/// colors. Adding a theme only requires supplying another token set here.
@immutable
class NoctraThemeTokens extends ThemeExtension<NoctraThemeTokens> {
  final Color canvas;
  final Color surface;
  final Color surfaceVariant;
  final Color elevatedSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color border;
  final Color subtleBorder;
  final Color accent;
  final Color secondaryAccent;
  final Color tertiaryAccent;
  final Color scrim;
  final double glassBlurSigma;

  const NoctraThemeTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceVariant,
    required this.elevatedSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.border,
    required this.subtleBorder,
    required this.accent,
    required this.secondaryAccent,
    required this.tertiaryAccent,
    required this.scrim,
    this.glassBlurSigma = 0,
  });

  @override
  NoctraThemeTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceVariant,
    Color? elevatedSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? border,
    Color? subtleBorder,
    Color? accent,
    Color? secondaryAccent,
    Color? tertiaryAccent,
    Color? scrim,
    double? glassBlurSigma,
  }) =>
      NoctraThemeTokens(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        elevatedSurface: elevatedSurface ?? this.elevatedSurface,
        primaryText: primaryText ?? this.primaryText,
        secondaryText: secondaryText ?? this.secondaryText,
        tertiaryText: tertiaryText ?? this.tertiaryText,
        border: border ?? this.border,
        subtleBorder: subtleBorder ?? this.subtleBorder,
        accent: accent ?? this.accent,
        secondaryAccent: secondaryAccent ?? this.secondaryAccent,
        tertiaryAccent: tertiaryAccent ?? this.tertiaryAccent,
        scrim: scrim ?? this.scrim,
        glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      );

  @override
  NoctraThemeTokens lerp(ThemeExtension<NoctraThemeTokens>? other, double t) {
    if (other is! NoctraThemeTokens) return this;
    return NoctraThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiaryText: Color.lerp(tertiaryText, other.tertiaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      tertiaryAccent: Color.lerp(tertiaryAccent, other.tertiaryAccent, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      glassBlurSigma: lerpDouble(glassBlurSigma, other.glassBlurSigma, t)!,
    );
  }
}

extension NoctraThemeContext on BuildContext {
  NoctraThemeTokens get noctraTokens {
    final theme = Theme.of(this);
    return theme.extension<NoctraThemeTokens>() ??
        NoctraThemeTokens(
          canvas: theme.scaffoldBackgroundColor,
          surface: theme.colorScheme.surface,
          surfaceVariant: theme.colorScheme.surfaceContainerHighest,
          elevatedSurface: theme.colorScheme.surfaceContainerHigh,
          primaryText: theme.colorScheme.onSurface,
          secondaryText: theme.colorScheme.onSurfaceVariant,
          tertiaryText: theme.colorScheme.onSurfaceVariant,
          border: theme.colorScheme.outline,
          subtleBorder: theme.colorScheme.outlineVariant,
          accent: theme.colorScheme.primary,
          secondaryAccent: theme.colorScheme.secondary,
          tertiaryAccent: theme.colorScheme.tertiary,
          scrim: theme.colorScheme.scrim,
        );
  }
}

class NoirColors {
  // Pure Monochromatic Noir Black Palette
  static const Color blackCanvas = Color(0xFF070709);
  static const Color blackSurface = Color(0xFF0E0E12);
  static const Color blackSurfaceVariant = Color(0xFF16161C);
  static const Color blackGlassBg = Color(0xCC0D0D0E);
  static const Color blackBorder = Color(0x28FFFFFF);
  static const Color blackBorderSubtle = Color(0x12FFFFFF);
  static const Color blackTextPrimary = Color(0xFFFFFFFF);
  static const Color blackTextSecondary = Color(0xFF929298);
  static const Color blackTextTertiary = Color(0xFF58585E);
  static const Color blackAccent = Color(0xFFFFFFFF);

  // Pure Monochromatic Noir White Palette
  static const Color whiteCanvas = Color(0xFFF4F4F6);
  static const Color whiteSurface = Color(0xFFFFFFFF);
  static const Color whiteSurfaceVariant = Color(0xFFEBEBF0);
  static const Color whiteGlassBg = Color(0xDEFFFFFF);
  static const Color whiteBorder = Color(0x2E000000);
  static const Color whiteBorderSubtle = Color(0x0F000000);
  static const Color whiteTextPrimary = Color(0xFF060608);
  static const Color whiteTextSecondary = Color(0xFF5C5C64);
  static const Color whiteTextTertiary = Color(0xFFA2A2AA);
  static const Color whiteAccent = Color(0xFF000000);

  // True Pitch Black AMOLED Palette (0% OLED Power)
  static const Color amoledCanvas = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF000000);
  static const Color amoledSurfaceVariant = Color(0xFF0A0A0A);
  // Liquid Glass — deep sapphire canvas, glass surfaces, aurora cyan actions,
  // violet selection, and mint confirmation. Visibly sapphire blue.
  static const Color glassCanvas = Color(0xFF162E4A);
  static const Color glassSurface = Color(0xD0253E60);
  static const Color glassSurfaceVariant = Color(0xC0356080);
  static const Color glassElevatedSurface = Color(0xDF4A7AAA);
  static const Color glassTextPrimary = Color(0xFFF0F6FF);
  static const Color glassTextSecondary = Color(0xFFB0C8E8);
  static const Color glassTextTertiary = Color(0xFF6E8EB8);
  static const Color glassAccent = Color(0xFF7EC8FF);
  static const Color glassSecondaryAccent = Color(0xFFB8A8FF);
  static const Color glassTertiaryAccent = Color(0xFF68E8C0);
}

class NoirTheme {
  static ThemeData getTheme(NoirThemeMode mode) {
    final isWhite = mode == NoirThemeMode.noirWhite;
    final isAmoled = mode == NoirThemeMode.noirAmoled;
    final isLiquidGlass = mode == NoirThemeMode.liquidGlass;

    final canvas = isWhite
        ? NoirColors.whiteCanvas
        : (isAmoled
            ? NoirColors.amoledCanvas
            : (isLiquidGlass
                ? NoirColors.glassCanvas
                : NoirColors.blackCanvas));
    final surface = isWhite
        ? NoirColors.whiteSurface
        : (isAmoled
            ? NoirColors.amoledSurface
            : (isLiquidGlass
                ? NoirColors.glassSurface
                : NoirColors.blackSurface));
    final textPrimary = isWhite
        ? NoirColors.whiteTextPrimary
        : (isLiquidGlass
            ? NoirColors.glassTextPrimary
            : NoirColors.blackTextPrimary);
    final textSecondary = isWhite
        ? NoirColors.whiteTextSecondary
        : (isLiquidGlass
            ? NoirColors.glassTextSecondary
            : NoirColors.blackTextSecondary);
    final accent = isWhite
        ? NoirColors.whiteAccent
        : (isLiquidGlass ? NoirColors.glassAccent : NoirColors.blackAccent);
    final secondaryAccent = isLiquidGlass
        ? NoirColors.glassSecondaryAccent
        : (isWhite ? const Color(0xFF636366) : const Color(0xFF8E8E93));
    final tertiaryAccent =
        isLiquidGlass ? NoirColors.glassTertiaryAccent : accent;
    final tokens = NoctraThemeTokens(
      canvas: canvas,
      surface: surface,
      surfaceVariant: isWhite
          ? NoirColors.whiteSurfaceVariant
          : (isAmoled
              ? NoirColors.amoledSurfaceVariant
              : (isLiquidGlass
                  ? NoirColors.glassSurfaceVariant
                  : NoirColors.blackSurfaceVariant)),
      elevatedSurface: isWhite
          ? NoirColors.whiteSurface
          : (isAmoled
              ? const Color(0xFF101010)
              : (isLiquidGlass
                  ? NoirColors.glassElevatedSurface
                  : const Color(0xFF1C1C20))),
      primaryText: textPrimary,
      secondaryText: textSecondary,
      tertiaryText: isWhite
          ? NoirColors.whiteTextTertiary
          : (isLiquidGlass
              ? NoirColors.glassTextTertiary
              : NoirColors.blackTextTertiary),
      border: isWhite
          ? NoirColors.whiteBorder
          : (isLiquidGlass ? const Color(0x77D0E4FF) : NoirColors.blackBorder),
      subtleBorder: isWhite
          ? NoirColors.whiteBorderSubtle
          : (isLiquidGlass
              ? const Color(0x44C0D8F0)
              : NoirColors.blackBorderSubtle),
      accent: accent,
      secondaryAccent: secondaryAccent,
      tertiaryAccent: tertiaryAccent,
      scrim: Colors.black
          .withValues(alpha: isWhite ? 0.18 : (isLiquidGlass ? 0.28 : 0.52)),
      glassBlurSigma: isLiquidGlass ? 18 : 0,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isWhite ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme(
        brightness: isWhite ? Brightness.light : Brightness.dark,
        primary: accent,
        onPrimary: isWhite ? Colors.white : Colors.black,
        secondary: secondaryAccent,
        onSecondary: isWhite ? Colors.white : Colors.black,
        tertiary: tertiaryAccent,
        onTertiary: Colors.black,
        error: isWhite ? const Color(0xFF424242) : const Color(0xFFB0B0B0),
        onError: isWhite ? Colors.white : Colors.black,
        surface: surface,
        onSurface: textPrimary,
      ),
      extensions: [tokens],
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            color: textPrimary),
        headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: textPrimary),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
        labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static BoxDecoration liquidGlassDecoration({
    required bool isDark,
    double radius = 18,
    bool isHighlighted = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: isHighlighted ? 0.12 : 0.07),
                const Color(0xFF0E0E10).withValues(alpha: 0.88),
                const Color(0xFF060608).withValues(alpha: 0.94),
              ]
            : [
                Colors.white.withValues(alpha: 0.96),
                const Color(0xFFF7F7FA).withValues(alpha: 0.90),
                const Color(0xFFEDEDF2).withValues(alpha: 0.85),
              ],
        stops: const [0.0, 0.45, 1.0],
      ),
      border: Border.all(
        color: isDark
            ? (isHighlighted
                ? NoirColors.blackBorder
                : NoirColors.blackBorderSubtle)
            : (isHighlighted
                ? NoirColors.whiteBorder
                : NoirColors.whiteBorderSubtle),
        width: 1.0,
      ),
    );
  }
}

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
              child: _LiquidOrb(size: 480, color: Color(0x9068C8FF))),
          const Positioned(
              bottom: -250,
              right: -180,
              child: _LiquidOrb(size: 520, color: Color(0x808070FF))),
          const Positioned(
              top: 300,
              right: -150,
              child: _LiquidOrb(size: 330, color: Color(0x6068E8C0))),
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
              gradient: RadialGradient(colors: [color, Colors.transparent])),
        ),
      );
}
