import 'dart:async';
import 'dart:math';
import '../models/song_model.dart';
import '../sources/noctra_sqlite_database.dart';
import 'taste_vector_engine.dart';

/// NeuralRecommenderEngine v2: 120-dim input MLP with 3 hidden layers.
///
/// Input layout (120 dims):
///   [0..31]   user taste vector (32 dims)
///   [32..63]  track embedding vector (32 dims)
///   [64..87]  session context (24 dims — time, momentum, affinity)
///   [88..95]  audio features from metadata (8 dims):
///             [88] energy, [89] danceability, [90] valence,
///             [91] tempo_norm, [92] acousticness, [93] instrumentalness,
///             [94] speechiness, [95] liveness
///   [96..103] temporal features (8 dims):
///             [96] day_of_week_sin, [97] day_of_week_cos,
///             [98] month_sin, [99] month_cos,
///             [100] hour_sin, [101] hour_cos,
///             [102] is_weekend, [103] is_holiday_season
///   [104..111] listening pattern features (8 dims):
///              [104] avg_session_length_norm, [105] genre_diversity,
///              [106] artist_concentration, [107] skip_rate_recent,
///              [108] replay_ratio, [109] discovery_openness,
///              [110] time_spent_today_norm, [111] mood_shift_magnitude
///   [112..119] social/cross-platform features (8 dims):
///              [112] popularity_tier, [113] release_recency,
///              [114] chart_presence, [115] isrc_match_confidence,
///              [116] lyrics_availability, [117] audio_fingerprint_match,
///              [118] cross_platform_coverage, [119] metadata_quality
class NeuralRecommenderEngine {
  static const int inputDimension = 120;
  static const int hidden1Dimension = 64;
  static const int hidden2Dimension = 32;
  static const int hidden3Dimension = 16;
  static const double _learningRate = 0.001;
  // Xavier-initialized weights for 4-layer MLP
  // Layer 1: 120 → 64
  static final List<List<double>> _w1 = List.generate(
    hidden1Dimension,
    (i) => List.generate(inputDimension, (j) {
      final limit = sqrt(2.0 / inputDimension);
      return (sin(i * 1.7 + j * 0.43) * limit * 0.8);
    }),
  );
  static final List<double> _b1 = List.filled(hidden1Dimension, 0.01);

  // Layer 2: 64 → 32
  static final List<List<double>> _w2 = List.generate(
    hidden2Dimension,
    (i) => List.generate(hidden1Dimension, (j) {
      final limit = sqrt(2.0 / hidden1Dimension);
      return (cos(i * 2.1 + j * 0.77) * limit * 0.8);
    }),
  );
  static final List<double> _b2 = List.filled(hidden2Dimension, 0.01);

  // Layer 3: 32 → 16
  static final List<List<double>> _w3 = List.generate(
    hidden3Dimension,
    (i) => List.generate(hidden2Dimension, (j) {
      final limit = sqrt(2.0 / hidden2Dimension);
      return (sin(i * 1.3 + j * 0.59) * limit * 0.8);
    }),
  );
  static final List<double> _b3 = List.filled(hidden3Dimension, 0.01);

  // Layer 4 (output): 16 → 1
  static final List<double> _w4 = List.generate(hidden3Dimension, (i) {
    final limit = sqrt(2.0 / hidden3Dimension);
    return (cos(i * 0.8) * limit * 0.8);
  });
  static double _b4 = 0.01;

  // Online SGD training stats
  static int _trainStep = 0;
  static double _runningLoss = 0.0;
  static double _runningAccuracy = 0.0;
  static final List<double> _lossHistory = [];
  static bool _isRestored = false;
  static Future<void>? _restoreFuture;
  static Future<void> _pendingPersistence = Future.value();

  static int get totalTrainSteps => _trainStep;
  static double get averageLoss =>
      _trainStep > 0 ? _runningLoss / _trainStep : 0.0;
  static double get accuracy => _runningAccuracy;
  static List<double> get lossHistory => List.unmodifiable(_lossHistory);

  /// Restore learned weights from SQLite. Corrupted data self-heals to defaults.
  static Future<void> restoreFromDatabase() {
    if (_isRestored) return Future.value();
    return _restoreFuture ??= _doRestore();
  }

