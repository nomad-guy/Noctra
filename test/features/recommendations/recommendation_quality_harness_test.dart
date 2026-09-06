import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';
import 'package:noctra/features/recommendations/domain/models/recommendation_context.dart';
import 'package:noctra/features/recommendations/domain/models/taste_profile.dart';
import 'package:noctra/features/recommendations/domain/recommendation_repository_contract.dart';
import 'package:noctra/features/recommendations/diversity/mmr_diversity_reranker.dart';
import 'package:noctra/features/recommendations/ranking/hybrid_candidate_ranker.dart';

void main() {
  group('Phase 24 & 25: Recommendation Quality Test Harness', () {
    late HybridCandidateRanker ranker;
    late MMRDiversityReranker reranker;

    setUp(() {
      ranker = const HybridCandidateRanker();
      reranker = const MMRDiversityReranker();
    });

    test('Ranking is deterministic: identical inputs produce identical outputs', () {
      final profile = TasteProfile.initial();
      final context = RecommendationContext.now();
      final candidates = [
        Song(
          id: 'song_a',
          title: 'Night Drive',
          artist: 'Synthwave Guy',
          album: 'Outrun',
          streamUrl: null,
          duration: const Duration(seconds: 210),
          genre: 'Synthwave',
          featureVector: TasteVectorEngine.extractTextEmbedding('synthwave night drive'),
        ),
        Song(
          id: 'song_b',
          title: 'Acoustic Morning',
          artist: 'Folk Guy',
          album: 'Woods',
          streamUrl: null,
          duration: const Duration(seconds: 180),
          genre: 'Acoustic',
          featureVector: TasteVectorEngine.extractTextEmbedding('acoustic guitar folk'),
        ),
      ];

      final run1 = ranker.rank(candidates: candidates, profile: profile, context: context);
      final run2 = ranker.rank(candidates: candidates, profile: profile, context: context);

      expect(run1.length, equals(run2.length));
      for (int i = 0; i < run1.length; i++) {
        expect(run1[i].song.id, equals(run2[i].song.id));
        expect(run1[i].score, equals(run2[i].score));
      }
    });

    test('Diversity constraint: Enforces max 2 songs per artist', () {
      final pool = [
        for (int i = 0; i < 8; i++)
          CuratedCandidate(
            song: Song(
              id: 'arijit_$i',
              title: 'Arijit Song $i',
              artist: 'Arijit Singh',
              album: 'Bollywood Hits',
              streamUrl: null,
              duration: const Duration(seconds: 220),
              genre: 'Bollywood',
            ),
            score: 0.95 - (i * 0.01),
            matchReason: 'Top Hit',
          ),
        for (int i = 0; i < 5; i++)
          CuratedCandidate(
            song: Song(
              id: 'weeknd_$i',
              title: 'The Weeknd Song $i',
              artist: 'The Weeknd',
              album: 'After Hours',
              streamUrl: null,
              duration: const Duration(seconds: 230),
              genre: 'R&B',
            ),
            score: 0.85 - (i * 0.01),
            matchReason: 'Vibe Match',
          ),
        for (int i = 0; i < 5; i++)
          CuratedCandidate(
            song: Song(
              id: 'taylor_$i',
              title: 'Taylor Song $i',
              artist: 'Taylor Swift',
              album: '1989',
              streamUrl: null,
              duration: const Duration(seconds: 210),
              genre: 'Pop',
            ),
            score: 0.80 - (i * 0.01),
            matchReason: 'Vibe Match',
          ),
      ];

      final diversified = reranker.diversify(pool, targetCount: 6);

      expect(diversified.length, equals(6));
      final arijitCount = diversified.where((c) => c.song.artist == 'Arijit Singh').length;
      expect(arijitCount, lessThanOrEqualTo(2));
    });

    test('Numerical safety: Never produces NaN, Infinity, or out-of-bound scores', () {
      final profile = TasteProfile.initial();
      final context = RecommendationContext.now();
      final degenerateSong = Song(
        id: 'degenerate',
        title: '',
        artist: '',
        album: '',
        streamUrl: null,
        duration: Duration.zero,
        featureVector: List<double>.filled(32, 0.0), // All zeros
      );

      final ranked = ranker.rank(candidates: [degenerateSong], profile: profile, context: context);
      expect(ranked.first.score.isNaN, isFalse);
      expect(ranked.first.score.isInfinite, isFalse);
      expect(ranked.first.score, inInclusiveRange(0.01, 0.99));
    });

    test('Cold start: Empty history produces valid, scored candidates', () {
      final coldProfile = TasteProfile.initial();
      final coldContext = RecommendationContext.now();
      final candidates = [
        Song(
          id: 'popular_1',
          title: 'Starboy',
          artist: 'The Weeknd',
          album: 'Starboy',
          streamUrl: null,
          duration: const Duration(seconds: 230),
          genre: 'Pop',
        ),
      ];

      final ranked = ranker.rank(candidates: candidates, profile: coldProfile, context: coldContext);
      expect(ranked, isNotEmpty);
      expect(ranked.first.score, inInclusiveRange(0.01, 0.99));
      expect(ranked.first.matchReason, isNotEmpty);
    });
  });
}
