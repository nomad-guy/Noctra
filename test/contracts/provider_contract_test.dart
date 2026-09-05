import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/discovery/domain/music_provider_contract.dart';
import 'package:noctra/features/discovery/infrastructure/fake_music_provider.dart';

void main() {
  group('MusicProviderContract Substitution Tests', () {
    late MusicProviderContract provider;

    setUp(() {
      provider = FakeMusicProvider();
    });

    test('can swap provider and execute searches reliably', () async {
      expect(provider.providerId, equals('fake_provider'));

      final results = await provider.search('Midnight');
      expect(results, isNotEmpty);
      expect(results.first.title, contains('Midnight'));
      expect(results.first.artist, equals('Noir Syndicate'));
    });

    test('retrieves artist top tracks without network dependencies', () async {
      final tracks = await provider.getArtistTopTracks('Noir Syndicate');
      expect(tracks.length, equals(2));
      for (final t in tracks) {
        expect(t.artist, equals('Noir Syndicate'));
      }
    });

    test('returns exact track details by id', () async {
      final track = await provider.getTrackDetails('fake_1');
      expect(track, isNotNull);
      expect(track!.title, equals('Midnight Echo'));
      expect(track.duration, equals(const Duration(seconds: 210)));

      final missing = await provider.getTrackDetails('unknown_999');
      expect(missing, isNull);
    });

    test('retrieves trending songs', () async {
      final trending = await provider.getTrending(limit: 2);
      expect(trending.length, equals(2));
      expect(trending.first.id, equals('fake_1'));
    });
  });
}
