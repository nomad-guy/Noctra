import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/song_similarity_deduplicator.dart';

void main() {
  Song makeSong({
    required String id,
    required String title,
    required String artist,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      duration: const Duration(seconds: 210),
    );
  }

  group('SongSimilarityDeduplicator', () {
    test('detects exact ID duplicates', () {
      final s1 = makeSong(id: '123', title: 'Song A', artist: 'Artist A');
      final s2 = makeSong(id: '123', title: 'Song Different', artist: 'Artist B');
      expect(SongSimilarityDeduplicator.areDuplicates(s1, s2), isTrue);
    });

    test('detects streaming platform noise variants with same artist', () {
      final s1 = makeSong(id: 'a1', title: 'Kesariya', artist: 'Arijit Singh');
      final s2 = makeSong(
        id: 'a2',
        title: 'Kesariya (From "Brahmastra") - Official Audio',
        artist: 'Arijit Singh, Pritam',
      );
      expect(SongSimilarityDeduplicator.areDuplicates(s1, s2), isTrue);
    });

    test('detects dash separator variants with same artist', () {
      final s1 = makeSong(id: 'b1', title: 'Apna Bana Le', artist: 'Arijit Singh, Sachin-Jigar');
      final s2 = makeSong(
        id: 'b2',
        title: 'Apna Bana Le - Bhediya | Varun Dhawan',
        artist: 'Sachin-Jigar feat. Arijit Singh',
      );
      expect(SongSimilarityDeduplicator.areDuplicates(s1, s2), isTrue);
    });

    test('does not conflate completely different songs by same artist', () {
      final s1 = makeSong(id: 'c1', title: 'Tum Hi Ho', artist: 'Arijit Singh');
      final s2 = makeSong(id: 'c2', title: 'Channa Mereya', artist: 'Arijit Singh');
      expect(SongSimilarityDeduplicator.areDuplicates(s1, s2), isFalse);
    });

    test('does not conflate same short generic title by different artists', () {
      final s1 = makeSong(id: 'd1', title: 'Hello', artist: 'Adele');
      final s2 = makeSong(id: 'd2', title: 'Hello', artist: 'Lionel Richie');
      expect(SongSimilarityDeduplicator.areDuplicates(s1, s2), isFalse);
    });

    test('does not conflate sequel or numbered parts by same artist', () {
      final s1 = makeSong(id: 'e1', title: 'Song Number 1', artist: 'Artist');
      final s2 = makeSong(id: 'e2', title: 'Song Number 2', artist: 'Artist');
      expect(SongSimilarityDeduplicator.areDuplicates(s1, s2), isFalse);

      final d1 = makeSong(id: 'f1', title: 'Dhoom Machale', artist: 'Pritam');
      final d2 = makeSong(id: 'f2', title: 'Dhoom Machale 2', artist: 'Pritam');
      expect(SongSimilarityDeduplicator.areDuplicates(d1, d2), isFalse);
    });

    test('stateful deduplicator filters intra-pool repeats and respects seed', () {
      final seed = makeSong(id: 'seed_1', title: 'Kesariya', artist: 'Arijit Singh');
      final dedup = SongSimilarityDeduplicator(seedSong: seed);

      final candidate1 = makeSong(id: 'c1', title: 'Kesariya (Official Video)', artist: 'Arijit Singh');
      final candidate2 = makeSong(id: 'c2', title: 'Apna Bana Le', artist: 'Arijit Singh');
      final candidate3 = makeSong(id: 'c3', title: 'Apna Bana Le - Audio', artist: 'Arijit Singh');
      final candidate4 = makeSong(id: 'c4', title: 'Deva Deva', artist: 'Arijit Singh');

      expect(dedup.addIfUnique(candidate1), isFalse, reason: 'Duplicate of seed should be rejected');
      expect(dedup.addIfUnique(candidate2), isTrue, reason: 'First unique track should be added');
      expect(dedup.addIfUnique(candidate3), isFalse, reason: 'Duplicate of accepted track should be rejected');
      expect(dedup.addIfUnique(candidate4), isTrue, reason: 'Second unique track should be added');

      final filtered = dedup.filterUnique([
        candidate1,
        candidate2,
        candidate3,
        candidate4,
        makeSong(id: 'c5', title: 'Deva Deva (From Film)', artist: 'Arijit Singh'),
        makeSong(id: 'c6', title: 'Raataan Lambiyan', artist: 'Jubin Nautiyal'),
      ]);

      // Only candidate6 should be added now since candidate2 & candidate4 were already accepted
      expect(filtered.map((s) => s.id).toList(), ['c6']);
    });
  });
}
