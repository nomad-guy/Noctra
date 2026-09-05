import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/ai/ai_mix_track_source.dart';

/// Phase 22 regression tests for AI-generated libraries ("AI Mixes" and
/// "AI Folders").
///
/// Background: tapping an AI library resolved tracks purely from its vibe
/// key — "Favorites"/"Downloads" folders ignored the user's actual
/// favorites/downloads and ran an 8s network vibe-feed search (wrong content
/// online, silent no-op offline), and mixes without locally curated tracks
/// did an 8s network wait that could end in a silent dead tap.
Song _song(String id, String title) => Song(
      id: id,
      title: title,
      artist: 'Artist',
      duration: const Duration(seconds: 180),
    );

void main() {
  group('AiMixTrackSource favorites/downloads', () {
    test('favorites resolves the local favorites list, no network call', () async {
      var networkTouched = false;
      final result = await AiMixTrackSource.resolveFrom(
        favorites: [_song('f1', 'Fav One'), _song('f2', 'Fav Two')],
        downloads: [_song('d1', 'DL One')],
        localCurator: (_) => <Song>[],
        vibeKey: 'favorites',
        feedFetcher: (_) async {
          networkTouched = true;
          return <Song>[];
        },
      );
      expect(networkTouched, isFalse,
          reason: 'Favorites must never touch the network');
      expect(result.map((s) => s.id), ['f1', 'f2']);
    });

    test('downloads resolves the local downloads list, no network call', () async {
      var networkTouched = false;
      final result = await AiMixTrackSource.resolveFrom(
        favorites: <Song>[],
        downloads: [_song('d1', 'DL One'), _song('d2', 'DL Two')],
        localCurator: (_) => <Song>[],
        vibeKey: 'downloads',
        feedFetcher: (_) async {
          networkTouched = true;
          return <Song>[];
        },
      );
      expect(networkTouched, isFalse,
          reason: 'Downloads must never touch the network');
      expect(result.map((s) => s.id), ['d1', 'd2']);
    });
  });

  group('AiMixTrackSource remix ordering', () {
    test('different epochs produce different orders (deterministic per epoch)',
        () {
      final pool = [
        _song('a', 'A'),
        _song('b', 'B'),
        _song('c', 'C'),
        _song('d', 'D'),
        _song('e', 'E'),
        _song('f', 'F'),
      ];
      final first = AiMixTrackSource.applyRemixOrder(pool,
          epoch: 0, vibeKey: 'late_night');
      final second = AiMixTrackSource.applyRemixOrder(pool,
          epoch: 1, vibeKey: 'late_night');
      expect(first.map((s) => s.id).toSet(), pool.map((s) => s.id).toSet(),
          reason: 'remix keeps the full pool');
      expect(first.map((s) => s.id), isNot(second.map((s) => s.id)),
          reason: 'a new epoch must change the arrangement');
    });

    test('same epoch + same inputs is fully reproducible', () {
      final pool = [
        _song('a', 'A'),
        _song('b', 'B'),
        _song('c', 'C'),
        _song('d', 'D'),
      ];
      final a = AiMixTrackSource.applyRemixOrder(pool,
          previousIds: const ['b'], epoch: 3, vibeKey: 'deep_focus');
      final b = AiMixTrackSource.applyRemixOrder(pool,
          previousIds: const ['b'], epoch: 3, vibeKey: 'deep_focus');
      expect(a.map((s) => s.id), b.map((s) => s.id));
    });

    test('tracks from the previous arrangement are not repeated up front', () {
      final pool = [
        _song('a', 'A'),
        _song('b', 'B'),
        _song('c', 'C'),
        _song('d', 'D'),
        _song('e', 'E'),
      ];
      final ids = AiMixTrackSource.applyRemixOrder(pool,
              previousIds: const ['a', 'b'], epoch: 5, vibeKey: 'retro_synth')
          .map((s) => s.id)
          .toList();
      expect(ids.sublist(0, 3),
          isNot(contains(anyOf('a', 'b'))),
          reason: 'fresh (not-previously-played) tracks must lead the remix');
      expect(ids, containsAll(['a', 'b', 'c', 'd', 'e']),
          reason: 'nothing is dropped');
    });

    test('degenerate pools are returned safely', () {
      expect(AiMixTrackSource.applyRemixOrder(const [], epoch: 0), isEmpty);
      final single = [_song('x', 'X')];
      expect(
          AiMixTrackSource.applyRemixOrder(single, epoch: 0)
              .map((s) => s.id),
          ['x']);
    });
  });

  group('AiMixTrackSource network vibes', () {
    test('uses the network feed when the local library has nothing', () async {
      final result = await AiMixTrackSource.resolveFrom(
        favorites: <Song>[],
        downloads: <Song>[],
        localCurator: (_) => <Song>[],
        vibeKey: 'late_night',
        feedFetcher: (_) async => [_song('net1', 'Feed Track')],
      );
      expect(result.map((s) => s.id), ['net1']);
    });

    test('local curation wins and the network is never consulted when the '
        'library already matches (instant, offline-safe open)', () async {
      var networkTouched = false;
      final result = await AiMixTrackSource.resolveFrom(
        favorites: <Song>[],
        downloads: <Song>[],
        localCurator: (_) => [_song('local', 'Local Curation')],
        vibeKey: 'late_night',
        feedFetcher: (_) async {
          networkTouched = true;
          return [_song('net1', 'Feed Track')];
        },
      );
      expect(networkTouched, isFalse,
          reason: 'an open must never wait on the network when local '
              'curation already produced tracks');
      expect(result.map((s) => s.id), ['local']);
    });

    test('falls back to local curation when the feed fails (offline)', () async {
      final result = await AiMixTrackSource.resolveFrom(
        favorites: <Song>[],
        downloads: <Song>[],
        localCurator: (_) => [_song('local', 'Local Curation')],
        vibeKey: 'deep_focus',
        feedFetcher: (_) async => throw Exception('offline'),
      );
      expect(result.map((s) => s.id), ['local']);
    });

    test('falls back to local curation when the feed times out', () async {
      final result = await AiMixTrackSource.resolveFrom(
        favorites: <Song>[],
        downloads: <Song>[],
        localCurator: (_) => [_song('local', 'Local Curation')],
        vibeKey: 'high_energy',
        feedFetcher: (_) => Future<List<Song>>.delayed(
            const Duration(seconds: 30), () => <Song>[]),
      );
      // The bounded feedTimeout (6s) must not make the caller wait forever.
      expect(result.map((s) => s.id), ['local']);
    });

    test('empty feed and empty library resolve to empty (no crash, no hang)',
        () async {
      final result = await AiMixTrackSource.resolveFrom(
        favorites: <Song>[],
        downloads: <Song>[],
        localCurator: (_) => <Song>[],
        vibeKey: 'retro_synth',
        feedFetcher: (_) async => <Song>[],
      );
      expect(result, isEmpty);
    });
  });
}
