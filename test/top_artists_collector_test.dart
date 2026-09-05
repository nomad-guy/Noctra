import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/ui/widgets/top_artists_carousel.dart';

/// Phase 22 regression tests for the Explore Artists carousel.
///
/// Background: the carousel collected artists only from onboarding, top
/// history and the live Deezer/Spotify feeds. When the feeds were slow or
/// unreachable (regular on weak networks), the row shrank to almost nothing
/// even though the user's own library and recently-played tracks contained
/// plenty of artists. The collector now folds in local library + recently
/// played artists (offline-safe) before the network feeds.
Song _song(String id, String title, String artist) => Song(
      id: id,
      title: title,
      artist: artist,
      duration: const Duration(seconds: 180),
    );

void main() {
  test('local library artists appear even when both feeds fail (offline)', () {
    final names = TopArtistsCarousel.collectArtistNames(
      localSongs: [
        _song('1', 'Song A', 'Local Artist One'),
        _song('2', 'Song B', 'Local Artist Two'),
      ],
      recentSongs: [_song('3', 'Song C', 'Recently Played Artist')],
      // Network feeds empty/failed → must not wipe the local artists.
      trendingSongs: const [],
      chartSongs: const [],
    );
    expect(names, containsAll(['Local Artist One', 'Local Artist Two']));
    expect(names, contains('Recently Played Artist'));
  });

  test('deduplicates the same artist across all sources', () {
    final names = TopArtistsCarousel.collectArtistNames(
      onboarded: const ['One Direction'],
      topHistory: const ['one direction'],
      localSongs: [_song('1', 'A', 'one direction')],
      recentSongs: [_song('2', 'B', 'ONE DIRECTION')],
      trendingSongs: [_song('3', 'C', 'one direction')],
    );
    expect(
        names.where((n) => n.toLowerCase() == 'one direction'), hasLength(1));
  });

  test('empty everything resolves to empty (no crash, no placeholder junk)',
      () {
    expect(TopArtistsCarousel.collectArtistNames(), isEmpty);
  });

  test('onboarded artists rank before network-feed artists', () {
    final names = TopArtistsCarousel.collectArtistNames(
      onboarded: const ['Onboarded Star'],
      trendingSongs: [_song('1', 'A', 'Trending Star')],
    );
    expect(names.first, 'Onboarded Star');
  });

  test('respects the limit deterministically', () {
    final names = TopArtistsCarousel.collectArtistNames(
      localSongs: [
        for (var i = 0; i < 10; i++) _song('$i', 'T$i', 'Artist $i'),
      ],
      limit: 3,
    );
    expect(names, hasLength(3));
  });
}
