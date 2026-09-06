import '../../../../data/repositories/taste_vector_engine.dart';
import '../domain/recommendation_repository_contract.dart';
import 'diversity_strategy_contract.dart';

/// Maximal Marginal Relevance (MMR) implementation of [DiversityStrategyContract].
///
/// Balances relevance score against similarity to already-selected tracks,
/// while enforcing hard limits on per-artist saturation.
class MMRDiversityReranker implements DiversityStrategyContract {
  final double lambda;
  final int maxTracksPerArtist;

  const MMRDiversityReranker({
    this.lambda = 0.70,
    this.maxTracksPerArtist = 2,
  });

  @override
  List<CuratedCandidate> diversify(
    List<CuratedCandidate> candidates, {
    int targetCount = 15,
  }) {
    if (candidates.length <= targetCount) return candidates;

    final List<CuratedCandidate> selected = [];
    final List<CuratedCandidate> pool = List.of(candidates);
    final Map<String, int> artistFrequency = {};

    while (selected.length < targetCount && pool.isNotEmpty) {
      CuratedCandidate? bestCandidate;
      double bestMMRScore = -double.infinity;
      int bestIndex = -1;

      for (int i = 0; i < pool.length; i++) {
        final c = pool[i];
        final artist = c.song.artist.trim().toLowerCase();

        // Enforce hard constraint on per-artist saturation
        if ((artistFrequency[artist] ?? 0) >= maxTracksPerArtist) continue;

        final candidateVector = c.song.hasUsableEmbedding
            ? c.song.featureVector
            : TasteVectorEngine.extractSongEmbedding(c.song);

        double maxSimToSelected = 0.0;
        for (final s in selected) {
          final selectedVector = s.song.hasUsableEmbedding
              ? s.song.featureVector
              : TasteVectorEngine.extractSongEmbedding(s.song);

          final sim = TasteVectorEngine.cosineSimilarity(
            candidateVector,
            selectedVector,
          );
          if (sim > maxSimToSelected) maxSimToSelected = sim;
        }

        final mmrScore =
            (lambda * c.score) - ((1.0 - lambda) * maxSimToSelected);
        if (mmrScore > bestMMRScore) {
          bestMMRScore = mmrScore;
          bestCandidate = c;
          bestIndex = i;
        }
      }

      if (bestCandidate != null && bestIndex != -1) {
        selected.add(bestCandidate);
        final artist = bestCandidate.song.artist.trim().toLowerCase();
        artistFrequency[artist] = (artistFrequency[artist] ?? 0) + 1;
        pool.removeAt(bestIndex);
      } else {
        // Fallback if pool is exhausted by hard constraints
        if (pool.isNotEmpty) {
          selected.add(pool.removeAt(0));
        } else {
          break;
        }
      }
    }

    return selected;
  }
}