  static Future<void> _doRestore() async {
    try {
      final state = await NoctraSqliteDatabase().loadNeuralModelState();
      if (state != null) {
        // Self-healing: accept v2 (120-dim) or v1 (88-dim) weights
        final restoredW1 = _restoreMatrix(state['w1'], _w1);
        final restoredW2 = _restoreMatrix(state['w2'], _w2);
        final restoredW3 = _restoreMatrix(state['w3'], _w3);

        if (restoredW1 && restoredW2) {
          if (restoredW3) {
            _restoreVector(state['b1'], _b1);
            _restoreVector(state['b2'], _b2);
            _restoreVector(state['b3'], _b3);
          }
          // Try v2 output layer
          final w4Raw = state['w4'];
          if (w4Raw is List && w4Raw.length == hidden3Dimension) {
            _restoreVector(w4Raw, _w4);
          }
          _b4 = (state['b4'] as num?)?.toDouble() ?? _b4;
        }

        _trainStep = (state['trainStep'] as num?)?.toInt() ?? _trainStep;
        _runningLoss =
            (state['runningLoss'] as num?)?.toDouble() ?? _runningLoss;
        _runningAccuracy =
            (state['runningAccuracy'] as num?)?.toDouble() ?? _runningAccuracy;
        _lossHistory
          ..clear()
          ..addAll((state['lossHistory'] as List? ?? [])
              .whereType<num>()
              .map((v) => v.toDouble())
              .take(100));
      }
    } catch (_) {
      // Inference remains available with deterministic cold-start model.
    } finally {
      _isRestored = true;
      _restoreFuture = null;
    }
  }

  static bool _restoreVector(dynamic raw, List<double> target) {
    if (raw is! List || raw.any((v) => v is! num)) return false;
    final len = min(raw.length, target.length);
    for (int i = 0; i < len; i++) {
      target[i] = (raw[i] as num).toDouble();
    }
    return true;
  }

  static bool _restoreMatrix(dynamic raw, List<List<double>> target) {
    if (raw is! List || raw.length != target.length) return false;
    for (int i = 0; i < target.length; i++) {
      if (!_restoreVector(raw[i], target[i])) return false;
    }
    return true;
  }

  static void _persistState() {
    final snapshot = <String, dynamic>{
      'w1': _w1,
      'w2': _w2,
      'w3': _w3,
      'w4': List<double>.from(_w4),
      'b1': _b1,
      'b2': _b2,
      'b3': _b3,
      'b4': _b4,
      'trainStep': _trainStep,
      'runningLoss': _runningLoss,
      'runningAccuracy': _runningAccuracy,
      'lossHistory': List<double>.from(_lossHistory),
    };
    _pendingPersistence = _pendingPersistence
        .catchError((_) {})
        .then((_) => NoctraSqliteDatabase().saveNeuralModelState(snapshot));
    unawaited(_pendingPersistence);
  }

  /// Forward pass through the 4-layer MLP.
  static double predictScore({
    required List<double> userVector,
    required Song song,
    List<double>? contextFeatures,
    List<double>? audioFeatures,
    List<double>? temporalFeatures,
    List<double>? patternFeatures,
    List<double>? socialFeatures,
  }) {
    final songVec = song.featureVector.isNotEmpty &&
            !song.featureVector.every((x) => x == 0.5)
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    final input = _buildInput(
      userVector, songVec, contextFeatures,
      audioFeatures, temporalFeatures, patternFeatures, socialFeatures,
    );

    // Layer 1: 120 → 64 (LeakyReLU)
    final h1 = _forwardLayer(input, _w1, _b1);

    // Layer 2: 64 → 32 (LeakyReLU)
    final h2 = _forwardLayer(h1, _w2, _b2);

    // Layer 3: 32 → 16 (LeakyReLU)
    final h3 = _forwardLayer(h2, _w3, _b3);

    // Output: 16 → 1 (sigmoid)
    double out = _b4;
    for (int i = 0; i < hidden3Dimension; i++) {
      out += _w4[i] * h3[i];
    }
    final double mlpScore = 1.0 / (1.0 + exp(-out.clamp(-10.0, 10.0)));

    // Blend MLP score with cosine similarity
    final double cosine =
        TasteVectorEngine.cosineSimilarity(userVector, songVec);
    return (mlpScore * 0.55 + cosine * 0.45).clamp(0.01, 0.99);
  }

