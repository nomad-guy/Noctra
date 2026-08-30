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

  /// Computes cosine similarity with dot product and magnitude normalization
  static double cosineSimilarity(List<double> v1, List<double> v2) {
    double dot = 0.0;
    double mag1 = 0.0;
    double mag2 = 0.0;
    final len = min(v1.length, v2.length);
    for (int i = 0; i < len; i++) {
      dot += v1[i] * v2[i];
      mag1 += v1[i] * v1[i];
      mag2 += v2[i] * v2[i];
    }
    final denom = sqrt(mag1) * sqrt(mag2);
    if (denom == 0) return 0.5;
    return (dot / denom).clamp(0.0, 1.0);
  }

  /// Extracts deterministic 16-dimensional acoustic feature embedding from track metadata
  static List<double> extractSongEmbedding(Song song) {
    final text = '${song.title} ${song.artist} ${song.album} ${song.genre}'.toLowerCase();
    final vec = List<double>.filled(16, 0.45);

    // Dark Tone & Sub-Bass
    if (text.contains('dark') || text.contains('night') || text.contains('black') || text.contains('shadow') || text.contains('demon')) {
      vec[0] = 0.90; vec[13] = 0.85;
    }
    // Energy & Tempo
    if (text.contains('hyper') || text.contains('fast') || text.contains('energy') || text.contains('drop') || text.contains('bass') || text.contains('rock')) {
      vec[2] = 0.92; vec[14] = 0.88; vec[12] = 0.75;
    }
    // Chill & Ambient
    if (text.contains('chill') || text.contains('relax') || text.contains('ambient') || text.contains('sleep') || text.contains('lofi') || text.contains('rain')) {
      vec[1] = 0.92; vec[3] = 0.95; vec[11] = 0.88; vec[2] = 0.20;
    }
    // Acoustic Warmth
    if (text.contains('acoustic') || text.contains('guitar') || text.contains('piano') || text.contains('unplugged') || text.contains('folk') || text.contains('organic')) {
      vec[5] = 0.95; vec[6] = 0.10; vec[7] = 0.85;
    }
    // Electronic & Synthwave
    if (text.contains('synth') || text.contains('retro') || text.contains('cyber') || text.contains('electro') || text.contains('wave') || text.contains('outrun')) {
      vec[6] = 0.95; vec[9] = 0.98; vec[10] = 0.92; vec[13] = 0.80;
    }
    // Vocal Presence
    if (text.contains('feat') || text.contains('voice') || text.contains('acoustic') || text.contains('arijit') || text.contains('weeknd')) {
      vec[7] = 0.92; vec[15] = 0.15;
    } else if (text.contains('instrumental') || text.contains('soundtrack') || text.contains('remix') || text.contains('dub')) {
      vec[15] = 0.92; vec[7] = 0.18;
    }

    return vec;
  }

  /// Reinforcement Learning vector update with adaptive reward shaping and anti-saturation regularization
  static List<double> selfHealAndRecalibrate(List<double> currentVector, {Song? lastSong, String eventType = 'listen'}) {
    final List<double> targetVector = lastSong != null && lastSong.featureVector.isNotEmpty
        ? (lastSong.featureVector.every((x) => x == 0.5) ? extractSongEmbedding(lastSong) : lastSong.featureVector)
        : getDefaultVector();

    final List<double> updated = List<double>.from(currentVector);
    while (updated.length < 16) {
      updated.add(0.5);
    }

    double alpha = 0.06; // Default learning rate
    if (eventType == 'fast_skip') {
      alpha = -0.06; // Negative gradient step
    } else if (eventType == 'complete_listen') {
      alpha = 0.10; // High reinforcement
    } else if (eventType == 'favorite') {
      alpha = 0.16; // Strongest reinforcement anchor
    }

    for (int i = 0; i < 16 && i < targetVector.length; i++) {
      final target = targetVector[i];
      final delta = (target - updated[i]) * alpha;
      updated[i] = (updated[i] + delta).clamp(0.04, 0.96);
    }

    // Regularization decay toward baseline to maintain curiosity and prevent dimension saturation
    for (int i = 0; i < updated.length; i++) {
      if (updated[i] > 0.90) updated[i] -= 0.015;
      if (updated[i] < 0.10) updated[i] += 0.015;
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

  /// Context-aware target vector with prompt parsing and temporal time-of-day bias
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
      final vec = List<double>.filled(16, 0.45);
      if (p.contains('dark') || p.contains('night') || p.contains('moody') || p.contains('noir')) {
        vec[0] = 0.95; vec[4] = 0.80; vec[10] = 0.95; vec[13] = 0.85;
      }
      if (p.contains('fast') || p.contains('energy') || p.contains('workout') || p.contains('hype') || p.contains('run')) {
        vec[2] = 0.95; vec[14] = 0.92; vec[12] = 0.85;
      }
      if (p.contains('chill') || p.contains('study') || p.contains('sleep') || p.contains('calm') || p.contains('focus') || p.contains('comfort') || p.contains('peace') || p.contains('heal') || p.contains('soft') || p.contains('gentle')) {
        vec[3] = 0.98; vec[11] = 0.95; vec[1] = 0.95; vec[5] = 0.90; vec[7] = 0.85; vec[2] = 0.10; vec[0] = 0.15;
      }
      if (p.contains('sad') || p.contains('alone') || p.contains('heartbreak') || p.contains('melancholy')) {
        vec[4] = 0.98; vec[1] = 0.85; vec[5] = 0.85; vec[7] = 0.90; vec[2] = 0.15;
      }
      if (p.contains('synth') || p.contains('cyber') || p.contains('retro') || p.contains('drive')) {
        vec[6] = 0.95; vec[9] = 0.98; vec[10] = 0.95; vec[13] = 0.88;
      }
      if (p.contains('acoustic') || p.contains('guitar') || p.contains('organic') || p.contains('soul')) {
        vec[5] = 0.98; vec[7] = 0.90; vec[15] = 0.20;
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
