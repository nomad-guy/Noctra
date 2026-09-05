import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/assistant/domain/stable_media_id.dart';

void main() {
  group('StableMediaId', () {
    test('parses root URI', () {
      final id = StableMediaId.parse(StableMediaId.rootId);
      expect(id, isNotNull);
      expect(id!.type, equals('root'));
      expect(id.value, isNull);
    });

    test('parses track URI with encoded special characters', () {
      final uri = StableMediaId.forTrack('track:123/xyz');
      final parsed = StableMediaId.parse(uri);
      expect(parsed, isNotNull);
      expect(parsed!.type, equals('track'));
      expect(parsed.value, equals('track:123/xyz'));
    });

    test('parses album and artist URIs', () {
      final artistUri = StableMediaId.forArtist('The Weeknd');
      final parsedArtist = StableMediaId.parse(artistUri);
      expect(parsedArtist?.type, equals('artist'));
      expect(parsedArtist?.value, equals('The Weeknd'));

      final albumUri = StableMediaId.forAlbum('After Hours');
      final parsedAlbum = StableMediaId.parse(albumUri);
      expect(parsedAlbum?.type, equals('album'));
      expect(parsedAlbum?.value, equals('After Hours'));
    });

    test('handles raw string fallback aliases', () {
      expect(StableMediaId.parse('favorites')?.type, equals('favorites'));
      expect(StableMediaId.parse('downloads')?.type, equals('downloads'));
      expect(StableMediaId.parse('recently_played')?.type, equals('recently_played'));
    });

    test('returns null for invalid URIs', () {
      expect(StableMediaId.parse(null), isNull);
      expect(StableMediaId.parse(''), isNull);
      expect(StableMediaId.parse('https://example.com'), isNull);
    });
  });
}
