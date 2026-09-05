/// Knowledge Graph for music entity relationships.
///
/// Maintains weighted edges between entities (artists, genres, moods, eras)
/// that strengthen with user interaction. Used by the recommendation engine
/// for context-aware suggestions and explainable recommendations.
class MusicKnowledgeGraph {
  MusicKnowledgeGraph._();
  static final MusicKnowledgeGraph instance = MusicKnowledgeGraph._();

  /// Entity adjacency: entity_id -> {neighbor_id: weight}
  final Map<String, Map<String, double>> _adjacency = {};

  /// Entity metadata: entity_id -> {type: 'artist'|'genre'|'mood', display_name}
  final Map<String, Map<String, String>> _metadata = {};

  /// Decay factor for edges (daily)
  static const double _decayFactor = 0.995;

  // ── Pre-seeded relationships ──

  static final Map<String, Map<String, double>> _seedEdges = {
    // Genre → Mood edges
    'genre:bollywood': {'mood:romantic': 0.8, 'mood:energetic': 0.6, 'mood:emotional': 0.7, 'mood:nostalgic': 0.5},
    'genre:hip-hop': {'mood:energetic': 0.9, 'mood:confident': 0.8, 'mood:aggressive': 0.5},
    'genre:lo-fi': {'mood:chill': 0.95, 'mood:focus': 0.85, 'mood:melancholy': 0.4},
    'genre:synthwave': {'mood:night': 0.9, 'mood:nostalgic': 0.8, 'mood:cinematic': 0.7},
    'genre:acoustic': {'mood:romantic': 0.7, 'mood:peaceful': 0.8, 'mood:melancholy': 0.5},
    'genre:edm': {'mood:energetic': 0.95, 'mood:euphoric': 0.8, 'mood:party': 0.9},
    'genre:sufi': {'mood:spiritual': 0.95, 'mood:peaceful': 0.7, 'mood:emotional': 0.8},
    'genre:rock': {'mood:energetic': 0.8, 'mood:rebellious': 0.7, 'mood:powerful': 0.8},
    'genre:jazz': {'mood:relaxed': 0.8, 'mood:sophisticated': 0.7, 'mood:chill': 0.6},
    'genre:phonk': {'mood:dark': 0.9, 'mood:aggressive': 0.8, 'mood:night': 0.7},
    'genre:punjabi': {'mood:energetic': 0.8, 'mood:party': 0.7, 'mood:romantic': 0.5},
    'genre:k-pop': {'mood:energetic': 0.8, 'mood:fun': 0.7, 'mood:catchy': 0.9},
    'genre:folk': {'mood:peaceful': 0.8, 'mood:nostalgic': 0.7, 'mood:storytelling': 0.9},

    // Artist similarity edges (genre-based grouping)
    'artist:arijit-singh': {'artist:pritam': 0.85, 'artist:shreya-ghoshal': 0.8, 'artist:atif-aslam': 0.7, 'artist:kk': 0.75, 'artist:sonu-nigam': 0.7},
    'artist:sidhu-moose-wala': {'artist:diljit-dosanjh': 0.8, 'artist:karan-aujla': 0.75, 'artist:ap-dhillon': 0.7, 'artist:shubh': 0.7},
    'artist:the-weeknd': {'artist:drake': 0.7, 'artist:billie-eilish': 0.6, 'artist:dua-lipa': 0.5},
    'artist:badshah': {'artist:divine': 0.7, 'artist:raftaar': 0.7, 'artist:emaslay': 0.6},
    'artist:nusrat-fateh-ali-khan': {'artist:rahat-fateh-ali-khan': 0.95, 'artist:abida-parveen': 0.8, 'artist:sabri-brothers': 0.7},
    'artist:ar-rahman': {'artist:ilaiyaraaja': 0.7, 'artist:anirudh-ravichander': 0.65, 'artist:shankar-ehsaan-loy': 0.6},

    // Mood → Mood semantic similarity
    'mood:romantic': {'mood:emotional': 0.7, 'mood:melancholy': 0.5, 'mood:peaceful': 0.4},
    'mood:energetic': {'mood:party': 0.8, 'mood:confident': 0.6, 'mood:euphoric': 0.5},
    'mood:chill': {'mood:relaxed': 0.9, 'mood:focus': 0.6, 'mood:peaceful': 0.7},
    'mood:dark': {'mood:melancholy': 0.6, 'mood:aggressive': 0.5, 'mood:night': 0.8},
    'mood:sad': {'mood:melancholy': 0.9, 'mood:emotional': 0.8, 'mood:heartbreak': 0.85},
    'mood:happy': {'mood:fun': 0.8, 'mood:uplifting': 0.7, 'mood:party': 0.5},
  };

