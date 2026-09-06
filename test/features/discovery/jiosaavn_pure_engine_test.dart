import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/discovery/infrastructure/jiosaavn_pure_engine.dart';

void main() {
  group('JioSaavnPureEngine', () {
    test('sanitizeText strips noise tags and punctuation', () {
      expect(
        JioSaavnPureEngine.sanitizeText('Starboy (Official Music Video) [Audio]'),
        equals('Starboy'),
      );
      expect(
        JioSaavnPureEngine.sanitizeText('Song Name - Topic (Slowed + Reverb)'),
        equals('Song Name'),
      );
    });

    test('isMatch evaluates song title and artist correctly', () {
      expect(
        JioSaavnPureEngine.isMatch('Blinding Lights', 'The Weeknd', 'Blinding Lights', 'The Weeknd'),
        isTrue,
      );

      // Rejects remix if user asked for original
      expect(
        JioSaavnPureEngine.isMatch('Blinding Lights', 'The Weeknd', 'Blinding Lights (Remix)', 'The Weeknd'),
        isFalse,
      );

      // Matches remix if user explicitly asked for remix
      expect(
        JioSaavnPureEngine.isMatch('Blinding Lights (Remix)', 'The Weeknd', 'Blinding Lights Remix', 'The Weeknd'),
        isTrue,
      );
    });

    test('parseSongItem extracts clean metadata and upgrades thumbnail to 500x500', () {
      final raw = {
        'id': '12345',
        'title': 'Test Song &amp; Track',
        'subtitle': 'Test Artist',
        'image': 'http://c.saavncdn.com/123/track-150x150.jpg',
        'more_info': {
          'album': 'Test Album',
          'duration': '215',
          'encrypted_media_url': '',
        },
      };

      final parsed = JioSaavnPureEngine.parseSongItem(raw);
      expect(parsed, isNotNull);
      expect(parsed!['title'], equals('Test Song & Track'));
      expect(parsed['artist'], equals('Test Artist'));
      expect(parsed['album'], equals('Test Album'));
      expect(parsed['thumbnail'], equals('https://c.saavncdn.com/123/track-500x500.jpg'));
      expect(parsed['duration'], equals(215));
    });

    test('decryptMediaUrl returns null on invalid input', () {
      expect(JioSaavnPureEngine.decryptMediaUrl(null), isNull);
      expect(JioSaavnPureEngine.decryptMediaUrl(''), isNull);
      expect(JioSaavnPureEngine.decryptMediaUrl('invalid_base64!'), isNull);
    });
  });
}
