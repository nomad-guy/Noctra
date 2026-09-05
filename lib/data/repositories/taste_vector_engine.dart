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
      dot += val1 * val2; mag1 += val1 * val1; mag2 += val2 * val2; valid++;
    }
    if (valid == 0 || mag1 == 0 || mag2 == 0) return 0.5;
    final double denom = sqrt(mag1) * sqrt(mag2);
    if (denom == 0 || denom.isNaN) return 0.5;
    return (dot / denom).clamp(0.0, 1.0);
  }

  static List<double> blendVectors(List<double> v1, List<double> v2, double w1) {
    final w2 = 1.0 - w1;
    final result = List<double>.filled(vectorDimension, 0.0);
    for (int i = 0; i < vectorDimension; i++) {
      final a = i < v1.length ? v1[i] : 0.5;
      final b = i < v2.length ? v2[i] : 0.5;
      result[i] = (a * w1 + b * w2).clamp(0.05, 0.95);
    }
    return result;
  }

  static List<double> applyTemporalDecay(List<double> current, {int daysElapsed = 14}) {
    final double factor = exp(-0.0495 * daysElapsed);
    final baseline = getDefaultVector();
    final res = List<double>.filled(vectorDimension, 0.5);
    for (int i = 0; i < vectorDimension; i++) {
      final cur = i < current.length ? current[i] : 0.5;
      res[i] = (baseline[i] + (cur - baseline[i]) * factor).clamp(0.05, 0.95);
    }
    return res;
  }

  static List<double> extractSongEmbedding(Song song) {
    return extractTextEmbedding('${song.title} ${song.artist} ${song.album} ${song.genre}');
  }

  static List<double> extractTextEmbedding(String rawText) {
    final text = rawText.toLowerCase();
    final vec = List<double>.from(getDefaultVector());
    void nudge(int axis, double target, double weight) {
      if (axis >= 0 && axis < vectorDimension) {
        vec[axis] = (vec[axis] * (1.0 - weight) + target * weight).clamp(0.05, 0.98);
      }
    }
    // Discern heavy/rock from dark ambient/synth
    if (text.contains('metal') || text.contains('heavy rock') || text.contains('hardcore') || text.contains('punk')) {
      nudge(0, 0.85, 0.40); nudge(2, 0.95, 0.45); nudge(14, 0.92, 0.40); nudge(21, 0.90, 0.35);
    } else if (text.contains('dark') || text.contains('night') || text.contains('black') || text.contains('shadow')) {
      nudge(0, 0.85, 0.35); nudge(10, 0.90, 0.40); nudge(13, 0.78, 0.35);
    }
    if (text.contains('hyper') || text.contains('energy') || text.contains('fast') || text.contains('drop') || text.contains('edm')) {
      nudge(2, 0.92, 0.40); nudge(14, 0.88, 0.35); nudge(12, 0.80, 0.35); nudge(21, 0.85, 0.35);
    }
    if (text.contains('chill') || text.contains('relax') || text.contains('ambient') || text.contains('lofi') || text.contains('sleep')) {
      nudge(1, 0.90, 0.40); nudge(3, 0.92, 0.40); nudge(11, 0.85, 0.35); nudge(18, 0.90, 0.40); nudge(2, 0.20, 0.35);
    }
    if (text.contains('acoustic') || text.contains('guitar') || text.contains('piano') || text.contains('unplugged') || text.contains('folk')) {
      nudge(5, 0.92, 0.45); nudge(6, 0.20, 0.35); nudge(7, 0.85, 0.35); nudge(25, 0.88, 0.40);
    }
    if (text.contains('synth') || text.contains('retro') || text.contains('cyber') || text.contains('electro') || text.contains('outrun')) {
      nudge(6, 0.92, 0.40); nudge(9, 0.95, 0.45); nudge(10, 0.88, 0.35); nudge(26, 0.90, 0.40); nudge(31, 0.88, 0.35);
    }
    if (text.contains('sufi') || text.contains('qawwali') || text.contains('nusrat') || text.contains('rahat')) {
      nudge(16, 0.95, 0.45); nudge(17, 0.90, 0.40); nudge(7, 0.90, 0.35);
    }
    if (text.contains('bollywood') || text.contains('arijit') || text.contains('pritam') || text.contains('shreya')) {
      nudge(19, 0.92, 0.45); nudge(7, 0.88, 0.35); nudge(8, 0.82, 0.35);
    }
    if (text.contains('hip hop') || text.contains('rap') || text.contains('trap') || text.contains('drake') || text.contains('kendrick')) {
      nudge(20, 0.92, 0.45); nudge(24, 0.88, 0.40); nudge(13, 0.85, 0.35);
    }
    if (text.contains('instrumental') || text.contains('soundtrack') || text.contains('score') || text.contains('orchestra')) {
      nudge(15, 0.92, 0.45); nudge(28, 0.88, 0.40); nudge(7, 0.20, 0.35);
    } else if (text.contains('feat') || text.contains('vocal') || text.contains('voice') || text.contains('singing')) {
      nudge(7, 0.88, 0.35); nudge(29, 0.85, 0.35); nudge(15, 0.25, 0.35);
    }
    if (text.contains('jazz') || text.contains('blues') || text.contains('swing')) {
      nudge(22, 0.92, 0.45); nudge(5, 0.85, 0.35);
    }
    if (text.contains('latin') || text.contains('salsa') || text.contains('reggaeton')) {
      nudge(27, 0.92, 0.45); nudge(14, 0.85, 0.35);
    }
    if (text.contains('phonk') || text.contains('slowed') || text.contains('reverb')) {
      nudge(31, 0.90, 0.40); nudge(0, 0.82, 0.35); nudge(10, 0.85, 0.35);
    }
    if (text.contains('punjabi') || text.contains('bhangra') || text.contains('diljit') || text.contains('sidhu')) {
      nudge(20, 0.88, 0.40); nudge(19, 0.78, 0.35); nudge(24, 0.82, 0.35);
    }
    if (text.contains('k-pop') || text.contains('kpop') || text.contains('bts') || text.contains('blackpink')) {
      nudge(12, 0.88, 0.40); nudge(7, 0.90, 0.40); nudge(6, 0.85, 0.35);
    }
    return vec;
  }

  // Natural-language prompt → axis delta map for precise vibe steering
  static Map<int, double> buildPromptModifier(String prompt) {
    final p = prompt.toLowerCase();
    final Map<int, double> deltas = {};
    void set(int axis, double delta) => deltas[axis] = (deltas[axis] ?? 0.0) + delta;

    if (p.contains('darker') || p.contains('more dark') || p.contains('darker vibe')) { set(0, 0.25); set(10, 0.20); set(12, -0.20); }
    if (p.contains('lighter') || p.contains('happier') || p.contains('upbeat') || p.contains('uplifting')) { set(12, 0.25); set(3, 0.15); set(0, -0.20); }
    if (p.contains('more energetic') || p.contains('higher energy') || p.contains('pump up')) { set(2, 0.25); set(14, 0.20); set(3, -0.15); }
    if (p.contains('calmer') || p.contains('less energetic') || p.contains('wind down') || p.contains('slow')) { set(3, 0.25); set(1, 0.20); set(2, -0.20); }
    if (p.contains('late-night') || p.contains('late night') || p.contains('midnight') || p.contains('night drive')) { set(10, 0.30); set(0, 0.20); set(1, 0.15); }
    if (p.contains('morning') || p.contains('sunrise') || p.contains('wake up')) { set(12, 0.25); set(3, 0.20); set(0, -0.15); }
    if (p.contains('focus') || p.contains('study') || p.contains('work') || p.contains('concentrate')) { set(11, 0.30); set(15, 0.20); set(2, -0.15); }
    if (p.contains('gym') || p.contains('workout') || p.contains('run') || p.contains('exercise')) { set(2, 0.30); set(14, 0.25); set(13, 0.20); }
    if (p.contains('more bollywood') || p.contains('bollywood') || p.contains('hindi') || p.contains('desi')) { set(19, 0.35); set(7, 0.20); }
    if (p.contains('more punjabi') || p.contains('punjabi')) { set(20, 0.25); set(19, 0.15); }
    if (p.contains('sufi') || p.contains('spiritual') || p.contains('qawwali')) { set(16, 0.35); set(17, 0.25); }
    if (p.contains('synthwave') || p.contains('retro') || p.contains('80s') || p.contains('outrun')) { set(9, 0.30); set(6, 0.25); set(26, 0.25); }
    if (p.contains('acoustic') || p.contains('unplugged') || p.contains('guitar')) { set(5, 0.30); set(6, -0.20); }
    if (p.contains('less popular') || p.contains('underground') || p.contains('deep cuts') || p.contains('hidden gems')) {
      // Popularity penalty handled in candidate retrieval, not the vector
    }
    if (p.contains('lofi') || p.contains('lo-fi') || p.contains('chill hop')) { set(18, 0.30); set(3, 0.25); set(11, 0.20); }
    if (p.contains('phonk') || p.contains('slowed') || p.contains('reverb')) { set(31, 0.30); set(0, 0.20); }
    if (p.contains('jazz') || p.contains('blues')) { set(22, 0.30); set(5, 0.20); }
    if (p.contains('electronic') || p.contains('edm') || p.contains('techno') || p.contains('house')) { set(6, 0.30); set(2, 0.20); set(14, 0.20); }
    if (p.contains('pop') || p.contains('mainstream')) { set(7, 0.20); set(12, 0.15); }
    if (p.contains('hip-hop') || p.contains('hip hop') || p.contains('rap')) { set(20, 0.30); set(24, 0.25); }
    return deltas;
  }

  static List<double> createVectorFromPreferences({required List<String> languages, required List<String> genres, required List<String> artists}) {
    final vec = List<double>.from(getDefaultVector());
    void nudge(int axis, double target, double weight) {
      if (axis >= 0 && axis < vectorDimension) vec[axis] = (vec[axis] * (1.0 - weight) + target * weight).clamp(0.05, 0.98);
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
      if (ll.contains('hindi') || ll.contains('urdu')) { nudge(19, 0.90, 0.6); nudge(16, 0.85, 0.5); }
      if (ll.contains('punjabi')) { nudge(20, 0.90, 0.6); nudge(24, 0.85, 0.5); }
      if (ll.contains('tamil') || ll.contains('telugu') || ll.contains('kannada') || ll.contains('malayalam')) { nudge(17, 0.92, 0.6); nudge(7, 0.90, 0.5); }
      if (ll.contains('marathi') || ll.contains('bengali') || ll.contains('gujarati') || ll.contains('odia')) { nudge(25, 0.90, 0.6); nudge(17, 0.85, 0.5); }
      if (ll.contains('spanish') || ll.contains('portuguese')) { nudge(27, 0.95, 0.7); nudge(14, 0.88, 0.5); }
      if (ll.contains('french') || ll.contains('german') || ll.contains('italian')) { nudge(5, 0.90, 0.6); nudge(8, 0.88, 0.5); }
      if (ll.contains('korean') || ll.contains('japanese')) { nudge(9, 0.90, 0.6); nudge(26, 0.88, 0.6); }
      if (ll.contains('arabic') || ll.contains('persian')) { nudge(16, 0.95, 0.7); nudge(17, 0.88, 0.5); }
    }
    return vec;
  }

  static List<double> selfHealAndRecalibrate(List<double> currentVector, {Song? lastSong, String eventType = 'listen'}) {
    final List<double> targetVector = lastSong == null
        ? getDefaultVector()
        : (lastSong.hasUsableEmbedding
            ? lastSong.featureVector
            : extractSongEmbedding(lastSong));
    final List<double> updated = List<double>.from(currentVector);
    while (updated.length < vectorDimension) {
      updated.add(0.5);
    }
    double alpha = 0.06;
    if (eventType == 'fast_skip') {
      alpha = -0.08;
    } else if (eventType == 'short_skip') {
      alpha = -0.04;
    } else if (eventType == 'complete_listen' || eventType == 'full_listen') {
      alpha = 0.12;
    } else if (eventType == 'favorite') {
      alpha = 0.18;
    } else if (eventType == 'replay') {
      alpha = 0.14;
    } else if (eventType == 'playlist_add') {
      alpha = 0.15;
    } else if (eventType == 'search_select') {
      alpha = 0.10;
    }
    for (int i = 0; i < vectorDimension && i < targetVector.length; i++) {
      final delta = (targetVector[i] - updated[i]) * alpha;
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
        case 'bollywood': vec[19] = 0.98; vec[7] = 0.90; vec[8] = 0.85; break;
        case 'acoustic_warm': vec[5] = 0.95; vec[7] = 0.88; vec[25] = 0.90; break;
        case 'late_night': vec[0] = 0.90; vec[10] = 0.95; vec[1] = 0.80; break;
        case 'discovery': vec[12] = 0.80; vec[3] = 0.75; break;
      }
    }
    if (prompt != null && prompt.isNotEmpty) {
      final modifiers = buildPromptModifier(prompt);
      for (final entry in modifiers.entries) {
        if (entry.key < vectorDimension) {
          vec[entry.key] = (vec[entry.key] + entry.value).clamp(0.05, 0.98);
        }
      }
    }
    return vec;
  }

  static String generateExplanation(Song song, int score, [String? vibeKey, String? prompt]) {
    if (prompt != null && prompt.isNotEmpty) {
      final p = prompt.toLowerCase();
      if (p.contains('bollywood') || p.contains('hindi')) return 'Matches your Bollywood taste';
      if (p.contains('night') || p.contains('dark')) return 'Perfect for late-night listening';
      if (p.contains('energy') || p.contains('gym')) return 'High-energy match for your request';
      if (p.contains('chill') || p.contains('relax')) return 'Relaxed vibe you asked for';
      return 'Matched to your request';
    }
    if (vibeKey == 'bollywood') return 'Top Bollywood match';
    if (vibeKey == 'noir_night' || vibeKey == 'late_night') return 'Late-night sonic atmosphere';
    if (vibeKey == 'high_energy') return 'Peak energy track';
    if (vibeKey == 'ambient_chill') return 'Calm, ambient listening';
    return 'Based on your taste';
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
    if (vector.length >= 20 && vector[19] >= 0.70) return 'Bollywood Sonic Connoisseur';
    if (vector.length >= 21 && vector[20] >= 0.70) return 'Hip-Hop & Street Curator';
    return 'Universal Acoustic Minimalist';
  }
}
