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

  /// Computes cosine similarity with full mathematical span [-1.0, 1.0] normalized to [0.0, 1.0]
  static double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty) return 0.5;
    final maxLen = max(v1.length, v2.length);
    double dot = 0.0, mag1 = 0.0, mag2 = 0.0;
    int validDimensions = 0;

    for (int i = 0; i < maxLen; i++) {
      final val1 = i < v1.length ? v1[i] : 0.5;
      final val2 = i < v2.length ? v2[i] : 0.5;
      if (val1.isNaN || val1.isInfinite || val2.isNaN || val2.isInfinite) continue;

      dot += val1 * val2;
      mag1 += val1 * val1;
      mag2 += val2 * val2;
      validDimensions++;
    }

    if (validDimensions == 0 || mag1 == 0 || mag2 == 0) return 0.5;
    final denom = sqrt(mag1) * sqrt(mag2);
    if (denom == 0 || denom.isNaN) return 0.5;

    final rawCosine = (dot / denom).clamp(-1.0, 1.0);
    // Maps raw cosine similarity from [-1.0, 1.0] to normalized [0.0, 1.0]
    return ((rawCosine + 1.0) / 2.0).clamp(0.0, 1.0);
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

    // Regularization decay to prevent dimensional saturation
    for (int i = 0; i < updated.length; i++) {
      if (updated[i] > 0.90) updated[i] -= 0.012;
      if (updated[i] < 0.10) updated[i] += 0.012;
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
        genre: '',
        featureVector: songVector,
      ),
      eventType: action,
    );
  }

  /// Context-aware target vector with prompt parsing
  static List<double> getTargetVector({String? vibeKey, String? prompt, required List<double> defaultTaste}) {
    if (vibeKey == 'noir_night' || vibeKey == 'late_night') {
      return [0.92, 0.75, 0.30, 0.85, 0.70, 0.20, 0.65, 0.50, 0.60, 0.85, 0.98, 0.75, 0.20, 0.80, 0.40, 0.50];
    } else if (vibeKey == 'retro_synth' || vibeKey == 'dark_synth') {
      return [0.85, 0.55, 0.85, 0.40, 0.50, 0.05, 0.98, 0.40, 0.50, 0.98, 0.95, 0.65, 0.35, 0.90, 0.80, 0.70];
    } else if (vibeKey == 'high_energy') {
      return [0.30, 0.10, 0.98, 0.10, 0.20, 0.10, 0.85, 0.70, 0.85, 0.75, 0.60, 0.40, 0.90, 0.75, 0.95, 0.30];
    } else if (vibeKey == 'deep_focus') {
      return [0.40, 0.85, 0.30, 0.90, 0.30, 0.40, 0.70, 0.15, 0.75, 0.70, 0.80, 0.98, 0.40, 0.50, 0.45, 0.90];
    } else if (vibeKey == 'ambient_chill') {
      return [0.35, 0.95, 0.20, 0.98, 0.40, 0.70, 0.50, 0.60, 0.40, 0.50, 0.75, 0.90, 0.50, 0.40, 0.30, 0.75];
    } else if (vibeKey == 'acoustic_warm') {
      return [0.20, 0.50, 0.40, 0.85, 0.40, 0.98, 0.05, 0.90, 0.30, 0.10, 0.40, 0.75, 0.60, 0.30, 0.45, 0.20];
    }

    if (prompt != null && prompt.isNotEmpty) {
      final p = prompt.toLowerCase();
      final vec = List<double>.from(defaultTaste.isNotEmpty ? defaultTaste : getDefaultVector());
      void nudge(int axis, double target, double weight) {
        if (axis >= 0 && axis < 16) {
          vec[axis] = (vec[axis] * (1.0 - weight) + target * weight).clamp(0.05, 0.98);
        }
      }

      if (p.contains('dark') || p.contains('night') || p.contains('noir')) {
        nudge(0, 0.95, 0.6); nudge(4, 0.80, 0.5); nudge(10, 0.95, 0.6); nudge(13, 0.85, 0.5);
      }
      if (p.contains('fast') || p.contains('energy') || p.contains('workout') || p.contains('hype')) {
        nudge(2, 0.95, 0.7); nudge(14, 0.92, 0.6); nudge(12, 0.85, 0.5);
      }
      if (p.contains('chill') || p.contains('study') || p.contains('sleep') || p.contains('calm') || p.contains('focus')) {
        nudge(3, 0.98, 0.7); nudge(11, 0.95, 0.7); nudge(1, 0.95, 0.6); nudge(5, 0.90, 0.5); nudge(2, 0.10, 0.5);
      }
      if (p.contains('synth') || p.contains('cyber') || p.contains('retro')) {
        nudge(6, 0.95, 0.6); nudge(9, 0.98, 0.7); nudge(10, 0.95, 0.6); nudge(13, 0.88, 0.5);
      }
      if (p.contains('acoustic') || p.contains('guitar') || p.contains('organic')) {
        nudge(5, 0.98, 0.7); nudge(7, 0.90, 0.6); nudge(15, 0.20, 0.5);
      }
      return vec;
    }

    return defaultTaste;
  }

  static String generateExplanation(Song song, int matchPercentage, String? vibeKey, String? prompt) {
    if (prompt != null && prompt.isNotEmpty) {
      final shortPrompt = prompt.length > 25 ? '${prompt.substring(0, 22)}...' : prompt;
      return 'Neural match to "$shortPrompt" ($matchPercentage% acoustic fit)';
    }
    if (vibeKey != null) {
      final clean = vibeKey.replaceAll('_', ' ').toUpperCase();
      return '$clean vector alignment with your listening habits ($matchPercentage%)';
    }
    return '16-axis harmonic resonance with your ${song.genre ?? "music"} profile ($matchPercentage%)';
  }

  /// Multi-Head Neural Archetype Classification
  static String calculateArchetype(List<double> vector) {
    final dark = vector.isNotEmpty ? vector[0] : 0.5;
    final ambient = vector.length > 1 ? vector[1] : 0.5;
    final energy = vector.length > 2 ? vector[2] : 0.5;
    final chill = vector.length > 3 ? vector[3] : 0.5;
    final acoustic = vector.length > 5 ? vector[5] : 0.5;
    final synth = vector.length > 9 ? vector[9] : 0.5;
    final nightDrive = vector.length > 10 ? vector[10] : 0.5;
    final subBass = vector.length > 13 ? vector[13] : 0.5;

    if (nightDrive >= 0.65 && synth >= 0.60) return 'Nocturnal Cyber-Audiophile';
    if (energy >= 0.70 && subBass >= 0.65) return 'High-Velocity Kinetic Flow';
    if (acoustic >= 0.65 && chill >= 0.55) return 'Organic Acoustic Realist';
    if (ambient >= 0.70 && chill >= 0.65) return 'Ambient Serenade Dreamer';
    if (dark >= 0.70 && subBass >= 0.70) return 'Obsidian Deep Sub-Bassist';
    if (synth >= 0.70) return 'Retro-Futurist Sound Architect';
    return 'Eclectic Noir Connoisseur';
  }
}
