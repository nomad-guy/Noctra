import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/neural_recommender_engine.dart';
import '../../data/repositories/taste_vector_engine.dart';
import '../../services/ytdlp/music_service.dart';
import 'mmr_diversity_filter.dart';

class CandidateRetrievalService {
  /// Two-stage neural retrieval + MLP scoring + MMR diversity filter
  static Future<List<Map<String, dynamic>>> curatePersonalizedFeed({
    String? vibeKey,
    String? naturalPrompt,
    int targetCount = 15,
  }) async {
    final repo = MusicRepository();
    final userVector = repo.userTasteVector;

    // Stage 1: Fast Candidate Pool Retrieval (~100 items)
    final Set<String> seenIds = {};
    final List<Song> pool = [];

    void addTracks(List<Song> tracks) {
      for (final s in tracks) {
        if (s.id.isNotEmpty && seenIds.add(s.id)) pool.add(s);
      }
    }

    addTracks(repo.localLibrary);
    addTracks(repo.downloads);
    addTracks(repo.recentlyPlayed);
    addTracks(repo.favorites);

    // Fetch dynamic live candidates
    try {
      if (naturalPrompt != null && naturalPrompt.trim().isNotEmpty) {
        final searchResults = await MusicService.search(naturalPrompt.trim());
        addTracks(searchResults);
      } else if (vibeKey != null) {
        final vibeTracks = await MusicService.fetchVibeFeed(vibeKey);
        addTracks(vibeTracks);
      } else {
        final trending = await MusicService.fetchTrendingFeed();
        addTracks(trending);
      }
    } catch (_) {}

    if (pool.isEmpty) return [];

    // Stage 2: On-Device Tiny Neural MLP Scoring
    final List<ScoredCandidate> scored = [];
    final targetVector = TasteVectorEngine.getTargetVector(
      vibeKey: vibeKey,
      prompt: naturalPrompt,
      defaultTaste: userVector,
    );

    for (final song in pool) {
      final double mlpProb = NeuralRecommenderEngine.predictScore(
        userVector: targetVector,
        song: song,
      );
      final int score = ((mlpProb * 78) + 21).round().clamp(60, 99);
      final explanation = TasteVectorEngine.generateExplanation(song, score, vibeKey, naturalPrompt);

      scored.add(ScoredCandidate(
        song: song,
        score: mlpProb,
        explanation: explanation,
      ));
    }

    // Sort by Neural Probabilities
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Stage 3: MMR Diversity Reranker
    final diversified = MMRDiversityFilter.rerankWithMMR(
      candidates: scored,
      targetCount: targetCount,
      lambda: 0.75,
    );

    return diversified.map((d) => d.toMap()).toList();
  }
}
