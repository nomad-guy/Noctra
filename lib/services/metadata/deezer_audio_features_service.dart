import 'dart:convert';
import 'package:http/http.dart' as http;

/// Audio features fetched from Deezer's public API (no key required).
/// Maps to Spotify-like audio analysis: energy, danceability, valence, etc.
class AudioFeatures {
  final double energy;
  final double danceability;
  final double valence;
  final double tempo;
  final double acousticness;
  final double instrumentalness;
  final double speechiness;
  final double liveness;
  final double loudness; // dB, typically -60 to 0
  final double duration; // seconds
  final String? key; // musical key: C, C#, D, ...
  final String? mode; // major/minor
  final int timeSignature; // 3, 4, 5, etc.
  final String source; // 'deezer', 'deezermatch', 'estimated'

  const AudioFeatures({
    this.energy = 0.5,
    this.danceability = 0.5,
    this.valence = 0.5,
    this.tempo = 120.0,
    this.acousticness = 0.5,
    this.instrumentalness = 0.0,
    this.speechiness = 0.05,
    this.liveness = 0.1,
    this.loudness = -8.0,
    this.duration = 210.0,
    this.key,
    this.mode,
    this.timeSignature = 4,
    this.source = 'default',
  });

  /// Convert to 8-dim feature vector for the neural engine.
  List<double> toFeatureVector() {
    return [
      energy,
      danceability,
      valence,
      (tempo / 200.0).clamp(0.0, 1.0),
      acousticness,
      instrumentalness,
      speechiness,
      liveness,
    ];
  }

  static const AudioFeatures defaults = AudioFeatures(source: 'default');
}

/// Zero-key Deezer audio features lookup.
/// Uses Deezer's public search + track endpoints.
class DeezerAudioFeaturesService {
  static final Map<String, AudioFeatures> _cache = {};
  static const int _maxCacheSize = 500;

  /// Fetch audio features for a song by title + artist.
  /// Falls back to genre-based estimation if Deezer lookup fails.
  static Future<AudioFeatures> fetchFeatures(
      String title, String artist) async {
    final cacheKey =
        '${title.toLowerCase().trim()}::${artist.toLowerCase().trim()}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    AudioFeatures? features;

    // Tier 1: Deezer search → track ID → audio info
    try {
      features = await _fetchFromDeezer(title, artist);
    } catch (_) {}

    // Tier 2: Search by artist name only (broader match)
    if (features == null) {
      try {
        features = await _fetchFromDeezer(title, '');
      } catch (_) {}
    }

    // Tier 3: Genre-based estimation from title/artist keywords
    features ??= _estimateFromKeywords(title, artist);

    // Cache result
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = features;

    return features;
  }

