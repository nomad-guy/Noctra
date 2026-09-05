import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/recommendations/domain/recommendation_repository_contract.dart';
import 'package:noctra/services/ai/candidate_retrieval_service.dart';
import 'package:noctra/services/metadata/deezer_audio_features_service.dart';
import 'package:noctra/shared/models/models.dart';

class FakeRecommendationRepository implements RecommendationRepositoryContract {
  final List<Song> cannedPool;

  FakeRecommendationRepository(this.cannedPool);

  @override
  Future<List<CuratedCandidate>> getPersonalizedFeed({
    String? vibeKey,
    String? naturalPrompt,
    Song? seedSong,
    int targetCount = 15,
    bool preferDeepCuts = false,
  }) async {
    final raw = await CandidateRetrievalService.curatePersonalizedFeed(
      vibeKey: vibeKey,
      naturalPrompt: naturalPrompt,
      seedSong: seedSong,
      targetCount: targetCount,
      preferDeepCuts: preferDeepCuts,
      poolOverride: cannedPool,
      featureFetcher: (t, a) async => const AudioFeatures(),
    );
    return raw.map((m) => CuratedCandidate.fromMap(m)).toList();
  }

  @override
  List<CuratedCandidate> getCuratedByVibe({String? vibeKey, String? naturalPrompt}) {
    return cannedPool.map((s) => CuratedCandidate(
          song: s,
          score: 0.9,
          matchReason: 'Vibe match ($vibeKey)',
        )).toList();
  }
}

void main() {
  group('Recommendation Subsystem Contract Tests', () {
    late FakeRecommendationRepository repo;

    setUp(() {
      repo = FakeRecommendationRepository([
        Song(
          id: 'vibe_1',
          title: 'Nightfall Pulse',
          artist: 'Luna Shadow',
          duration: const Duration(seconds: 200),
          featureVector: [0.8, 0.2, 0.9, 0.1, 0.5],
        ),
        Song(
          id: 'vibe_2',
          title: 'Late Night Coffee',
          artist: 'Lo-Fi Walker',
          duration: const Duration(seconds: 160),
          featureVector: [0.2, 0.9, 0.1, 0.8, 0.4],
        ),
      ]);
    });

    test('curates personalized feed using isolated pool and neutral features', () async {
      final feed = await repo.getPersonalizedFeed(
        vibeKey: 'late_night',
        targetCount: 2,
      );

      expect(feed, isNotEmpty);
      expect(feed.first.song.id, anyOf('vibe_1', 'vibe_2'));
      expect(feed.first.score, isNotNull);
      expect(feed.first.matchReason, isNotEmpty);
    });

    test('retrieves synchronous vibe candidates', () {
      final candidates = repo.getCuratedByVibe(vibeKey: 'ambient');
      expect(candidates.length, equals(2));
      expect(candidates.first.matchReason, contains('ambient'));
    });
  });
}
