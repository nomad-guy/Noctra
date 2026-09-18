import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'noctra_theme_tokens.dart';

/// Holds the platform's dynamic color schemes captured from
/// [DynamicColorBuilder] at app startup. Material U reads from here;
/// when dynamic color is unavailable (older Android, desktop), a
/// seed-based scheme derived from Noctra's own brand color is used.
class MaterialUSchemeHolder {
  MaterialUSchemeHolder._();

  static ColorScheme? light;
  static ColorScheme? dark;

  /// Seed fallback so Material U always renders a coherent Material You
  /// palette, even without OS wallpaper-derived dynamic color.
  static const int seedColor = 0xFF7EC8FF;

  static ColorScheme schemeFor(Brightness brightness) {
    if (brightness == Brightness.light) {
      return light ??
          ColorScheme.fromSeed(
              seedColor: const Color(seedColor), brightness: Brightness.light);
    }
    return dark ??
        ColorScheme.fromSeed(
            seedColor: const Color(seedColor), brightness: Brightness.dark);
  }
}

/// Material You theme: colors flow from the OS dynamic palette
/// (wallpaper-derived on Android 12+) with a branded seed fallback.
/// No glass effects — flat, high-contrast Material 3 surfaces.
ThemeData buildMaterialUTheme() {
  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final scheme = MaterialUSchemeHolder.schemeFor(platformBrightness);
  final isDarkScheme = scheme.brightness == Brightness.dark;
  final tokens = NoctraThemeTokens(
    canvas: scheme.surface,
    surface: scheme.surfaceContainerLow,
    surfaceVariant: scheme.surfaceContainer,
    elevatedSurface: scheme.surfaceContainerHigh,
    primaryText: scheme.onSurface,
    secondaryText: scheme.onSurfaceVariant,
    tertiaryText: scheme.onSurfaceVariant.withValues(alpha: 0.88),
    border: scheme.outline.withValues(alpha: 0.5),
    subtleBorder: scheme.outlineVariant.withValues(alpha: 0.3),
    accent: scheme.primary,
    secondaryAccent: scheme.secondary,
    tertiaryAccent: scheme.tertiary,
    scrim: Colors.black.withValues(alpha: isDarkScheme ? 0.5 : 0.2),
    glassBlurSigma: 0,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [tokens],
    fontFamily: 'Inter',
    textTheme: TextTheme(
      displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
          color: scheme.onSurface),
      headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface),
      titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
      bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400, color: scheme.onSurface),
      bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: scheme.onSurfaceVariant),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
