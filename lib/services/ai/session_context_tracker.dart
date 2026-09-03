import '../../data/models/song_model.dart';
import '../../data/repositories/taste_vector_engine.dart';

// SessionContextTracker maintains a short-term in-memory model of the
// current listening session. It decays naturally when the app is killed.
// Long-term taste is handled by TasteVectorEngine + SQLite (separate path).
class SessionContextTracker {
  static final SessionContextTracker _instance = SessionContextTracker._internal();
  factory SessionContextTracker() => _instance;
  SessionContextTracker._internal();

  static const int _maxSessionSongs = 20;
  static const int _momentumWindow = 3;

  final List<_SessionEntry> _queue = [];
  final Map<String, double> _artistAffinity = {};
  final Map<String, double> _genreAffinity = {};
  DateTime _sessionStart = DateTime.now();

  int get sessionSongCount => _queue.length;
  Map<String, double> get artistAffinity => Map.unmodifiable(_artistAffinity);
  Map<String, double> get genreAffinity => Map.unmodifiable(_genreAffinity);

  void recordSong(Song song, String eventType) {
    final weight = _signalWeight(eventType);
    if (weight <= 0) {
      // Negative signal: reduce affinity symmetrically with positive
      _adjustArtistAffinity(song.artist, weight * 0.15);
      final genre = song.genre;
      if (genre != null && genre.isNotEmpty) _adjustGenreAffinity(genre, weight * 0.12);
      return;
    }

    final entry = _SessionEntry(song: song, weight: weight, timestamp: DateTime.now());

    // Ring buffer — keep last _maxSessionSongs
    if (_queue.length >= _maxSessionSongs) _queue.removeAt(0);
    _queue.add(entry);

    _adjustArtistAffinity(song.artist, weight * 0.15);
    final genre = song.genre;
    if (genre != null && genre.isNotEmpty) _adjustGenreAffinity(genre, weight * 0.12);
  }

  static const int _maxAffinityEntries = 100;

  void _adjustArtistAffinity(String artist, double delta) {
    final key = artist.toLowerCase().trim();
    if (key.isEmpty) return;
    if (_artistAffinity.length >= _maxAffinityEntries &&
        !_artistAffinity.containsKey(key)) {
      _artistAffinity.remove(_artistAffinity.keys.first);
    }
    _artistAffinity[key] = ((_artistAffinity[key] ?? 0.5) + delta).clamp(0.0, 1.0);
  }

  void _adjustGenreAffinity(String genre, double delta) {
    final key = genre.toLowerCase().trim();
    if (key.isEmpty) return;
    if (_genreAffinity.length >= _maxAffinityEntries &&
        !_genreAffinity.containsKey(key)) {
      _genreAffinity.remove(_genreAffinity.keys.first);
    }
    _genreAffinity[key] = ((_genreAffinity[key] ?? 0.5) + delta).clamp(0.0, 1.0);
  }

  static double _signalWeight(String eventType) {
    switch (eventType) {
      case 'favorite': return 3.0;
      case 'playlist_add': return 2.5;
      case 'download': return 2.0;
      case 'replay': return 1.5;
      case 'search_select': return 1.2;
      case 'complete_listen': return 1.0;
      case 'deep_listen': return 0.6;
      case 'partial_listen': return 0.2;
      case 'fast_skip': return -1.0;
      case 'short_skip': return -0.4;
      default: return 0.3;
    }
  }

  // Weighted average of session song embeddings, recency-boosted
  List<double> get sessionVector {
    if (_queue.isEmpty) return TasteVectorEngine.getDefaultVector();
    final dim = TasteVectorEngine.vectorDimension;
    final result = List<double>.filled(dim, 0.0);
    double totalWeight = 0.0;

    for (int qi = 0; qi < _queue.length; qi++) {
      final e = _queue[qi];
      // Recency factor: newer entries get higher weight
      final recency = (qi + 1) / _queue.length;
      final w = e.weight * recency;

      final vec = e.song.hasUsableEmbedding
          ? e.song.featureVector
          : TasteVectorEngine.extractSongEmbedding(e.song);

      for (int i = 0; i < dim; i++) {
        result[i] += vec[i] * w;
      }
      totalWeight += w;
    }

    if (totalWeight == 0) return TasteVectorEngine.getDefaultVector();
    for (int i = 0; i < dim; i++) {
      result[i] = (result[i] / totalWeight).clamp(0.05, 0.95);
    }
    return result;
  }

  // Direction of taste shift in this session (last-3 vs prev-3 embeddings)
  List<double> get momentumFeatures {
    final qLen = _queue.length;
    if (qLen < _momentumWindow * 2) return List.filled(8, 0.5);
    final dim = TasteVectorEngine.vectorDimension;
    final recent = _queue.sublist(qLen - _momentumWindow);
    final prev = _queue.sublist(qLen - _momentumWindow * 2, qLen - _momentumWindow);

    List<double> avg(List<_SessionEntry> entries) {
      final r = List<double>.filled(dim, 0.0);
      for (final e in entries) {
        final v = e.song.hasUsableEmbedding
            ? e.song.featureVector
            : TasteVectorEngine.extractSongEmbedding(e.song);
        for (int i = 0; i < dim; i++) {
          r[i] += v[i];
        }
      }
      return r.map((x) => x / entries.length).toList();
    }

    final recentAvg = avg(recent);
    final prevAvg = avg(prev);
    // Return 8 most-changed axes as momentum signal
    final deltas = List.generate(dim, (i) => recentAvg[i] - prevAvg[i]);
    deltas.sort((a, b) => b.abs().compareTo(a.abs()));
    return deltas.take(8).map((d) => (d + 1.0) / 2.0).toList(); // normalize to [0,1]
  }

  // Top-N artist affinities as a fixed-length feature vector (8 dims)
  List<double> topArtistAffinityFeatures({int n = 8}) {
    final sorted = _artistAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <double>[];
    for (int i = 0; i < n; i++) {
      result.add(i < sorted.length ? sorted[i].value : 0.5);
    }
    return result;
  }

  // Blended vector: 60% long-term + 40% short-term session
  List<double> blendedVector(List<double> longTerm) {
    final session = sessionVector;
    final dim = TasteVectorEngine.vectorDimension;
    assert(longTerm.length == dim, 'longTerm length ${longTerm.length} != dim $dim');
    assert(session.length == dim, 'session length ${session.length} != dim $dim');
    final safeLT = longTerm.length == dim ? longTerm : List<double>.generate(dim, (i) => i < longTerm.length ? longTerm[i] : 0.5);
    final safeSV = session.length == dim ? session : List<double>.generate(dim, (i) => i < session.length ? session[i] : 0.5);
    final result = List<double>.filled(dim, 0.0);
    for (int i = 0; i < dim; i++) {
      result[i] = (safeLT[i] * 0.60 + safeSV[i] * 0.40).clamp(0.05, 0.95);
    }
    return result;
  }

  // Minutes elapsed since session start
  double get sessionAgeMinutes =>
      DateTime.now().difference(_sessionStart).inMinutes.toDouble();

  void resetSession() {
    _queue.clear();
    _artistAffinity.clear();
    _genreAffinity.clear();
    _sessionStart = DateTime.now();
  }
}

class _SessionEntry {
  final Song song;
  final double weight;
  final DateTime timestamp;
  const _SessionEntry({required this.song, required this.weight, required this.timestamp});
}
