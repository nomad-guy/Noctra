import 'package:flutter/material.dart';
import 'noctra_theme_tokens.dart';

export 'noctra_theme_backdrop.dart';
export 'noctra_theme_tokens.dart';

enum NoirThemeMode {
  noirBlack,
  noirWhite,
  liquidGlass,
}

extension NoirThemeModeX on NoirThemeMode {
  bool get isDark => this != NoirThemeMode.noirWhite;
  bool get isLiquidGlass => this == NoirThemeMode.liquidGlass;
  bool get isWhite => this == NoirThemeMode.noirWhite;
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
    final isLiquidGlass = mode == NoirThemeMode.liquidGlass;

    final canvas = isWhite
        ? NoirColors.whiteCanvas
        : (isLiquidGlass ? NoirColors.glassCanvas : NoirColors.blackCanvas);
    final surface = isWhite
        ? NoirColors.whiteSurface
        : (isLiquidGlass ? NoirColors.glassSurface : NoirColors.blackSurface);
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
          : (isLiquidGlass
              ? NoirColors.glassSurfaceVariant
              : NoirColors.blackSurfaceVariant),
      elevatedSurface: isWhite
          ? NoirColors.whiteSurface
          : (isLiquidGlass
              ? NoirColors.glassElevatedSurface
              : const Color(0xFF1C1C20)),
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
