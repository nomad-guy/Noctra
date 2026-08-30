import 'package:flutter/material.dart';

enum NoirThemeMode {
  noirBlack,
  noirWhite,
  noirAmoled,
}

extension NoirThemeModeX on NoirThemeMode {
  bool get isDark => this != NoirThemeMode.noirWhite;
  bool get isAmoled => this == NoirThemeMode.noirAmoled;
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

  // True Pitch Black AMOLED Palette (0% OLED Power)
  static const Color amoledCanvas = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF000000);
  static const Color amoledSurfaceVariant = Color(0xFF0A0A0A);
}

class NoirTheme {
  static ThemeData getTheme(NoirThemeMode mode) {
    final isWhite = mode == NoirThemeMode.noirWhite;
    final isAmoled = mode == NoirThemeMode.noirAmoled;

    final canvas = isWhite ? NoirColors.whiteCanvas : (isAmoled ? NoirColors.amoledCanvas : NoirColors.blackCanvas);
    final surface = isWhite ? NoirColors.whiteSurface : (isAmoled ? NoirColors.amoledSurface : NoirColors.blackSurface);
    final textPrimary = isWhite ? NoirColors.whiteTextPrimary : NoirColors.blackTextPrimary;
    final textSecondary = isWhite ? NoirColors.whiteTextSecondary : NoirColors.blackTextSecondary;
    final accent = isWhite ? NoirColors.whiteAccent : NoirColors.blackAccent;

    return ThemeData(
      useMaterial3: true,
      brightness: isWhite ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme(
        brightness: isWhite ? Brightness.light : Brightness.dark,
        primary: accent,
        onPrimary: isWhite ? Colors.white : Colors.black,
        secondary: isWhite ? const Color(0xFF636366) : const Color(0xFF8E8E93),
        onSecondary: isWhite ? Colors.white : Colors.black,
        error: isWhite ? const Color(0xFF424242) : const Color(0xFFB0B0B0),
        onError: isWhite ? Colors.white : Colors.black,
        surface: surface,
        onSurface: textPrimary,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.9, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: textPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: textSecondary),
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
        color: isDark ? (isHighlighted ? NoirColors.blackBorder : NoirColors.blackBorderSubtle) : (isHighlighted ? NoirColors.whiteBorder : NoirColors.whiteBorderSubtle),
        width: 1.0,
      ),
    );
  }
}
