import '../../data/models/song_model.dart';
import '../../data/repositories/taste_vector_engine.dart';

class ScoredCandidate {
  final Song song;
  final double score;
  final String explanation;

  const ScoredCandidate({
    required this.song,
    required this.score,
    required this.explanation,
  });

  Map<String, dynamic> toMap() => {
    'song': song,
    'score': (score * 100).round(),
    'matchPercentage': (score * 100).round(),
    'explanation': explanation,
  };
}

class MMRDiversityFilter {
  /// Applies Maximal Marginal Relevance (MMR) to guarantee artist and genre variety
  static List<ScoredCandidate> rerankWithMMR({
    required List<ScoredCandidate> candidates,
    int targetCount = 15,
    double lambda = 0.72,
  }) {
    if (candidates.length <= targetCount) return candidates;

    final List<ScoredCandidate> selected = [];
    final List<ScoredCandidate> pool = List<ScoredCandidate>.from(candidates);
    final Map<String, int> artistFrequency = {};

    while (selected.length < targetCount && pool.isNotEmpty) {
      ScoredCandidate? bestCandidate;
      double bestMMRScore = -double.infinity;
      int bestIndex = -1;

      for (int i = 0; i < pool.length; i++) {
        final c = pool[i];
        final artist = c.song.artist.trim().toLowerCase();
        // Hard constraint: Max 2 tracks per artist in Top 15
        if ((artistFrequency[artist] ?? 0) >= 2) continue;

        final candidateVector = _embedding(c.song);
        double maxSimToSelected = 0.0;
        for (final s in selected) {
          final sim = TasteVectorEngine.cosineSimilarity(
            candidateVector,
            _embedding(s.song),
          );
          if (sim > maxSimToSelected) maxSimToSelected = sim;
        }

        final mmrScore = (lambda * c.score) - ((1.0 - lambda) * maxSimToSelected);
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
        // Fallback if hard constraint exhausted pool
        if (pool.isNotEmpty) {
          selected.add(pool.removeAt(0));
        } else {
          break;
        }
      }
    }

    return selected;
  }

  static List<double> _embedding(Song song) => song.hasUsableEmbedding
      ? song.featureVector
      : TasteVectorEngine.extractSongEmbedding(song);
}