  static final Map<String, Map<String, String>> _seedMetadata = {
    'genre:bollywood': {'type': 'genre', 'label': 'Bollywood'},
    'genre:hip-hop': {'type': 'genre', 'label': 'Hip-Hop'},
    'genre:lo-fi': {'type': 'genre', 'label': 'Lo-Fi'},
    'genre:synthwave': {'type': 'genre', 'label': 'Synthwave'},
    'genre:acoustic': {'type': 'genre', 'label': 'Acoustic'},
    'genre:edm': {'type': 'genre', 'label': 'EDM'},
    'genre:sufi': {'type': 'genre', 'label': 'Sufi'},
    'genre:rock': {'type': 'genre', 'label': 'Rock'},
    'genre:jazz': {'type': 'genre', 'label': 'Jazz'},
    'genre:phonk': {'type': 'genre', 'label': 'Phonk'},
    'genre:punjabi': {'type': 'genre', 'label': 'Punjabi'},
    'genre:k-pop': {'type': 'genre', 'label': 'K-Pop'},
    'genre:folk': {'type': 'genre', 'label': 'Folk'},
    'mood:romantic': {'type': 'mood', 'label': 'Romantic'},
    'mood:energetic': {'type': 'mood', 'label': 'Energetic'},
    'mood:chill': {'type': 'mood', 'label': 'Chill'},
    'mood:dark': {'type': 'mood', 'label': 'Dark'},
    'mood:sad': {'type': 'mood', 'label': 'Sad'},
    'mood:happy': {'type': 'mood', 'label': 'Happy'},
    'mood:focus': {'type': 'mood', 'label': 'Focus'},
    'mood:night': {'type': 'mood', 'label': 'Night'},
    'mood:spiritual': {'type': 'mood', 'label': 'Spiritual'},
    'mood:party': {'type': 'mood', 'label': 'Party'},
  };

  MusicKnowledgeGraph() {
    // Initialize with seed edges
    for (final entry in _seedEdges.entries) {
      _adjacency[entry.key] = Map.from(entry.value);
    }
    for (final entry in _seedMetadata.entries) {
      _metadata[entry.key] = Map.from(entry.value);
    }
  }

  /// Strengthen edge between two entities based on user signal.
  void reinforce(String from, String to, double weight) {
    _adjacency.putIfAbsent(from, () => {});
    _adjacency.putIfAbsent(to, () => {});
    final current = _adjacency[from]![to] ?? 0.0;
    _adjacency[from]![to] = (current + weight * 0.15).clamp(0.0, 1.0);
    // Bidirectional reinforcement
    final currentRev = _adjacency[to]![from] ?? 0.0;
    _adjacency[to]![from] = (currentRev + weight * 0.1).clamp(0.0, 1.0);
  }

  /// Record that user played a song — auto-infer and reinforce edges.
  void recordSongPlay(String artist, String? genre, {double weight = 1.0}) {
    final artistKey = 'artist:${artist.toLowerCase().replaceAll(' ', '-')}';
    if (genre != null && genre.isNotEmpty) {
      final genreKey = 'genre:${genre.toLowerCase().replaceAll(' ', '-')}';
      reinforce(artistKey, genreKey, weight);
    }
  }

