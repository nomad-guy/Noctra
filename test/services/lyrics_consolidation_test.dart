import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyrics/lyrics_matcher.dart';
import 'package:noctra/services/lyrics/lyrics_service.dart';
import 'package:noctra/services/lyrics/universal_lyrics_transliteration_engine.dart';

void main() {
  group('Lyrics consolidation & translation parsing', () {
    test('merges Romanized line and English translation sharing timestamp', () {
      const lrc = '''
[00:19.03] Saamne se nikla mere chaand yeh abhi
[00:19.03] My moon (beloved) just passed right in front of me
[00:22.86] Poora ho gaya ho jaise khwaab yeh koi
[00:22.86] As if some dream of mine came true
''';

      final lines = LyricsMatcher.parseLrc(lrc);
      expect(lines.length, equals(2));

      expect(lines[0].timestamp, equals(const Duration(seconds: 19, milliseconds: 30)));
      expect(lines[0].text, equals('Saamne se nikla mere chaand yeh abhi'));
      expect(lines[0].translation, equals('My moon (beloved) just passed right in front of me'));

      expect(lines[1].timestamp, equals(const Duration(seconds: 22, milliseconds: 860)));
      expect(lines[1].text, equals('Poora ho gaya ho jaise khwaab yeh koi'));
      expect(lines[1].translation, equals('As if some dream of mine came true'));
    });

    test('merges lines within 150ms delta', () {
      const lrc = '''
[00:10.00] Yeh raatein yeh mausam
[00:10.10] These nights, this weather
''';

      final lines = LyricsMatcher.parseLrc(lrc);
      expect(lines.length, equals(1));
      expect(lines[0].text, equals('Yeh raatein yeh mausam'));
      expect(lines[0].translation, equals('These nights, this weather'));
    });

    test('deduplicates exact repeated lines at same timestamp', () {
      const lrc = '''
[00:05.00] Dum da ra ra
[00:05.00] Dum da ra ra
''';

      final lines = LyricsMatcher.parseLrc(lrc);
      expect(lines.length, equals(1));
      expect(lines[0].text, equals('Dum da ra ra'));
      expect(lines[0].translation, isNull);
    });

    test('prioritizes native script as main text over Latin translation', () {
      const lrc = '''
[00:15.00] In the dark of the night
[00:15.00] अंधेरी रात में
''';

      final lines = LyricsMatcher.parseLrc(lrc);
      expect(lines.length, equals(1));
      expect(lines[0].text, equals('अंधेरी रात में'));
      expect(lines[0].translation, equals('In the dark of the night'));
    });

    test('transliteration engine preserves translation field intact', () {
      final originalLines = [
        const LyricLine(
          timestamp: Duration(seconds: 10),
          text: 'namaste',
          translation: 'hello',
        ),
      ];
      final lyricsData = LyricsData(
        isSynced: true,
        lines: originalLines,
        plainText: 'namaste',
      );

      final converted = UniversalLyricsTransliterationEngine.transliterateLyrics(
        lyricsData,
        'devanagari',
      );

      expect(converted.lines.first.text, isNot(equals('namaste')));
      expect(converted.lines.first.translation, equals('hello'));
    });
  });
}
