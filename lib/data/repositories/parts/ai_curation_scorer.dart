part of '../music_repository.dart';

/// Embedding-pool scorer used by AI playlist/folder curation.
///
/// The AI presets previously re-scored the whole candidate library from
/// scratch once per vibe (up to 9× per `getAIGeneratedPlaylists` call) on
/// every `build()` of the Library AI tab and Home mixes row. This computes
/// each song's embedding exactly once per distinct data state and derives
/// every vibe ranking from the shared vectors.
class AICurationScorer {
  AICurationScorer._();

  /// Cache of candidate pool → shared embeddings, keyed by a cheap signature
  /// of the inputs (taste vector + candidate ids + recency order). Bounded:
  /// a new entry replaces the previous one, and the cache clears itself when
  /// the pool changes between reads (library mutations), so it never grows.
  static String? _lastSignature;
  static Map<String, List<double>> _embeddings = const {};

  static String signature({
    required List<double> tasteVector,
    required Iterable<Song> pool,
  }) {
    final sb = StringBuffer();
    for (int i = 0; i < tasteVector.length; i += 4) {
      sb.write((tasteVector[i] * 10000).round());
      sb.write('_');
    }
    for (final s in pool) {
      sb.write(s.id);
      sb.write(',');
    }
    return sb.toString();
  }

  static void reset() {
    _lastSignature = null;
    _embeddings = const {};
  }

  /// Returns the shared pool (deduped) and an embedding lookup populated for
  /// every candidate, re-embedding only when the underlying songs changed.
  static (List<Song>, Map<String, List<double>>) poolAndEmbeddings({
    required List<double> tasteVector,
    required Iterable<Song> library,
    required Iterable<Song> downloads,
    required Iterable<Song> recent,
  }) {
    final pool = <Song>[];
    final seen = <String>{};
    void addAll(Iterable<Song> songs) {
      for (final s in songs) {
        if (s.id.isNotEmpty && seen.add(s.id)) {
          pool.add(s.copyWith());
        }
      }
    }

    addAll(library);
    addAll(downloads);
    addAll(recent);

    // Embeddings are text-derived from the song itself and never depend on
    // the taste vector, so cache purely on the pool identity: ranking any
    // number of vibes in one build costs a single embedding pass.
    final sig = signature(tasteVector: const [], pool: pool);
    if (sig == _lastSignature) return (pool, _embeddings);

    final embeddings = <String, List<double>>{};
    for (final s in pool) {
      embeddings[s.id] = s.hasUsableEmbedding
          ? s.featureVector
          : TasteVectorEngine.extractSongEmbedding(s);
    }
    _lastSignature = sig;
    _embeddings = embeddings;
    return (pool, embeddings);
  }
}
