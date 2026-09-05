import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyrics/lyrics_service.dart';

void main() {
  group('LyricsService title matching', () {
    test('exact match', () {
      expect(LyricsService.titlesMatchForTest('Tum Hi Ho', 'Tum Hi Ho'), true);
    });

    test('case insensitive', () {
      expect(LyricsService.titlesMatchForTest('tum hi ho', 'Tum Hi Ho'), true);
    });

    test('with punctuation differences', () {
      expect(LyricsService.titlesMatchForTest('Tum Hi Ho', 'Tum-Hi-Ho'), true);
    });

    test('Levenshtein near-match', () {
      expect(LyricsService.titlesMatchForTest('Tum Hi Ho', 'Tum Hi Hao'), true);
    });

    test('different songs should not match', () {
      expect(LyricsService.titlesMatchForTest('Tum Hi Ho', 'Agar Tum Saath Ho'),
          false);
    });

    test('short substring should NOT match (bug fix)', () {
      // "Noor" should NOT match "Noor-e-Jahan" because "Noor" is < 5 chars
      expect(LyricsService.titlesMatchForTest('Noor', 'Noor-e-Jahan'), false);
    });

    test('long substring should match', () {
      expect(
          LyricsService.titlesMatchForTest('Tum Hi Ho', 'Tum Hi Ho Acoustic'),
          true);
      expect(
          LyricsService.titlesMatchForTest(
              'Shape of You', 'Shape of You (Remix)'),
          true);
    });

    test('empty strings', () {
      expect(LyricsService.titlesMatchForTest('', 'Tum Hi Ho'), false);
      expect(LyricsService.titlesMatchForTest('Tum Hi Ho', ''), false);
    });

    test('Hindi/Devanagari titles', () {
      expect(LyricsService.titlesMatchForTest('दिल से', 'दिल से'), true);
    });
  });

  group('LyricsService validation', () {
    test('valid lyrics pass validation', () {
      final data = LyricsData(
        isSynced: true,
        lines: [
          LyricLine(timestamp: Duration.zero, text: 'Tum hi ho'),
          LyricLine(timestamp: Duration(seconds: 3), text: 'Ab tum hi ho'),
        ],
        plainText: 'Tum hi ho\nAb tum hi ho',
      );
      expect(data.lines.length, 2);
      expect(data.isSynced, true);
    });

    test('empty lyrics data', () {
      final data = LyricsData.empty();
      expect(data.isSynced, false);
      expect(data.lines.isEmpty, true);
    });
  });

  group('LyricsService script selection', () {
    test('does not classify Gurmukhi lyrics as Latin', () {
      expect(LyricsService.hasNonLatinScriptForTest('ਸਾਰੇ ਰੰਗ'), isTrue);
      expect(LyricsService.hasNonLatinScriptForTest('Shape of You'), isFalse);
    });
  });

  group('LyricsService LRC parsing', () {
    test('parses standard LRC format', () {
      final lrc =
          '[00:00.00] Tum hi ho\n[00:03.50] Ab tum hi ho\n[00:07.00] Bas tum hi ho';
      final lines = LyricsService.parseLrcForTest(lrc);
      expect(lines.length, 3);
      expect(lines[0].text, 'Tum hi ho');
      expect(lines[0].timestamp, Duration.zero);
      expect(lines[1].text, 'Ab tum hi ho');
      expect(lines[1].timestamp, Duration(milliseconds: 3500));
      expect(lines[2].text, 'Bas tum hi ho');
      expect(lines[2].timestamp, Duration(seconds: 7));
    });

    test('skips empty lines', () {
      final lrc = '[00:00.00] Tum hi ho\n\n[00:03.50] Ab tum hi ho\n';
      final lines = LyricsService.parseLrcForTest(lrc);
      expect(lines.length, 2);
    });

    test('sorts by timestamp', () {
      final lrc = '[00:03.50] Second\n[00:00.00] First';
      final lines = LyricsService.parseLrcForTest(lrc);
      expect(lines[0].text, 'First');
      expect(lines[1].text, 'Second');
    });

    test('handles milliseconds (3 digits)', () {
      final lrc = '[01:23.456] Test line';
      final lines = LyricsService.parseLrcForTest(lrc);
      expect(lines.length, 1);
      expect(lines[0].timestamp,
          Duration(minutes: 1, seconds: 23, milliseconds: 456));
    });
  });

  group('LyricsService sanitization', () {
    test('removes parentheses content', () {
      final result =
          LyricsService.sanitizeTitleForTest('Tum Hi Ho (Official Video)');
      expect(result, 'Tum Hi Ho');
    });

    test('removes feat artists', () {
      final result =
          LyricsService.sanitizeTitleForTest('Song Title feat. Someone');
      expect(result, 'Song Title');
    });

    test('removes YouTube suffixes', () {
      final result = LyricsService.sanitizeTitleForTest(
          'Song Title - Official Music Video');
      expect(result, 'Song Title');
    });

    test('preserves Hindi titles', () {
      final result = LyricsService.sanitizeTitleForTest('तुम ही हो');
      expect(result, 'तुम ही हो');
    });
  });
}
