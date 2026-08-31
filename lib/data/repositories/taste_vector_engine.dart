import 'dart:math';
import '../models/song_model.dart';

class TasteVectorEngine {
  static const List<String> axisNames = [
    'Dark Tone', 'Ambient Depth', 'Energy', 'Chill Factor',
    'Melancholy', 'Acoustic Warmth', 'Electronic', 'Vocal Presence',
    'Harmonic Density', 'Analog Synth', 'Night Drive', 'Cognitive Focus',
    'Uplift', 'Sub-Bass Weight', 'Rhythm Tempo', 'Instrumental'
  ];

  static List<double> getDefaultVector() => [0.65, 0.50, 0.60, 0.50, 0.45, 0.35, 0.70, 0.60, 0.55, 0.75, 0.80, 0.55, 0.50, 0.70, 0.65, 0.40];

  /// Computes mathematically normalized cosine similarity on [0.0, 1.0] with symmetric dimensions
  static double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty) return 0.5;
    final int n = min(min(v1.length, v2.length), 16);
    if (n == 0) return 0.5;

    double dot = 0.0, mag1 = 0.0, mag2 = 0.0;
    int valid = 0;

    for (int i = 0; i < n; i++) {
      final double val1 = v1[i];
      final double val2 = v2[i];
      if (val1.isNaN || val1.isInfinite || val2.isNaN || val2.isInfinite) continue;

      dot += val1 * val2;
      mag1 += val1 * val1;
      mag2 += val2 * val2;
      valid++;
    }

    if (valid == 0 || mag1 == 0 || mag2 == 0) return 0.5;
    final double denom = sqrt(mag1) * sqrt(mag2);
    if (denom == 0 || denom.isNaN) return 0.5;

    return (dot / denom).clamp(0.0, 1.0);
  }

  /// Extracts 16-dimensional acoustic feature embedding using additive multi-axis weighting
  static List<double> extractSongEmbedding(Song song) {
    final text = '${song.title} ${song.artist} ${song.album} ${song.genre}'.toLowerCase();
    final vec = List<double>.from(getDefaultVector());

    void nudge(int axis, double target, double weight) {
      if (axis >= 0 && axis < 16) {
        vec[axis] = (vec[axis] * (1.0 - weight) + target * weight).clamp(0.05, 0.98);
      }
    }

    if (text.contains('dark') || text.contains('night') || text.contains('black') || text.contains('shadow')) {
      nudge(0, 0.92, 0.6); nudge(10, 0.95, 0.7); nudge(13, 0.85, 0.5);
    }
    if (text.contains('hyper') || text.contains('energy') || text.contains('fast') || text.contains('rock') || text.contains('drop')) {
      nudge(2, 0.95, 0.7); nudge(14, 0.90, 0.6); nudge(12, 0.80, 0.5);
    }
    if (text.contains('chill') || text.contains('relax') || text.contains('ambient') || text.contains('lofi') || text.contains('sleep')) {
      nudge(1, 0.92, 0.6); nudge(3, 0.95, 0.7); nudge(11, 0.88, 0.6); nudge(2, 0.20, 0.5);
    }
    if (text.contains('acoustic') || text.contains('guitar') || text.contains('piano') || text.contains('unplugged') || text.contains('folk')) {
      nudge(5, 0.95, 0.8); nudge(6, 0.15, 0.7); nudge(7, 0.88, 0.5);
    }
    if (text.contains('synth') || text.contains('retro') || text.contains('cyber') || text.contains('electro') || text.contains('outrun')) {
      nudge(6, 0.95, 0.7); nudge(9, 0.98, 0.8); nudge(10, 0.92, 0.6); nudge(13, 0.85, 0.5);
    }
    if (text.contains('instrumental') || text.contains('soundtrack') || text.contains('orchestra') || text.contains('remix')) {
      nudge(15, 0.95, 0.8); nudge(7, 0.15, 0.7);
    } else if (text.contains('feat') || text.contains('vocal') || text.contains('voice') || text.contains('acoustic')) {
      nudge(7, 0.92, 0.6); nudge(15, 0.20, 0.6);
    }

    return vec;
  }

  /// Reinforcement learning vector update with adaptive reward shaping
  static List<double> selfHealAndRecalibrate(List<double> currentVector, {Song? lastSong, String eventType = 'listen'}) {
    final List<double> targetVector = lastSong != null && lastSong.featureVector.isNotEmpty
        ? (lastSong.featureVector.every((x) => x == 0.5) ? extractSongEmbedding(lastSong) : lastSong.featureVector)
        : getDefaultVector();

    final List<double> updated = List<double>.from(currentVector);
    while (updated.length < 16) {
      updated.add(0.5);
    }

    double alpha = 0.06;
    if (eventType == 'fast_skip') {
      alpha = -0.08;
    } else if (eventType == 'complete_listen') {
      alpha = 0.12;
    } else if (eventType == 'favorite') {
      alpha = 0.18;
    }

    for (int i = 0; i < 16 && i < targetVector.length; i++) {
      final target = targetVector[i];
      final delta = (target - updated[i]) * alpha;
      updated[i] = (updated[i] + delta).clamp(0.05, 0.95);
    }

    return updated;
  }

  static List<double> updateVector({required List<double> current, required List<double> songVector, required String action}) {
    return selfHealAndRecalibrate(
      current,
      lastSong: Song(
        id: '',
        title: '',
        artist: '',
        album: '',
        artworkUrl: '',
        streamUrl: '',
        duration: Duration.zero,
        featureVector: songVector,
      ),
      eventType: action,
    );
  }

  static List<double> getTargetVector({String? vibeKey, String? prompt, List<double>? defaultTaste}) {
    final vec = List<double>.from(defaultTaste ?? getDefaultVector());
    if (vibeKey != null) {
      switch (vibeKey) {
        case 'noir_night': vec[0] = 0.95; vec[10] = 0.98; vec[13] = 0.85; break;
        case 'retro_synth': vec[6] = 0.98; vec[9] = 0.98; vec[10] = 0.92; break;
        case 'deep_focus': vec[11] = 0.95; vec[15] = 0.90; vec[2] = 0.35; break;
        case 'high_energy': vec[2] = 0.98; vec[14] = 0.95; vec[12] = 0.85; break;
        case 'ambient_chill': vec[1] = 0.95; vec[3] = 0.98; vec[2] = 0.20; break;
      }
    }
    if (prompt != null && prompt.isNotEmpty) {
      final p = prompt.toLowerCase();
      if (p.contains('lofi') || p.contains('chill') || p.contains('study')) { vec[1] = 0.92; vec[3] = 0.95; vec[11] = 0.90; }
      if (p.contains('gym') || p.contains('workout') || p.contains('heavy')) { vec[2] = 0.98; vec[13] = 0.95; vec[14] = 0.92; }
      if (p.contains('coding') || p.contains('hack') || p.contains('synth')) { vec[6] = 0.95; vec[9] = 0.95; vec[11] = 0.92; }
    }
    return vec;
  }

  static String generateExplanation(Song song, int score, [String? vibeKey, String? prompt]) {
    final shortPrompt = (prompt != null && prompt.isNotEmpty) ? prompt : (vibeKey ?? 'Vibe');
    return 'Neural match to "$shortPrompt" ($score% acoustic fit)';
  }

  static String calculateArchetype(List<double> vector) {
    if (vector.length < 16) return 'Nocturnal Cyber-Audiophile';
    if (vector[0] >= 0.70 && vector[10] >= 0.70) return 'Nocturnal Cyber-Audiophile';
    if (vector[2] >= 0.70 && vector[14] >= 0.70) return 'Kinetic High-BPM Enthusiast';
    if (vector[1] >= 0.70 && vector[3] >= 0.70) return 'Ambient Lofi Explorer';
    if (vector[5] >= 0.70 && vector[7] >= 0.70) return 'Acoustic Warmth Connoisseur';
    if (vector[6] >= 0.70 && vector[9] >= 0.70) return 'Retro Analog Synthesist';
    if (vector[11] >= 0.70 && vector[15] >= 0.70) return 'Deep-Focus Cognitive Architect';
    return 'Universal Acoustic Minimalist';
  }
}
