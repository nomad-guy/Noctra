import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/metadata/artist_metadata_normalizer.dart';

void main() {
  group('ArtistMetadataNormalizer', () {
    test('keeps punctuation in a legacy artist identity', () {
      expect(ArtistMetadataNormalizer.fromLegacyText('Earth, Wind & Fire'),
          'Earth, Wind & Fire');
      expect(ArtistMetadataNormalizer.fromLegacyText('AC/DC'), 'AC/DC');
    });

    test('removes trailing YouTube metadata without splitting an artist', () {
      expect(
          ArtistMetadataNormalizer.fromLegacyText(
              'Simon & Garfunkel • Sounds of Silence • 3:05'),
          'Simon & Garfunkel');
    });

    test('prefers structured YouTube artist runs over subtitle metadata', () {
      final artist = ArtistMetadataNormalizer.fromYouTubeRuns([
        {
          'text': 'Artist A',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UC_artist_a'}
          },
        },
        {'text': ' • '},
        {
          'text': 'Artist B',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UC_artist_b'}
          },
        },
        {'text': ' • Album • 3:00'},
      ]);
      expect(artist, 'Artist A, Artist B');
    });

    test('normalizes casing and whitespace only for identity comparisons', () {
      expect(ArtistMetadataNormalizer.identityKey(' Arijit   Singh '),
          'arijit singh');
    });
  });
}
