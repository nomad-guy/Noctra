import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/lyrics/lyrics_service.dart';
import 'package:noctra/ui/widgets/lyrics_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LyricsService.clearCacheForTest();
  });

  tearDown(() {
    LyricsService.clearCacheForTest();
  });

  group('LyricsView.findActiveIndex - Single Source of Truth Resolution', () {
    final sampleLines = [
      const LyricLine(timestamp: Duration(seconds: 4), text: 'Line 0 at 00:04'),
      const LyricLine(timestamp: Duration(seconds: 8), text: 'Line 1 at 00:08'),
      const LyricLine(timestamp: Duration(seconds: 14), text: 'Line 2 at 00:14'),
      const LyricLine(timestamp: Duration(seconds: 22), text: 'Line 3 at 00:22'),
    ];

    test('returns -1 on empty lyrics list', () {
      expect(LyricsView.findActiveIndex([], const Duration(seconds: 10)), -1);
    });

    test('returns -1 when position is strictly before first lyric line', () {
      expect(LyricsView.findActiveIndex(sampleLines, Duration.zero), -1);
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 3, milliseconds: 999)), -1);
    });

    test('returns exact index on exact timestamp hit', () {
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 4)), 0);
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 8)), 1);
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 14)), 2);
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 22)), 3);
    });

    test('returns preceding line index when position is between timestamps', () {
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 5)), 0);
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 10)), 1);
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 21, milliseconds: 500)), 2);
    });

    test('returns last index when position is after last lyric line', () {
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(seconds: 30)), 3);
      expect(LyricsView.findActiveIndex(sampleLines, const Duration(minutes: 5)), 3);
    });

    test('handles duplicate timestamps deterministically by picking latest line', () {
      final duplicateLines = [
        const LyricLine(timestamp: Duration(seconds: 2), text: 'First at 2'),
        const LyricLine(timestamp: Duration(seconds: 5), text: 'A at 5'),
        const LyricLine(timestamp: Duration(seconds: 5), text: 'B at 5 (latest)'),
        const LyricLine(timestamp: Duration(seconds: 10), text: 'Next at 10'),
      ];
      expect(LyricsView.findActiveIndex(duplicateLines, const Duration(seconds: 5)), 2);
    });

    test('handles large timestamp gaps correctly without premature jumping', () {
      final gapLines = [
        const LyricLine(timestamp: Duration(seconds: 10), text: 'Intro ends'),
        const LyricLine(timestamp: Duration(minutes: 2), text: 'Verse 1 after long guitar solo'),
      ];
      expect(LyricsView.findActiveIndex(gapLines, const Duration(seconds: 30)), 0);
      expect(LyricsView.findActiveIndex(gapLines, const Duration(seconds: 119)), 0);
      expect(LyricsView.findActiveIndex(gapLines, const Duration(minutes: 2)), 1);
    });
  });

  group('LyricsView Widget - Viewport Following & Auto-Scroll Integration', () {
    final testSong = Song(
      id: 'test_song_autoscroll_1',
      title: 'Auto Scroll Anthem',
      artist: 'Noctra Test Crew',
      album: 'Test Album',
      duration: const Duration(seconds: 300),
    );

    // 25 lines so the list overflows the viewport and requires real scrolling
    final testLines = List.generate(
      25,
      (i) => LyricLine(
        timestamp: Duration(seconds: i * 4),
        text: 'Lyric Line $i: Sing along with the music at timestamp ${i * 4}s',
      ),
    );

    setUp(() {
      final lyricsData = LyricsData(
        isSynced: true,
        lines: testLines,
        plainText: testLines.map((l) => l.text).join('\n'),
      );
      LyricsService.setCacheForSong(testSong, lyricsData);
    });

    testWidgets('Renders synced lyrics and follows active line with auto-scroll', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 350,
                child: LyricsView(song: testSong),
              ),
            ),
          ),
        ),
      );

      // Wait for FutureBuilder to resolve
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // First line should be visible
      expect(find.textContaining('Lyric Line 0:'), findsOneWidget);

      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);

      final scrollable = tester.widget<SingleChildScrollView>(scrollableFinder);
      final controller = scrollable.controller!;
      expect(controller.hasClients, isTrue);

      final initialOffset = controller.offset;

      // Tap on a line far down the list (e.g., Line 12)
      // Since it's inside SingleChildScrollView, we can bring it into view and tap
      await tester.ensureVisible(find.textContaining('Lyric Line 12:'));
      await tester.pumpAndSettle();

      // Tap line 12
      await tester.tap(find.textContaining('Lyric Line 12:'));
      await tester.pumpAndSettle();

      // The offset should now have moved down significantly
      expect(controller.offset, greaterThan(initialOffset));

      // Tap line 2 (seek backward)
      await tester.ensureVisible(find.textContaining('Lyric Line 2:'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Lyric Line 2:'));
      await tester.pumpAndSettle();

      // The offset should have moved back up
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
    });

    testWidgets('Manual scrolling reveals "Sync with Song" chip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 350,
                child: LyricsView(song: testSong),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially "Sync with Song" chip should not be visible
      expect(find.text('Sync with Song'), findsNothing);

      // Drag to scroll manually
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -150));
      await tester.pump();

      // After user drag, "Sync with Song" chip appears
      expect(find.text('Sync with Song'), findsOneWidget);

      // Tapping "Sync with Song" resumes auto-scroll
      await tester.tap(find.text('Sync with Song'));
      await tester.pumpAndSettle();

      // "Sync with Song" chip disappears after tapping
      expect(find.text('Sync with Song'), findsNothing);
    });

    testWidgets('Track change cleanly resets active state and loads new lyrics', (tester) async {
      final secondSong = Song(
        id: 'test_song_autoscroll_2',
        title: 'Second Anthem',
        artist: 'Noctra Test Crew',
        album: 'Test Album 2',
        duration: const Duration(seconds: 200),
      );

      final secondLines = List.generate(
        10,
        (i) => LyricLine(
          timestamp: Duration(seconds: i * 5),
          text: 'Song 2 Line $i: Fresh lyrics',
        ),
      );

      LyricsService.setCacheForSong(
        secondSong,
        LyricsData(
          isSynced: true,
          lines: secondLines,
          plainText: secondLines.map((l) => l.text).join('\n'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 350,
                child: LyricsView(song: testSong),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Lyric Line 0:'), findsOneWidget);

      // Change to second song
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 350,
                child: LyricsView(song: secondSong),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Second song lyrics should be rendered, first song should not be present
      expect(find.textContaining('Song 2 Line 0: Fresh lyrics'), findsOneWidget);
      expect(find.textContaining('Lyric Line 0: Sing along'), findsNothing);
    });
  });
}