  /// Build 120-dim input vector from all feature sources.
  static List<double> _buildInput(
    List<double> userVec,
    List<double> songVec,
    List<double>? ctx,
    List<double>? audio,
    List<double>? temporal,
    List<double>? pattern,
    List<double>? social,
  ) {
    final input = List<double>.filled(inputDimension, 0.5);

    // [0..31] user vector
    for (int i = 0; i < 32 && i < userVec.length; i++) {
      input[i] = userVec[i];
    }
    // [32..63] song vector
    for (int i = 0; i < 32 && i < songVec.length; i++) {
      input[32 + i] = songVec[i];
    }
    // [64..87] context (24 dims)
    final context = ctx ?? buildContext();
    for (int i = 0; i < 24 && i < context.length; i++) {
      input[64 + i] = context[i];
    }
    // [88..95] audio features
    final audioFeats = audio ?? List.filled(8, 0.5);
    for (int i = 0; i < 8 && i < audioFeats.length; i++) {
      input[88 + i] = audioFeats[i];
    }
    // [96..103] temporal features
    final tempFeats = temporal ?? _buildTemporalFeatures();
    for (int i = 0; i < 8 && i < tempFeats.length; i++) {
      input[96 + i] = tempFeats[i];
    }
    // [104..111] pattern features
    final patFeats = pattern ?? List.filled(8, 0.5);
    for (int i = 0; i < 8 && i < patFeats.length; i++) {
      input[104 + i] = patFeats[i];
    }
    // [112..119] social/cross-platform features
    final socFeats = social ?? List.filled(8, 0.5);
    for (int i = 0; i < 8 && i < socFeats.length; i++) {
      input[112 + i] = socFeats[i];
    }

    return input;
  }

  /// Build temporal features from current time.
  static List<double> _buildTemporalFeatures() {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday; // 1=Mon, 7=Sun
    final month = now.month;

    return [
      sin(dayOfWeek / 7.0 * 2 * pi),       // [96] day_of_week_sin
      cos(dayOfWeek / 7.0 * 2 * pi),       // [97] day_of_week_cos
      sin(month / 12.0 * 2 * pi),           // [98] month_sin
      cos(month / 12.0 * 2 * pi),           // [99] month_cos
      sin(hour / 24.0 * 2 * pi),            // [100] hour_sin
      cos(hour / 24.0 * 2 * pi),            // [101] hour_cos
      dayOfWeek >= 6 ? 1.0 : 0.0,           // [102] is_weekend
      (month == 12 || month == 1) ? 1.0 : 0.0, // [103] is_holiday_season
    ];
  }

  /// Forward pass through a single layer with LeakyReLU.
  static List<double> _forwardLayer(
      List<double> input, List<List<double>> weights, List<double> bias) {
    final output = List<double>.filled(weights.length, 0.0);
    for (int i = 0; i < weights.length; i++) {
      double sum = bias[i];
      for (int j = 0; j < input.length && j < weights[i].length; j++) {
        sum += weights[i][j] * input[j];
      }
      output[i] = sum > 0 ? sum : sum * 0.1; // LeakyReLU
    }
    return output;
  }

