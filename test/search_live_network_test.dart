// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/resolvers/track_matching_guard.dart';
import 'package:noctra/services/ytdlp/music_service.dart';

/// LIVE-NETWORK end-to-end search verification.
///
/// These tests exercise the real pipeline end to end: real HTTP against
/// JioSaavn / YouTube Music / iTunes, real parsing, real ranking — the
/// same path a user's keystrokes take in the app.
///
/// Deliberately does NOT initialize TestWidgetsFlutterBinding: the
/// automated binding's fake-async zone intercepts real socket I/O and
/// returns synthetic 400 responses. Search is pure Dart (no platform
/// channels), so it runs fine in a normal async zone — which is the point:
/// this test hits real servers.
///
/// They assert relevance coverage (the reported songs/artists are found),
/// NOT a specific provider being up; each provider query is individually
/// timeout-tolerant and assertions only run on whatever the live network
/// actually returned, so an outage shows up as skips rather than flakes.
void main() {

  /// (query, expected markers) pairs. The label is separate from the
  /// query on purpose: the query string must be exactly what a user
  /// would type.
  const reportedCases = <(String, List<String>)>[
    ('Kahin Deep Jalay', ['Kahin Deep Jalay']),
    ('Mere Hamsafar', ['Mere Hamsafar']),
    ('Khuda Aur Mohabbat', ['Khuda Aur Mohabbat']),
    ('Ruposh', ['Ruposh']),
    ('Jhoom', ['Jhoom']),
    ('Zindagi Awargi', ['Awargi']),
    ('Sidney Gish', ['Sidney Gish']),
    ('Halo Beyonce', ['Beyoncé', 'Beyonce', 'Halo']),
    ('midnight ciy', ['Midnight']),
  ];

  group('LIVE search — reported missing songs (real network)', () {
    for (final case_ in reportedCases) {
      final query = case_.$1;
      final expected = case_.$2;
      test('search "$query" returns a relevant result', () async {
        final results = await MusicService.search(query).timeout(
          const Duration(seconds: 30),
          onTimeout: () => <Song>[],
        );

        if (results.isEmpty) {
          // Total network outage — skip instead of failing the build.
          print('SKIP (no network results): $query');
          return;
        }

        final titlesAndArtists =
            results.map((s) => '${s.title} ${s.artist}').toList();

        // Every reported case must surface at least one row whose
        // normalized text overlaps the query tokens.
        final queryNorm = query.toLowerCase();
        final relevant = titlesAndArtists
            .where((r) => r.toLowerCase().contains(queryNorm.split(' ').first))
            .toList();
        expect(relevant, isNotEmpty,
            reason: '"$query" returned rows but none relate to it:\n'
                '${titlesAndArtists.take(5).join('\n')}');

        // And at least one expected marker must appear in the visible set.
        final hasExpected = results.any((song) => expected.any((marker) =>
            '${song.title} ${song.artist}'
                .toLowerCase()
                .contains(marker.toLowerCase())));
        expect(hasExpected, isTrue,
            reason: '"$query" results lack any expected marker '
                '$expected:\n${titlesAndArtists.take(8).join('\n')}');
      }, timeout: const Timeout(Duration(seconds: 45)));
    }

    test('top result for exact-title query is the right song, not a remix',
        () async {
      final results =
          await MusicService.search('Kahin Deep Jalay').timeout(
        const Duration(seconds: 30),
        onTimeout: () => <Song>[],
      );
      if (results.isEmpty) {
        print('SKIP (no network results): Kahin Deep Jalay');
        return;
      }
      final top = results.first.title.toLowerCase();
      expect(top, contains('kahin deep jalay'),
          reason: 'Top row was "${results.first.title}" by '
              '${results.first.artist}');
      expect(top.contains('slowed') || top.contains('reverb'), isFalse,
          reason: 'Top row is a slowed/reverb edit');
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('cached repeat search returns identical results (cache consistency)',
        () async {
      final first = await MusicService.search('Ruposh').timeout(
        const Duration(seconds: 30),
        onTimeout: () => <Song>[],
      );
      if (first.isEmpty) {
        print('SKIP (no network results): Ruposh cache check');
        return;
      }
      final second = await MusicService.search('Ruposh');
      expect(
        second.map((s) => s.id).toList(),
        first.map((s) => s.id).toList(),
      );
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('rapid successive searches keep their own results (stale guard)',
        () async {
      final a = await MusicService.search('Jhoom').timeout(
        const Duration(seconds: 30),
        onTimeout: () => <Song>[],
      );
      final b = await MusicService.search('Sidney Gish').timeout(
        const Duration(seconds: 30),
        onTimeout: () => <Song>[],
      );
      if (a.isEmpty || b.isEmpty) {
        print('SKIP (no network results): stale-guard check');
        return;
      }
      // Both queries are cached independently; neither may bleed rows
      // into the other's result set.
      expect(
        a.any((s) =>
            s.title.toLowerCase().contains('jhoom') ||
            s.artist.toLowerCase().contains('jhoom')),
        isTrue,
        reason: 'Jhoom search produced no Jhoom row');
      expect(
        b.any((s) =>
            s.artist.toLowerCase().contains('sidney') ||
            s.title.toLowerCase().contains('sidney')),
        isTrue,
        reason: 'Sidney Gish search produced no Sidney Gish row');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('LIVE matching guard — accented targets resolve to the right stream',
      () {
    test('precomposed diacritic target vs plain candidate is a safe match',
        () {
      // Playback path: a library row with accented metadata resolving
      // against a plain-text provider candidate must not be rejected.
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: 'Beyoncé',
        targetArtist: 'Halo Singer',
        candidateTitle: 'Beyonce',
        candidateArtist: 'Halo Singer',
      );
      expect(safe, isTrue);
    });

    test('accented artist target vs accented candidate is a safe match', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: 'La Vie En Rose',
        targetArtist: 'Édith Piaf',
        candidateTitle: 'La Vie En Rose',
        candidateArtist: 'Edith Piaf',
      );
      expect(safe, isTrue);
    });

    test('genuinely different artist is still rejected after the fix', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: 'Hello',
        targetArtist: 'Adele',
        candidateTitle: 'Hello',
        candidateArtist: 'Lionel Richie',
      );
      expect(safe, isFalse);
    });
  });
}