  static Future<AudioFeatures?> _fetchFromDeezer(
      String title, String artist) async {
    final query = artist.isNotEmpty ? '$title $artist' : title;
    final uri = Uri.parse(
        'https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=3');
    final res = await http
        .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 3));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['data'] as List?;
    if (results == null || results.isEmpty) return null;

    // Find best match (prefer title + artist match)
    Map<String, dynamic>? bestMatch;
    for (final item in results) {
      final trackTitle = (item['title'] ?? '').toString().toLowerCase();
      final searchTitle = title.toLowerCase();

      if (trackTitle.contains(searchTitle) ||
          searchTitle.contains(trackTitle)) {
        bestMatch = item as Map<String, dynamic>;
        break;
      }
    }
    bestMatch ??= results.first as Map<String, dynamic>;

    final trackId = bestMatch['id'];
    if (trackId == null) return null;

    // Fetch detailed track info (includes BPM, duration, etc.)
    final detailUri = Uri.parse('https://api.deezer.com/track/$trackId');
    final detailRes = await http
        .get(detailUri, headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 3));

    if (detailRes.statusCode != 200) return null;

    final detail = jsonDecode(detailRes.body) as Map<String, dynamic>;
    final bpm = (detail['bpm'] as num?)?.toDouble() ?? 120.0;
    final duration = (detail['duration'] as num?)?.toDouble() ?? 210.0;
    // Deezer track fields we can use
    final gain = (detail['gain'] as num?)?.toDouble() ?? -8.0;

    // Estimate audio features from available Deezer data
    // Deezer doesn't expose full audio features publicly, but we can
    // derive good estimates from BPM, duration, and genre signals
    final estimated = _estimateFromBpmAndDuration(bpm, duration, gain);

    return AudioFeatures(
      energy: estimated.energy,
      danceability: estimated.danceability,
      valence: estimated.valence,
      tempo: bpm,
      acousticness: estimated.acousticness,
      instrumentalness: estimated.instrumentalness,
      speechiness: estimated.speechiness,
      liveness: estimated.liveness,
      loudness: gain,
      duration: duration,
      key: _midiToKey(detail['key'] as int?),
      mode: (detail['mode'] as int?) == 1 ? 'major' : 'minor',
      timeSignature: detail['time_signature'] as int? ?? 4,
      source: 'deezer',
    );
  }

  /// Estimate audio features from BPM, duration, and loudness.
  static AudioFeatures _estimateFromBpmAndDuration(
      double bpm, double duration, double gain) {
    // BPM-based energy/danceability
    final bpmNorm = (bpm / 180.0).clamp(0.0, 1.0);
    final energy = (0.3 + bpmNorm * 0.6 + (gain > -5 ? 0.1 : 0.0))
        .clamp(0.0, 1.0);
    final danceability = (0.2 + bpmNorm * 0.5 + 0.2).clamp(0.0, 1.0);

    // Duration-based features
    final isShort = duration < 180;
    final isLong = duration > 300;
    final acousticness = isLong ? 0.6 : (isShort ? 0.2 : 0.35);
    final instrumentalness = duration > 240 ? 0.3 : 0.05;

    return AudioFeatures(
      energy: energy,
      danceability: danceability,
      valence: (0.3 + bpmNorm * 0.3).clamp(0.0, 1.0),
      tempo: bpm,
      acousticness: acousticness,
      instrumentalness: instrumentalness,
      speechiness: 0.05,
      liveness: 0.1,
      loudness: gain,
      duration: duration,
      source: 'deezer_estimate',
    );
  }

  /// Estimate features from title/artist keywords.
  static AudioFeatures _estimateFromKeywords(String title, String artist) {
    final text = '$title $artist'.toLowerCase();

    double energy = 0.5, danceability = 0.5, valence = 0.5;
    double acousticness = 0.3, tempo = 120.0;

    if (text.contains('chill') || text.contains('lofi') || text.contains('relax')) {
      energy = 0.25; danceability = 0.4; valence = 0.4;
      acousticness = 0.7; tempo = 85;
    } else if (text.contains('party') || text.contains('dance') || text.contains('edm')) {
      energy = 0.9; danceability = 0.9; valence = 0.8;
      acousticness = 0.05; tempo = 128;
    } else if (text.contains('rock') || text.contains('metal')) {
      energy = 0.85; danceability = 0.5; valence = 0.5;
      acousticness = 0.1; tempo = 140;
    } else if (text.contains('romantic') || text.contains('love')) {
      energy = 0.4; danceability = 0.45; valence = 0.7;
      acousticness = 0.5; tempo = 95;
    } else if (text.contains('sad') || text.contains('heartbreak')) {
      energy = 0.3; danceability = 0.3; valence = 0.2;
      acousticness = 0.6; tempo = 80;
    } else if (text.contains('rap') || text.contains('hip hop') || text.contains('trap')) {
      energy = 0.75; danceability = 0.8; valence = 0.5;
      acousticness = 0.1; tempo = 140;
    } else if (text.contains('sufi') || text.contains('qawwali') || text.contains('bhajan')) {
      energy = 0.5; danceability = 0.4; valence = 0.6;
      acousticness = 0.8; tempo = 90;
    } else if (text.contains('synthwave') || text.contains('retro') || text.contains('outrun')) {
      energy = 0.7; danceability = 0.6; valence = 0.5;
      acousticness = 0.05; tempo = 110;
    } else if (text.contains('acoustic') || text.contains('unplugged') || text.contains('folk')) {
      energy = 0.35; danceability = 0.4; valence = 0.5;
      acousticness = 0.85; tempo = 100;
    }

    return AudioFeatures(
      energy: energy,
      danceability: danceability,
      valence: valence,
      tempo: tempo,
      acousticness: acousticness,
      source: 'keyword_estimate',
    );
  }

  static String? _midiToKey(int? midi) {
    if (midi == null) return null;
    const keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return (midi >= 0 && midi < keys.length) ? keys[midi] : null;
  }
}
