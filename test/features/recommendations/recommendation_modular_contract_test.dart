import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/recommendations/recommendations.dart';
import 'package:noctra/shared/models/models.dart';

void main() {
  group('Recommendation Event Qualification (Anti-Poisoning)', () {
    test('skips under 10 seconds produce fastSkip with negative signal', () {
      final (type, score) = EventQualifier.qualifyPlayback(
        listenedSeconds: 5,
        totalDurationSeconds: 200,
      );
      expect(type, equals(RecommendationEventType.fastSkip));
      expect(score, equals(-0.5));
    });

    test('skips between 10 and 30 seconds produce shortSkip with mild penalty', () {
      final (type, score) = EventQualifier.qualifyPlayback(
        listenedSeconds: 15,
        totalDurationSeconds: 200,
      );
      expect(type, equals(RecommendationEventType.shortSkip));
      expect(score, equals(-0.2));
    });

    test('listens over 90% produce completeListen with full positive score', () {
      final (type, score) = EventQualifier.qualifyPlayback(
        listenedSeconds: 190,
        totalDurationSeconds: 200,
      );
      expect(type, equals(RecommendationEventType.completeListen));
      expect(score, equals(1.0));
    });

    test('explicit user actions map to high-confidence signals', () {
      expect(
        EventQualifier.scoreForExplicitAction(RecommendationEventType.favorite),
        equals(3.0),
      );
      expect(
        EventQualifier.scoreForExplicitAction(RecommendationEventType.playlistAdd),
        equals(2.5),
      );
      expect(
        EventQualifier.scoreForExplicitAction(RecommendationEventType.download),
        equals(2.0),
      );
    });
  });

  group('TasteProfile Multi-Tier Blending & Temporal Decay', () {
    test('initial profile produces uniform 0.5 vector', () {
      final profile = TasteProfile.initial();
      expect(profile.blendedVector.length, equals(32));
      for (final val in profile.blendedVector) {
        expect(val, closeTo(0.5, 0.001));
      }
    });

    test('temporal decay moves medium-term profile toward baseline', () {
      final highVector = List<double>.filled(32, 0.9);
      final profile = TasteProfile(
        shortTermVector: List.unmodifiable(highVector),
        mediumTermVector: List.unmodifiable(highVector),
        longTermVector: List.unmodifiable(highVector),
        artistAffinities: const {},
        genreAffinities: const {},
        updatedAt: DateTime.now().subtract(const Duration(days: 14)),
      );

      final decayed = profile.applyDecay(daysElapsed: 14);
      // factor for 14 days is exp(-0.0495 * 14) ~= 0.50
      // value should move from 0.9 toward 0.5 (around 0.70)
      expect(decayed.mediumTermVector[0], lessThan(0.9));
      expect(decayed.mediumTermVector[0], greaterThan(0.6));
    });
  });

  group('MMR Diversity Re-ranking', () {
    test('enforces hard constraint of maximum 2 tracks per artist in top feed', () {
      const artistA = 'Artist Overrepresented';
      final candidates = List.generate(
        10,
        (i) => CuratedCandidate(
          song: Song(
            id: 'song_$i',
            title: 'Track $i',
            artist: i < 6 ? artistA : 'Artist Diverse $i',
            album: 'Album',
            duration: const Duration(seconds: 200),
          ),
          score: 95.0 - (i * 2),
          matchReason: 'Top match',
        ),
      );

      const reranker = MMRDiversityReranker(maxTracksPerArtist: 2);
      final diversified = reranker.diversify(candidates, targetCount: 6);

      final artistACount =
          diversified.where((c) => c.song.artist == artistA).length;
      expect(artistACount, lessThanOrEqualTo(2));
    });
  });
}
