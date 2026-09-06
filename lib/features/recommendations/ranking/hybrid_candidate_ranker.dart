import '../../../../shared/models/models.dart';
import '../../../data/repositories/taste_vector_engine.dart';
import '../domain/models/recommendation_context.dart';
import '../domain/models/taste_profile.dart';
import '../domain/recommendation_repository_contract.dart';
import 'candidate_ranker_contract.dart';

/// Deterministic, numerically safe hybrid candidate ranker.
/// Combines cosine vector similarity, artist affinity, session context, and genre preferences.
class HybridCandidateRanker implements CandidateRankerContract {
  const HybridCandidateRanker();

  @override
  List<CuratedCandidate> rank({
    required List<Song> candidates,
    required TasteProfile profile,
    required RecommendationContext context,
  }) {
    final scored = <CuratedCandidate>[];
    final seedArtist = context.seedSong?.artist.toLowerCase().trim();

    for (final song in candidates) {
      final score = calculateScore(
        song: song,
        profile: profile,
        context: context,
        seedArtist: seedArtist,
      );

      final explanation = _deriveExplanation(song, score, seedArtist);
      scored.add(CuratedCandidate(
        song: song,
        score: score,
        matchReason: explanation,
      ));
    }

    // Sort descending by score deterministically
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.song.id.compareTo(b.song.id);
    });

    return scored;
  }

  double calculateScore({
    required Song song,
    required TasteProfile profile,
    required RecommendationContext context,
    String? seedArtist,
  }) {
    final songVec = song.hasUsableEmbedding
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    // 1. Long-term taste alignment (cosine similarity)
    final longTermSim = TasteVectorEngine.cosineSimilarity(
      profile.longTermVector,
      songVec,
    );

    // 2. Short-term session alignment
    final sessionSim = TasteVectorEngine.cosineSimilarity(
      profile.shortTermVector,
      songVec,
    );

    // 3. Artist context affinity bonus
    double artistBonus = 0.0;
    final candArtist = song.artist.toLowerCase().trim();
    if (seedArtist != null && seedArtist.isNotEmpty) {
      if (candArtist == seedArtist) {
        artistBonus = 0.15;
      } else if (candArtist.contains(seedArtist) || seedArtist.contains(candArtist)) {
        artistBonus = 0.08;
      }
    }

    // 4. Stored artist affinity bonus
    final affinityBonus = (profile.artistAffinities[candArtist] ?? 0.0) * 0.10;

    // Composite weighted score
    final rawScore = (sessionSim * 0.40) +
        (longTermSim * 0.40) +
        artistBonus +
        affinityBonus;

    // Safety: ensure score is finite and strictly bounded [0.01, 0.99]
    if (rawScore.isNaN || rawScore.isInfinite) return 0.50;
    return rawScore.clamp(0.01, 0.99);
  }

  String _deriveExplanation(Song s, double score, String? seedArtist) {
    if (seedArtist != null && s.artist.toLowerCase().contains(seedArtist)) {
      return 'Similar artist to your current vibe';
    }
    if (score >= 0.80) return 'Strong sonic taste match';
    if (score >= 0.60) return 'Recommended for your session';
    return 'Sonic exploration';
  }
}
