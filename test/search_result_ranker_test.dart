import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/ytdlp/search_result_ranker.dart';

Song s(String id, String title, String artist) => Song(
      id: id,
      title: title,
      artist: artist,
      album: 'x',
      streamUrl: null,
      duration: const Duration(seconds: 180),
    );

void main() {
  group('score / ordering', () {
    test('exact-title Pakistani OST beats fuzzy Bollywood lookalike', () {
      // The on-device failure: "Kahin Deep Jalay" returned the Hemant
      // Kumar classic first and buried the real OST far below.
      final exact = s('i1', 'Kahin Deep Jalay (Original Score)',
          'Sahir Ali Bagga');
      final old = s('i2', 'Kahin Deep Jale Kahin Dil', 'Hemant Kumar');
      final ranked = SearchResultRanker.mergeAndRank(
          [[old], [exact]], 'Kahin Deep Jalay');
      expect(ranked.first.title, 'Kahin Deep Jalay (Original Score)');
      expect(SearchResultRanker.score('Kahin Deep Jalay', exact.title,
              exact.artist),
          greaterThan(SearchResultRanker.score(
              'Kahin Deep Jalay', old.title, old.artist)));
    });

    test('plain query demotes slowed/reverb/remix editions', () {
      final plain = s('p1', 'Khuda Aur Mohabbat', 'Rahat Fateh Ali Khan');
      final remixed = s('p2', 'Khuda Aur Mohabbat (Slowed + Reverb)',
          'Anku Malik');
      final ranked = SearchResultRanker.mergeAndRank(
          [[remixed], [plain]], 'Khuda Aur Mohabbat');
      expect(ranked.first.title, 'Khuda Aur Mohabbat');
      expect(SearchResultRanker.score('Khuda Aur Mohabbat', plain.title,
              plain.artist),
          greaterThan(SearchResultRanker.score(
              'Khuda Aur Mohabbat', remixed.title, remixed.artist)));
    });

    test('query asking for a remix keeps the remix on top', () {
      final plain = s('r1', 'Jhoom', 'Ali Zafar');
      final remixed = s('r2', 'Jhoom (R&B Mix)', 'Ali Zafar');
      final ranked = SearchResultRanker.mergeAndRank(
          [[plain], [remixed]], 'Jhoom r&b mix');
      expect(ranked.first.title, 'Jhoom (R&B Mix)');
    });

    test('exact full-title equality ranks first', () {
      final exact = s('e1', 'Ruposh', 'RukhSara');
      final feat = s('e2', 'Ruposh (feat. its_devilrony)', 'Anku Malik');
      expect(SearchResultRanker.score('ruposh', exact.title, exact.artist),
          1.0);
      final ranked = SearchResultRanker.mergeAndRank(
          [[feat], [exact]], 'ruposh');
      expect(ranked.first.title, 'Ruposh');
    });

    test('case and punctuation do not affect ranking', () {
      final a = s('c1', 'Ruposh (Acoustic)', 'Wajhi Farooki');
      final b = s('c2', 'Ruposh', 'Wajhi Farooki');
      final ranked = SearchResultRanker.mergeAndRank([[a], [b]], '  RUPOSH! ');
      expect(ranked.first.title, 'Ruposh');
    });
  });

  group('merge determinism', () {
    test('dedupe keeps the earlier-bucket copy (no arrival bias)', () {
      // Same logical track from two providers collapses to one row; which
      // copy survives is decided by bucket priority, never by network
      // arrival order.
      final saavn = s('saavn_x', 'Awargi', 'Sangeet Haldipur');
      final itunes = s('itunes_y', 'Awargi', 'Sangeet Haldipur');
      final a = SearchResultRanker.mergeAndRank(
          [[saavn], [itunes]], 'Awargi');
      final b = SearchResultRanker.mergeAndRank(
          [[itunes], [saavn]], 'Awargi');
      expect(a.single.id, 'saavn_x');
      expect(b.single.id, 'itunes_y');
      // Production always passes buckets in fixed priority order, so the
      // full pipeline is deterministic for a given query.
      final c = SearchResultRanker.mergeAndRank(
          [[saavn], [itunes]], 'Awargi');
      expect(a.map((x) => x.id).toList(), c.map((x) => x.id).toList());
    });

    test('identical input always yields identical ranking', () {
      final rows = [
        s('d1', 'Zindagi', 'Atif Aslam'),
        s('d2', 'Zindagi Awargi Hai Jhoom (Original Score)', 'Wajhi Farooki'),
        s('d3', 'Zindagi (feat. Macy Kate)', 'Sanjoy'),
        s('d4', 'Zindagi', 'Gill Hardeep'),
      ];
      final first = SearchResultRanker.mergeAndRank([rows], 'Zindagi');
      final second = SearchResultRanker.mergeAndRank([rows], 'Zindagi');
      expect(first.map((x) => x.id).toList(),
          second.map((x) => x.id).toList());
      // The OST variant must surface in the top band, not buried at the
      // bottom behind remixes (two exact-title classics may legitimately
      // precede it for an ambiguous one-word query).
      final titles = first.map((x) => x.title).toList();
      expect(titles.indexOf('Zindagi Awargi Hai Jhoom (Original Score)'),
          inInclusiveRange(0, 2));
      expect(titles.indexOf('Zindagi (feat. Macy Kate)'), greaterThan(2));
    });

    test('same strong video id from two providers dedupes once', () {
      final yt = s('ABCDEFGHIJK', 'Mere Hamsafar', 'Aima Baig');
      final ytDup = s('ABCDEFGHIJK', 'Mere Hamsafar', 'Aima Baig');
      final ranked = SearchResultRanker.mergeAndRank(
          [[yt], [ytDup]], 'Mere Hamsafar');
      expect(ranked.length, 1);
    });

    test('weak ids (lrc_/itunes_) dedupe by title+artist, not id', () {
      final lrc = s('lrc_1', 'Jhoom', 'Ali Zafar');
      final lrcSame = s('lrc_2', 'Jhoom', 'Ali Zafar');
      final ranked =
          SearchResultRanker.mergeAndRank([[lrc], [lrcSame]], 'Jhoom');
      expect(ranked.length, 1);
    });

    test('zero-overlap noise is dropped (no trending substitution)', () {
      expect(SearchResultRanker.mergeAndRank(
              [
                [s('x1', 'zzzqqq', 'nobody')]
              ],
              'Completely Unrelated Song'),
          isEmpty);
      // ...but a genuine partial overlap survives.
      final ranked = SearchResultRanker.mergeAndRank(
          [
            [s('x2', 'Kahin Deep Jalay (Original Score)', 'Sahir Ali Bagga')]
          ],
          'Completely Unrelated Song Kahin');
      expect(ranked, isNotEmpty);
    });
  });

  group('artist profile ordering', () {
    test('own recordings lead; feat./lyrics rows follow; junk drops', () {
      // Real-world shape for a niche indie artist: the artist's own song
      // mentions the name only in ARTIST position, while re-uploads and a
      // feature row echo it in their TITLES.
      final own = s('g1', 'Sophisticated Space', 'Sidney Gish');
      final own2 = s('g2', 'MFSOTSOTR', 'Sidney Gish');
      final feat = s('g3', 'Oh My (feat. Sidney Gish)', 'Camino 84');
      final lyrics =
          s('g4', 'Sidney Gish - Impostor Syndrome (Lyrics)', 'Sky Night');
      final slowed = s('g5', 'Impostor Syndrome (Best Part Slowed)',
          'unshackled');
      final ordered = SearchResultRanker.orderForArtistProfile(
          [feat, slowed, lyrics, own, own2], 'Sidney Gish');
      final titles = ordered.map((x) => x.title).toList();
      expect(titles.take(2).toSet(),
          {'Sophisticated Space', 'MFSOTSOTR'});
      expect(titles.indexOf('Oh My (feat. Sidney Gish)'),
          greaterThan(1));
      expect(titles, isNot(contains('Impostor Syndrome (Best Part Slowed)')));
    });

    test('duo artist rows stay when their artist covers the name', () {
      final duo = s('h1', 'Islands In the Stream',
          'Dolly Parton, Kenny Rogers');
      final other = s('h2', 'Islands In the Stream', 'Kenny Rogers');
      final junk = s('h3', 'Dolly Parton Interview 2024', 'Podcast');
      final ordered = SearchResultRanker.orderForArtistProfile(
          [junk, other, duo], 'Dolly Parton & Kenny Rogers');
      // The row whose artist IS the full duo leads; the solo half and the
      // interview clip only mention the name and follow behind it.
      expect(ordered.first.id, 'h1');
      expect(ordered, hasLength(3));
    });

    test('single-token artist name leads exact artist rows', () {
      final topic = s('w1', 'Blinding Lights', 'The Weeknd - Topic');
      final other = s('w2', 'Blinding Lights Remix', 'Other Artist');
      final ordered = SearchResultRanker.orderForArtistProfile(
          [other, topic], 'The Weeknd');
      expect(ordered.first.id, 'w1');
    });

    test('nothing related falls back to the full input (never empty)', () {
      final rows = [s('n1', 'Mystery Row', 'Some Artist')];
      expect(SearchResultRanker.orderForArtistProfile(rows, 'Nobody Known'),
          hasLength(1));
    });
  });

  group('normalization', () {
    test('keeps unicode letters (Devanagari/Roman-Urdu queries intact)', () {
      expect(SearchResultRanker.score('रुपोश', 'रुपोश', ''), 1.0);
      final roman = s('u1', 'Ruposh', 'Wajhi Farooki');
      final ranked = SearchResultRanker.mergeAndRank(
          [[s('u2', 'Ruposh (Female Version)', 'RukhSara')], [roman]],
          'ruposh');
      expect(ranked.first.title, 'Ruposh');
    });
  });
}
