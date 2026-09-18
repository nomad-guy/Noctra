import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/theme/noir_theme.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Material U theme', () {
    test('is the 4th theme mode and builds a valid ThemeData', () {
      final theme = NoirTheme.getTheme(NoirThemeMode.materialU);
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<NoctraThemeTokens>(), isNotNull);
    });

    test('seed fallback produces coherent scheme without dynamic color', () {
      // No DynamicColorBuilder in this test: holder is empty → seed path.
      MaterialUSchemeHolder.light = null;
      MaterialUSchemeHolder.dark = null;
      final theme = NoirTheme.getTheme(NoirThemeMode.materialU);
      expect(theme.colorScheme.primary, isNot(Colors.transparent));
      expect(
        theme.scaffoldBackgroundColor,
        theme.colorScheme.surface,
      );
      final tokens = theme.extension<NoctraThemeTokens>()!;
      expect(tokens.accent, theme.colorScheme.primary);
      expect(tokens.primaryText, theme.colorScheme.onSurface);
      expect(tokens.glassBlurSigma, 0); // no glass in Material U
    });

    test('uses provided dynamic schemes when available', () {
      MaterialUSchemeHolder.light = ColorScheme.fromSeed(
        seedColor: const Color(0xFF123456),
        brightness: Brightness.light,
      );
      MaterialUSchemeHolder.dark = ColorScheme.fromSeed(
        seedColor: const Color(0xFF123456),
        brightness: Brightness.dark,
      );
      final theme = NoirTheme.getTheme(NoirThemeMode.materialU);
      expect(
        theme.colorScheme.primary,
        MaterialUSchemeHolder.schemeFor(theme.brightness).primary,
      );
      MaterialUSchemeHolder.light = null;
      MaterialUSchemeHolder.dark = null;
    });

    test('isDark follows platform brightness for materialU only', () {
      // noirWhite is always light, noirBlack always dark — unchanged.
      expect(NoirThemeMode.noirWhite.isDark, isFalse);
      expect(NoirThemeMode.noirBlack.isDark, isTrue);
      expect(NoirThemeMode.liquidGlass.isDark, isTrue);
      // materialU mirrors the test binding's platform brightness (dark by
      // default in the test environment).
      expect(NoirThemeMode.materialU.isDark,
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
    });

    test('theme mode persistence round-trips materialU', () {
      expect(
        NoctraLocalDatabase.normalizeThemeMode('materialU'),
        'materialU',
      );
      expect(
        NoctraLocalDatabase.normalizeThemeMode('material_you'),
        'materialU',
      );
      expect(
        NoctraLocalDatabase.normalizeThemeMode('MATERIALU'),
        'materialU',
      );
      // Legacy values still normalize.
      expect(
        NoctraLocalDatabase.normalizeThemeMode('noirWhite'),
        'noirWhite',
      );
      expect(
        NoctraLocalDatabase.normalizeThemeMode('unknownTheme'),
        'noirBlack',
      );
    });
  });
}
