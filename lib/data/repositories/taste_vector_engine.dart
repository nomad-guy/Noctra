import 'dart:math';
import '../models/song_model.dart';

class TasteVectorEngine {
  static const int vectorDimension = 32;

  static const List<String> axisNames = [
    'Dark Tone', 'Ambient Depth', 'Kinetic Energy', 'Chill Factor',
    'Melancholy', 'Acoustic Warmth', 'Electronic', 'Vocal Presence',
    'Harmonic Density', 'Analog Synth', 'Night Drive', 'Cognitive Focus',
    'Uplift', 'Sub-Bass Weight', 'Rhythm Tempo', 'Instrumental',
    'Sufi Spiritual', 'Classical Raga', 'Lo-Fi Texture', 'Bollywood Orchestral',
    'Hip-Hop Cadence', 'Rock Distortion', 'Jazz Chords', 'Psychedelic Space',
    'Trap Percussion', 'Folk Story', 'Retro 80s', 'Latin Groove',
    'Cinematic Score', 'Vocal Harmony', 'Minimal Pulse', 'Cyber Industrial'
  ];

  static List<double> getDefaultVector() => List<double>.filled(vectorDimension, 0.5);

  static double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.isEmpty || v2.isEmpty) return 0.5;
    final int n = min(min(v1.length, v2.length), vectorDimension);
    if (n == 0) return 0.5;

    double dot = 0.0, mag1 = 0.0, mag2 = 0.0;
    int valid = 0;

    for (int i = 0; i < n; i++) {
      final double val1 = v1[i], val2 = v2[i];
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

  static List<double> applyTemporalDecay(List<double> current, {int daysElapsed = 14}) {
    final double factor = exp(-0.0495 * daysElapsed);
    final baseline = getDefaultVector();
    final res = List<double>.filled(vectorDimension, 0.5);
    for (int i = 0; i < vectorDimension; i++) {
      final cur = i < current.length ? current[i] : 0.5;
      final base = baseline[i];
      res[i] = (base + (cur - base) * factor).clamp(0.05, 0.95);
    }
    return res;
  }

  static List<double> extractSongEmbedding(Song song) {
    final text = '${song.title} ${song.artist} ${song.album} ${song.genre}'.toLowerCase();
    final vec = List<double>.from(getDefaultVector());

    void nudge(int axis, double target, double weight) {
      if (axis >= 0 && axis < vectorDimension) {
        vec[axis] = (vec[axis] * (1.0 - weight) + target * weight).clamp(0.05, 0.98);
      }
    }

    if (text.contains('dark') || text.contains('night') || text.contains('black') || text.contains('shadow')) {
      nudge(0, 0.92, 0.6); nudge(10, 0.95, 0.7); nudge(13, 0.85, 0.5);
    }
    if (text.contains('hyper') || text.contains('energy') || text.contains('fast') || text.contains('rock') || text.contains('drop')) {
      nudge(2, 0.95, 0.7); nudge(14, 0.90, 0.6); nudge(12, 0.80, 0.5); nudge(21, 0.90, 0.6);
    }
    if (text.contains('chill') || text.contains('relax') || text.contains('ambient') || text.contains('lofi') || text.contains('sleep')) {
      nudge(1, 0.92, 0.6); nudge(3, 0.95, 0.7); nudge(11, 0.88, 0.6); nudge(18, 0.92, 0.6); nudge(2, 0.20, 0.5);
    }
    if (text.contains('acoustic') || text.contains('guitar') || text.contains('piano') || text.contains('unplugged') || text.contains('folk')) {
      nudge(5, 0.95, 0.8); nudge(6, 0.15, 0.7); nudge(7, 0.88, 0.5); nudge(25, 0.90, 0.7);
    }
    if (text.contains('synth') || text.contains('retro') || text.contains('cyber') || text.contains('electro') || text.contains('outrun')) {
      nudge(6, 0.95, 0.7); nudge(9, 0.98, 0.8); nudge(10, 0.92, 0.6); nudge(26, 0.95, 0.7); nudge(31, 0.90, 0.6);
    }
    if (text.contains('sufi') || text.contains('qawwali') || text.contains('nusrat') || text.contains('rahat')) {
      nudge(16, 0.98, 0.8); nudge(17, 0.92, 0.7); nudge(7, 0.95, 0.7);
    }
    if (text.contains('bollywood') || text.contains('arijit') || text.contains('pritam') || text.contains('shreya')) {
      nudge(19, 0.95, 0.8); nudge(7, 0.92, 0.6); nudge(8, 0.85, 0.5);
    }
    if (text.contains('hip hop') || text.contains('rap') || text.contains('trap') || text.contains('drake') || text.contains('kendrick')) {
      nudge(20, 0.95, 0.8); nudge(24, 0.92, 0.7); nudge(13, 0.88, 0.6);
    }
    if (text.contains('instrumental') || text.contains('soundtrack') || text.contains('score') || text.contains('orchestra')) {
      nudge(15, 0.95, 0.8); nudge(28, 0.92, 0.7); nudge(7, 0.15, 0.7);
    } else if (text.contains('feat') || text.contains('vocal') || text.contains('voice')) {
      nudge(7, 0.92, 0.6); nudge(29, 0.88, 0.6); nudge(15, 0.20, 0.6);
    }

    return vec;
  }

  static List<double> createVectorFromPreferences({
    required List<String> languages,
    required List<String> genres,
    required List<String> artists,
  }) {
    final vec = List<double>.from(getDefaultVector());
    void nudge(int axis, double target, double weight) {
      if (axis >= 0 && axis < vectorDimension) {
        vec[axis] = (vec[axis] * (1.0 - weight) + target * weight).clamp(0.05, 0.98);
      }
    }

    for (final g in genres) {
      final lg = g.toLowerCase();
      if (lg.contains('bollywood')) { nudge(19, 0.95, 0.8); nudge(7, 0.90, 0.7); }
      if (lg.contains('lo-fi') || lg.contains('lofi')) { nudge(1, 0.92, 0.7); nudge(18, 0.95, 0.8); }
      if (lg.contains('hip-hop') || lg.contains('hip hop')) { nudge(20, 0.95, 0.8); nudge(24, 0.92, 0.7); }
      if (lg.contains('synthwave')) { nudge(6, 0.95, 0.8); nudge(9, 0.98, 0.8); nudge(26, 0.95, 0.8); }
      if (lg.contains('acoustic')) { nudge(5, 0.95, 0.8); nudge(25, 0.90, 0.7); }
      if (lg.contains('pop')) { nudge(7, 0.95, 0.7); nudge(8, 0.90, 0.6); }
      if (lg.contains('edm')) { nudge(2, 0.95, 0.8); nudge(14, 0.92, 0.7); }
      if (lg.contains('sufi')) { nudge(16, 0.98, 0.8); nudge(17, 0.92, 0.8); }
      if (lg.contains('rock')) { nudge(21, 0.95, 0.8); nudge(2, 0.90, 0.7); }
      if (lg.contains('phonk')) { nudge(31, 0.95, 0.8); nudge(20, 0.92, 0.8); }
    }

    for (final a in artists) {
      final la = a.toLowerCase();
      if (la.contains('arijit') || la.contains('pritam') || la.contains('shreya')) { nudge(19, 0.95, 0.8); nudge(7, 0.92, 0.7); }
      if (la.contains('weeknd') || la.contains('midnight')) { nudge(6, 0.95, 0.8); nudge(9, 0.95, 0.8); nudge(0, 0.90, 0.7); }
      if (la.contains('sidhu') || la.contains('diljit') || la.contains('aujla') || la.contains('dhillon')) { nudge(20, 0.95, 0.8); nudge(24, 0.92, 0.8); }
      if (la.contains('swift') || la.contains('lipa') || la.contains('billie')) { nudge(7, 0.95, 0.8); nudge(8, 0.90, 0.7); }
      if (la.contains('drake') || la.contains('badshah')) { nudge(20, 0.95, 0.8); nudge(13, 0.90, 0.7); }
    }

    for (final l in languages) {
      final ll = l.toLowerCase();
      if (ll.contains('hindi') || ll.contains('urdu')) { nudge(19, 0.90, 0.6); }
      if (ll.contains('punjabi')) { nudge(20, 0.90, 0.6); }
      if (ll.contains('korean') || ll.contains('japanese')) { nudge(9, 0.90, 0.6); nudge(26, 0.88, 0.6); }
    }

    return vec;
  }

  static List<double> selfHealAndRecalibrate(List<double> currentVector, {Song? lastSong, String eventType = 'listen'}) {
    final List<double> targetVector = lastSong != null && lastSong.featureVector.isNotEmpty
        ? (lastSong.featureVector.every((x) => x == 0.5) ? extractSongEmbedding(lastSong) : lastSong.featureVector)
        : getDefaultVector();

    final List<double> updated = List<double>.from(currentVector);
    while (updated.length < vectorDimension) {
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

    for (int i = 0; i < vectorDimension && i < targetVector.length; i++) {
      final target = targetVector[i];
      final delta = (target - updated[i]) * alpha;
      updated[i] = (updated[i] + delta).clamp(0.05, 0.95);
    }

    return updated;
  }

  static List<double> updateVector({required List<double> current, required List<double> songVector, required String action}) {
    return selfHealAndRecalibrate(
      current,
      lastSong: Song(id: '', title: '', artist: '', album: '', artworkUrl: '', streamUrl: '', duration: Duration.zero, featureVector: songVector),
      eventType: action,
    );
  }

  static List<double> getTargetVector({String? vibeKey, String? prompt, List<double>? defaultTaste}) {
    final vec = List<double>.from(defaultTaste ?? getDefaultVector());
    if (vibeKey != null) {
      switch (vibeKey) {
        case 'noir_night': vec[0] = 0.95; vec[10] = 0.98; vec[13] = 0.85; break;
        case 'retro_synth': vec[6] = 0.98; vec[9] = 0.98; vec[26] = 0.95; break;
        case 'deep_focus': vec[11] = 0.95; vec[15] = 0.90; vec[2] = 0.35; break;
        case 'high_energy': vec[2] = 0.98; vec[14] = 0.95; vec[12] = 0.85; break;
        case 'ambient_chill': vec[1] = 0.95; vec[3] = 0.98; vec[18] = 0.90; break;
      }
    }
    if (prompt != null && prompt.isNotEmpty) {
      final p = prompt.toLowerCase();
      if (p.contains('lofi') || p.contains('chill') || p.contains('study')) { vec[1] = 0.92; vec[3] = 0.95; vec[18] = 0.90; }
      if (p.contains('gym') || p.contains('workout') || p.contains('heavy')) { vec[2] = 0.98; vec[13] = 0.95; vec[14] = 0.92; }
      if (p.contains('coding') || p.contains('hack') || p.contains('synth')) { vec[6] = 0.95; vec[9] = 0.95; vec[26] = 0.92; }
      if (p.contains('sufi') || p.contains('qawwali')) { vec[16] = 0.95; vec[17] = 0.90; }
      if (p.contains('bollywood') || p.contains('desi')) { vec[19] = 0.95; vec[7] = 0.90; }
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
    if (vector.length >= 20 && vector[16] >= 0.70) return 'Sufi & Meditative Mystic';
    return 'Universal Acoustic Minimalist';
  }
}