  /// Online SGD training step — call after each user interaction.
  static double trainStep({
    required List<double> userVector,
    required Song song,
    required double target,
    List<double>? contextFeatures,
    List<double>? audioFeatures,
    List<double>? temporalFeatures,
    List<double>? patternFeatures,
    List<double>? socialFeatures,
  }) {
    final songVec = song.featureVector.isNotEmpty &&
            !song.featureVector.every((x) => x == 0.5)
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    final input = _buildInput(
      userVector, songVec, contextFeatures,
      audioFeatures, temporalFeatures, patternFeatures, socialFeatures,
    );

    // Forward pass — cache activations for backprop
    final h1 = _forwardLayer(input, _w1, _b1);
    final h2 = _forwardLayer(h1, _w2, _b2);
    final h3 = _forwardLayer(h2, _w3, _b3);

    double out = _b4;
    for (int i = 0; i < hidden3Dimension; i++) {
      out += _w4[i] * h3[i];
    }
    final double pred = 1.0 / (1.0 + exp(-out.clamp(-10.0, 10.0)));

    // Binary cross-entropy loss
    final double epsilon = 1e-7;
    final double loss = -(target * log(pred + epsilon) +
        (1 - target) * log(1 - pred + epsilon));

    // Backward pass
    final double dOut = pred - target;

    // Layer 4 gradients (output → h3)
    final dh3 = List<double>.filled(hidden3Dimension, 0.0);
    for (int i = 0; i < hidden3Dimension; i++) {
      dh3[i] = dOut * _w4[i];
      _w4[i] -= _learningRate * dOut * h3[i];
    }
    _b4 -= _learningRate * dOut;

    // Layer 3 gradients (h3 → h2)
    final dh2 = _backwardLayer(h3, h2, dh3, _w3, _b3, _learningRate);

    // Layer 2 gradients (h2 → h1)
    final dh1 = _backwardLayer(h2, h1, dh2, _w2, _b2, _learningRate);

    // Layer 1 gradients (h1 → input)
    _backwardLayerToInput(input, h1, dh1, _w1, _b1, _learningRate);

    // Track training stats
    _trainStep++;
    _runningLoss += loss;
    final bool correct =
        (pred >= 0.5 && target >= 0.5) || (pred < 0.5 && target < 0.5);
    _runningAccuracy = (_runningAccuracy * 0.99 + (correct ? 1.0 : 0.0) * 0.01);
    if (_trainStep % 50 == 0) _lossHistory.add(loss);
    if (_lossHistory.length > 100) _lossHistory.removeAt(0);
    if (_trainStep % 20 == 0) _persistState();

    return loss;
  }

  /// Backprop through a hidden layer, returning gradient for previous layer.
  static List<double> _backwardLayer(
    List<double> output,
    List<double> input,
    List<double> dOutput,
    List<List<double>> weights,
    List<double> bias,
    double lr,
  ) {
    final dInput = List<double>.filled(input.length, 0.0);
    for (int i = 0; i < output.length; i++) {
      final double deriv = output[i] > 0 ? 1.0 : 0.1; // LeakyReLU
      for (int j = 0; j < input.length; j++) {
        dInput[j] += dOutput[i] * weights[i][j];
        weights[i][j] -= lr * dOutput[i] * deriv * input[j];
      }
      bias[i] -= lr * dOutput[i];
    }
    return dInput;
  }

  /// Backprop to input layer.
  static void _backwardLayerToInput(
    List<double> input,
    List<double> output,
    List<double> dOutput,
    List<List<double>> weights,
    List<double> bias,
    double lr,
  ) {
    for (int i = 0; i < output.length; i++) {
      final double deriv = output[i] > 0 ? 1.0 : 0.1;
      for (int j = 0; j < input.length; j++) {
        weights[i][j] -= lr * dOutput[i] * deriv * input[j];
      }
      bias[i] -= lr * dOutput[i];
    }
  }

  /// Convenience: train from implicit signal.
  static double trainFromSignal({
    required List<double> userVector,
    required Song song,
    required String eventType,
    List<double>? contextFeatures,
    List<double>? audioFeatures,
    List<double>? temporalFeatures,
    List<double>? patternFeatures,
    List<double>? socialFeatures,
  }) {
    double target;
    switch (eventType) {
      case 'favorite':
        target = 1.0;
        break;
      case 'playlist_add':
        target = 0.95;
        break;
      case 'download':
        target = 0.9;
        break;
      case 'complete_listen':
        target = 0.85;
        break;
      case 'replay':
        target = 0.9;
        break;
      case 'deep_listen':
        target = 0.7;
        break;
      case 'search_select':
        target = 0.75;
        break;
      case 'partial_listen':
        target = 0.5;
        break;
      case 'short_skip':
        target = 0.2;
        break;
      case 'fast_skip':
        target = 0.05;
        break;
      default:
        target = 0.5;
    }
    return trainStep(
      userVector: userVector,
      song: song,
      target: target,
      contextFeatures: contextFeatures,
      audioFeatures: audioFeatures,
      temporalFeatures: temporalFeatures,
      patternFeatures: patternFeatures,
      socialFeatures: socialFeatures,
    );
  }