  /// Get top-N related entities for a given entity.
  List<MapEntry<String, double>> getRelated(String entityId, {int topN = 5}) {
    final edges = _adjacency[entityId];
    if (edges == null || edges.isEmpty) return [];
    final sorted = edges.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(topN).toList();
  }

  /// Find the best mood label for a set of genres.
  String inferMood(List<String> genres) {
    final Map<String, double> moodScores = {};
    for (final g in genres) {
      final genreKey = 'genre:${g.toLowerCase().replaceAll(' ', '-')}';
      final edges = _adjacency[genreKey];
      if (edges == null) continue;
      for (final entry in edges.entries) {
        if (entry.key.startsWith('mood:')) {
          moodScores[entry.key] = (moodScores[entry.key] ?? 0.0) + entry.value;
        }
      }
    }
    if (moodScores.isEmpty) return 'neutral';
    final best = moodScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return best.first.key.replaceFirst('mood:', '');
  }

  /// Find similar artists using graph traversal.
  List<String> findSimilarArtists(String artist, {int depth = 2, int maxResults = 10}) {
    final artistKey = 'artist:${artist.toLowerCase().replaceAll(' ', '-')}';
    final visited = <String>{};
    final results = <String, double>{};
    final queue = <MapEntry<String, double>>[MapEntry(artistKey, 1.0)];

    for (int d = 0; d < depth && queue.isNotEmpty; d++) {
      final next = <MapEntry<String, double>>[];
      for (final current in queue) {
        if (!visited.add(current.key)) continue;
        final edges = _adjacency[current.key];
        if (edges == null) continue;
        for (final entry in edges.entries) {
          if (entry.key.startsWith('artist:') && entry.key != artistKey) {
            final score = current.value * entry.value;
            results[entry.key] = (results[entry.key] ?? 0.0) + score;
            if (score > 0.3) next.add(MapEntry(entry.key, score));
          }
        }
      }
      queue..clear()..addAll(next);
    }

    final sorted = results.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxResults).map((e) => e.key.replaceFirst('artist:', '')).toList();
  }

  /// Generate a human-readable explanation for why a song was recommended.
  String explainRecommendation(String artist, String? genre, List<String> recentGenres) {
    final mood = inferMood(recentGenres);

    // Check if this artist has strong genre affinity with recent listening
    if (genre != null) {
      final genreKey = 'genre:${genre.toLowerCase().replaceAll(' ', '-')}';
      for (final recent in recentGenres) {
        final recentKey = 'genre:${recent.toLowerCase().replaceAll(' ', '-')}';
        final weight = _adjacency[genreKey]?[recentKey] ?? 0.0;
        if (weight > 0.5) return 'Shares $genre energy with your recent $recent listening';
      }
    }

    // Check artist similarity
    final similarArtists = findSimilarArtists(artist, depth: 1, maxResults: 3);
    for (final sim in similarArtists) {
      if (recentGenres.any((g) => _adjacency['artist:${sim.replaceAll(' ', '-')}']?.containsKey('genre:${g.toLowerCase().replaceAll(' ', '-')}') == true)) {
        return 'Similar to $sim, who fits your recent vibe';
      }
    }

    // Fallback to mood
    if (mood != 'neutral') return 'Matches the $mood mood from your listening pattern';
    return 'Matches your overall taste profile';
  }

  /// Apply daily decay to all edges (call once per day).
  void applyDecay() {
    for (final entry in _adjacency.values) {
      final keys = entry.keys.toList();
      for (final key in keys) {
        entry[key] = (entry[key]! * _decayFactor).clamp(0.01, 1.0);
        if (entry[key]! < 0.05) entry.remove(key);
      }
    }
  }

  /// Get the full graph for visualization.
  Map<String, Map<String, double>> get fullGraph => Map.unmodifiable(_adjacency);
  Map<String, Map<String, String>> get fullMetadata => Map.unmodifiable(_metadata);
}
