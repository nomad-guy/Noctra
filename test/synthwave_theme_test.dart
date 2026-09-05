import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/theme/noir_theme.dart';
import 'package:noctra/ui/widgets/proper_synthwave_painter.dart';
import 'package:noctra/ui/widgets/proper_synthwave_visualizer.dart';

/// Phase 25–34 regression — the Synthwave scene must recolor with the
/// active theme. It previously ignored Liquid Glass entirely (hard-coded
/// Noir chrome + white/black). These tests pin:
///   1. the per-theme accent tokens the player feeds the visualizers,
///   2. that the painter actually receives that accent and the
///      Liquid Glass flag (instead of ignoring them),
///   3. that accent changes repaint.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('theme accents used by the player visualizers', () {
    NoctraThemeTokens tokensOf(NoirThemeMode mode) =>
        NoirTheme.getTheme(mode).extension<NoctraThemeTokens>()!;

    test('Noir Black accent is pure white', () {
      expect(tokensOf(NoirThemeMode.noirBlack).accent, const Color(0xFFFFFFFF));
    });

    test('Noir White accent is pure black', () {
      expect(tokensOf(NoirThemeMode.noirWhite).accent, const Color(0xFF000000));
    });

    test('Liquid Glass accent is the glass blue, not white/black', () {
      expect(
          tokensOf(NoirThemeMode.liquidGlass).accent, const Color(0xFF7EC8FF));
    });

    test('only Liquid Glass marks the scene as liquid glass', () {
      expect(NoirThemeMode.noirBlack.isLiquidGlass, isFalse);
      expect(NoirThemeMode.noirWhite.isLiquidGlass, isFalse);
      expect(NoirThemeMode.liquidGlass.isLiquidGlass, isTrue);
    });
  });

  group('Synthwave painter theme propagation', () {
    Future<ProperSynthwavePainter> pumpPainter(WidgetTester tester,
        {required Color accent, required bool isLiquidGlass}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProperSynthwaveVisualizer(
              isPlaying: false,
              isDark: true,
              accent: accent,
              isLiquidGlass: isLiquidGlass,
              height: 200,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ProperSynthwavePainter),
      );
      return paint.painter! as ProperSynthwavePainter;
    }

    testWidgets('Liquid Glass scene receives the glass accent + flag',
        (tester) async {
      final painter = await pumpPainter(tester,
          accent: const Color(0xFF7EC8FF), isLiquidGlass: true);
      expect(painter.accent, const Color(0xFF7EC8FF));
      expect(painter.isLiquidGlass, isTrue);
    });

    testWidgets('Noir Black scene receives white accent, no glass flag',
        (tester) async {
      final painter = await pumpPainter(tester,
          accent: const Color(0xFFFFFFFF), isLiquidGlass: false);
      expect(painter.accent, const Color(0xFFFFFFFF));
      expect(painter.isLiquidGlass, isFalse);
    });

    testWidgets('Noir White scene receives black accent, no glass flag',
        (tester) async {
      final painter = await pumpPainter(tester,
          accent: const Color(0xFF000000), isLiquidGlass: false);
      expect(painter.accent, const Color(0xFF000000));
      expect(painter.isLiquidGlass, isFalse);
    });

    testWidgets('accent change flows through a rebuild', (tester) async {
      late StateSetter hostSetState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                hostSetState = setState;
                return ProperSynthwaveVisualizer(
                  isPlaying: false,
                  isDark: true,
                  accent: const Color(0xFFFFFFFF),
                  height: 200,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      ProperSynthwavePainter painterOf() => tester
          .widget<CustomPaint>(find.byWidgetPredicate((w) =>
              w is CustomPaint && w.painter is ProperSynthwavePainter))
          .painter! as ProperSynthwavePainter;
      expect(painterOf().accent, const Color(0xFFFFFFFF));

      hostSetState(() {});
      // Rebuild with the Liquid Glass accent, as the player container does
      // when the theme switches.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ProperSynthwaveVisualizer(
                isPlaying: false,
                isDark: true,
                accent: const Color(0xFF7EC8FF),
                isLiquidGlass: true,
                height: 200,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(painterOf().accent, const Color(0xFF7EC8FF));
      expect(painterOf().isLiquidGlass, isTrue);
    });
  });
}