  /// Build 24-dim session context vector.
  static List<double> buildContext({
    int sessionSongCount = 0,
    List<double>? momentumFeatures,
    List<double>? affinityFeatures,
  }) {
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekend = now.weekday >= 6 ? 1.0 : 0.0;
    final timePhase = (sin(hour / 24.0 * 2 * pi) + 1.0) / 2.0;
    final timeCos = (cos(hour / 24.0 * 2 * pi) + 1.0) / 2.0;
    final sessionNorm = (sessionSongCount / 20.0).clamp(0.0, 1.0);
    final isLateNight = hour >= 22 || hour < 4 ? 1.0 : 0.0;
    final isEarlyMorning = hour >= 5 && hour < 9 ? 0.8 : 0.0;

    final ctx = <double>[
      timePhase, timeCos, isWeekend, 0.5, // [64..67] time
      sessionNorm, isLateNight, isEarlyMorning, 0.5, // [68..71] session
    ];

    // [72..79] momentum features (8 dims)
    final momentum = momentumFeatures ?? List.filled(8, 0.5);
    for (int i = 0; i < 8; i++) {
      ctx.add(i < momentum.length ? momentum[i] : 0.5);
    }

    // [80..87] affinity features (8 dims)
    final affinity = affinityFeatures ?? List.filled(8, 0.5);
    for (int i = 0; i < 8; i++) {
      ctx.add(i < affinity.length ? affinity[i] : 0.5);
    }

    return ctx;
  }

  /// Build audio features from song metadata (8 dims).
  /// Maps to [88..95] in the input vector.
  static List<double> buildAudioFeatures({
    double energy = 0.5,
    double danceability = 0.5,
    double valence = 0.5,
    double tempo = 120.0,
    double acousticness = 0.5,
    double instrumentalness = 0.5,
    double speechiness = 0.5,
    double liveness = 0.5,
  }) {
    return [
      energy.clamp(0.0, 1.0),
      danceability.clamp(0.0, 1.0),
      valence.clamp(0.0, 1.0),
      (tempo / 200.0).clamp(0.0, 1.0), // normalize tempo to [0,1]
      acousticness.clamp(0.0, 1.0),
      instrumentalness.clamp(0.0, 1.0),
      speechiness.clamp(0.0, 1.0),
      liveness.clamp(0.0, 1.0),
    ];
  }

  /// Build listening pattern features from history (8 dims).
  /// Maps to [104..111] in the input vector.
  static List<double> buildPatternFeatures({
    double avgSessionLength = 10.0,
    double genreDiversity = 0.5,
    double artistConcentration = 0.5,
    double skipRate = 0.3,
    double replayRatio = 0.5,
    double discoveryOpenness = 0.5,
    double timeSpentToday = 30.0,
    double moodShift = 0.3,
  }) {
    return [
      (avgSessionLength / 30.0).clamp(0.0, 1.0),
      genreDiversity.clamp(0.0, 1.0),
      artistConcentration.clamp(0.0, 1.0),
      skipRate.clamp(0.0, 1.0),
      replayRatio.clamp(0.0, 1.0),
      discoveryOpenness.clamp(0.0, 1.0),
      (timeSpentToday / 120.0).clamp(0.0, 1.0),
      moodShift.clamp(0.0, 1.0),
    ];
  }

  /// Build social/cross-platform features (8 dims).
  /// Maps to [112..119] in the input vector.
  static List<double> buildSocialFeatures({
    double popularityTier = 0.5,
    double releaseRecency = 0.5,
    double chartPresence = 0.0,
    double isrcMatchConfidence = 0.5,
    double lyricsAvailability = 0.5,
    double audioFingerprintMatch = 0.0,
    double crossPlatformCoverage = 0.5,
    double metadataQuality = 0.5,
  }) {
    return [
      popularityTier.clamp(0.0, 1.0),
      releaseRecency.clamp(0.0, 1.0),
      chartPresence.clamp(0.0, 1.0),
      isrcMatchConfidence.clamp(0.0, 1.0),
      lyricsAvailability.clamp(0.0, 1.0),
      audioFingerprintMatch.clamp(0.0, 1.0),
      crossPlatformCoverage.clamp(0.0, 1.0),
      metadataQuality.clamp(0.0, 1.0),
    ];
  }
}
