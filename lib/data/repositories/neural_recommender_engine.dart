import 'dart:math';
import '../models/song_model.dart';
import 'taste_vector_engine.dart';

// NeuralRecommenderEngine: 88-dim input MLP.
// Input layout: [0..31] user vector, [32..63] track vector, [64..87] context (24 dims)
// Context dims: [64..67] time encoding, [68] weekend, [69] session count,
//               [70] late night, [71] early morning, [72..79] momentum features,
//               [80..87] artist/genre affinity features
class NeuralRecommenderEngine {
  static const int inputDimension = 88;
  static const int hidden1Dimension = 40;
  static const int hidden2Dimension = 20;
  static const double _learningRate = 0.002;

  // Xavier-initialized weights (better than sin/cos random)
  static final List<List<double>> _w1 = List.generate(
    hidden1Dimension,
    (i) => List.generate(inputDimension, (j) {
      final limit = sqrt(2.0 / inputDimension);
      return (sin(i * 1.7 + j * 0.43) * limit * 0.8);
    }),
  );
  static final List<double> _b1 = List.filled(hidden1Dimension, 0.01);

  static final List<List<double>> _w2 = List.generate(
    hidden2Dimension,
    (i) => List.generate(hidden1Dimension, (j) {
      final limit = sqrt(2.0 / hidden1Dimension);
      return (cos(i * 2.1 + j * 0.77) * limit * 0.8);
    }),
  );
  static final List<double> _b2 = List.filled(hidden2Dimension, 0.01);

  static final List<double> _w3 = List.generate(hidden2Dimension, (i) {
    final limit = sqrt(2.0 / hidden2Dimension);
    return (sin(i * 0.9) * limit * 0.8);
  });
  static double _b3 = 0.01;

  // Online SGD training stats
  static int _trainStep = 0;
  static double _runningLoss = 0.0;
  static double _runningAccuracy = 0.0;
  static final List<double> _lossHistory = [];
  static int get totalTrainSteps => _trainStep;
  static double get averageLoss => _trainStep > 0 ? _runningLoss / _trainStep : 0.0;
  static double get accuracy => _runningAccuracy;
  static List<double> get lossHistory => List.unmodifiable(_lossHistory);

  static double predictScore({
    required List<double> userVector,
    required Song song,
    List<double>? contextFeatures,
  }) {
    final songVec = song.featureVector.isNotEmpty && !song.featureVector.every((x) => x == 0.5)
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    final List<double> input = List<double>.filled(inputDimension, 0.5);
    for (int i = 0; i < 32 && i < userVector.length; i++) {
      input[i] = userVector[i];
    }
    for (int i = 0; i < 32 && i < songVec.length; i++) {
      input[32 + i] = songVec[i];
    }

    final ctx = contextFeatures ?? _buildDefaultContext();
    for (int i = 0; i < 24 && i < ctx.length; i++) {
      input[64 + i] = ctx[i];
    }

    // Forward pass Layer 1 (88 -> 40) with LeakyReLU
    final List<double> h1 = List<double>.filled(hidden1Dimension, 0.0);
    for (int i = 0; i < hidden1Dimension; i++) {
      double sum = _b1[i];
      for (int j = 0; j < inputDimension; j++) {
        sum += _w1[i][j] * input[j];
      }
      h1[i] = sum > 0 ? sum : sum * 0.1;
    }

    // Forward pass Layer 2 (40 -> 20) with LeakyReLU
    final List<double> h2 = List<double>.filled(hidden2Dimension, 0.0);
    for (int i = 0; i < hidden2Dimension; i++) {
      double sum = _b2[i];
      for (int j = 0; j < hidden1Dimension; j++) {
        sum += _w2[i][j] * h1[j];
      }
      h2[i] = sum > 0 ? sum : sum * 0.1;
    }

    // Forward pass Layer 3 (20 -> 1) with sigmoid
    double out = _b3;
    for (int i = 0; i < hidden2Dimension; i++) {
      out += _w3[i] * h2[i];
    }
    final double score = 1.0 / (1.0 + exp(-out.clamp(-10.0, 10.0)));
    final double cosine = TasteVectorEngine.cosineSimilarity(userVector, songVec);
    return (score * 0.55 + cosine * 0.45).clamp(0.01, 0.99);
  }

  /// Online SGD training step — call after each user interaction.
  /// [target] is the desired output (1.0 for liked, 0.0 for skipped).
  /// Returns the prediction error (loss) for monitoring.
  static double trainStep({
    required List<double> userVector,
    required Song song,
    required double target,
    List<double>? contextFeatures,
  }) {
    final songVec = song.featureVector.isNotEmpty && !song.featureVector.every((x) => x == 0.5)
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    // Build input
    final List<double> input = List<double>.filled(inputDimension, 0.5);
    for (int i = 0; i < 32 && i < userVector.length; i++) {
      input[i] = userVector[i];
    }
    for (int i = 0; i < 32 && i < songVec.length; i++) {
      input[32 + i] = songVec[i];
    }
    final ctx = contextFeatures ?? _buildDefaultContext();
    for (int i = 0; i < 24 && i < ctx.length; i++) {
      input[64 + i] = ctx[i];
    }

    // Forward pass with cached activations
    final List<double> h1 = List<double>.filled(hidden1Dimension, 0.0);
    for (int i = 0; i < hidden1Dimension; i++) {
      double sum = _b1[i];
      for (int j = 0; j < inputDimension; j++) {
        sum += _w1[i][j] * input[j];
      }
      h1[i] = sum > 0 ? sum : sum * 0.1; // LeakyReLU
    }

    final List<double> h2 = List<double>.filled(hidden2Dimension, 0.0);
    for (int i = 0; i < hidden2Dimension; i++) {
      double sum = _b2[i];
      for (int j = 0; j < hidden1Dimension; j++) {
        sum += _w2[i][j] * h1[j];
      }
      h2[i] = sum > 0 ? sum : sum * 0.1; // LeakyReLU
    }

    double out = _b3;
    for (int i = 0; i < hidden2Dimension; i++) {
      out += _w3[i] * h2[i];
    }
    final double pred = 1.0 / (1.0 + exp(-out.clamp(-10.0, 10.0)));

    // Binary cross-entropy loss
    final double epsilon = 1e-7;
    final double loss = -(target * log(pred + epsilon) + (1 - target) * log(1 - pred + epsilon));

    // Backward pass — sigmoid derivative
    final double dOut = pred - target; // d(sigmoid)/d(z) * d(BCE)/d(pred)

    // Layer 3 gradients
    final List<double> dh2 = List<double>.filled(hidden2Dimension, 0.0);
    for (int i = 0; i < hidden2Dimension; i++) {
      dh2[i] = dOut * _w3[i];
      _w3[i] -= _learningRate * dOut * h2[i];
    }
    _b3 -= _learningRate * dOut;

    // Layer 2 gradients (LeakyReLU derivative)
    final List<double> dh1 = List<double>.filled(hidden1Dimension, 0.0);
    for (int i = 0; i < hidden2Dimension; i++) {
      final double deriv = h2[i] > 0 ? 1.0 : 0.1;
      for (int j = 0; j < hidden1Dimension; j++) {
        dh1[j] += dh2[i] * _w2[i][j];
        _w2[i][j] -= _learningRate * dh2[i] * deriv * h1[j];
      }
      _b2[i] -= _learningRate * dh2[i] * deriv;
    }

    // Layer 1 gradients (LeakyReLU derivative)
    for (int i = 0; i < hidden1Dimension; i++) {
      final double deriv = h1[i] > 0 ? 1.0 : 0.1;
      for (int j = 0; j < inputDimension; j++) {
        _w1[i][j] -= _learningRate * dh1[i] * deriv * input[j];
      }
      _b1[i] -= _learningRate * dh1[i] * deriv;
    }

    // Track training stats
    _trainStep++;
    _runningLoss += loss;
    final bool correct = (pred >= 0.5 && target >= 0.5) || (pred < 0.5 && target < 0.5);
    _runningAccuracy = (_runningAccuracy * 0.99 + (correct ? 1.0 : 0.0) * 0.01);
    if (_trainStep % 50 == 0) _lossHistory.add(loss);
    if (_lossHistory.length > 100) _lossHistory.removeAt(0);

    return loss;
  }

  /// Convenience: train from an implicit signal (play/skip/favorite).
  static double trainFromSignal({
    required List<double> userVector,
    required Song song,
    required String eventType,
    List<double>? contextFeatures,
  }) {
    double target;
    switch (eventType) {
      case 'favorite': target = 1.0; break;
      case 'playlist_add': target = 0.95; break;
      case 'complete_listen': target = 0.85; break;
      case 'replay': target = 0.9; break;
      case 'deep_listen': target = 0.7; break;
      case 'search_select': target = 0.75; break;
      case 'partial_listen': target = 0.5; break;
      case 'short_skip': target = 0.2; break;
      case 'fast_skip': target = 0.05; break;
      default: target = 0.5;
    }
    return trainStep(userVector: userVector, song: song, target: target, contextFeatures: contextFeatures);
  }

  // Build 24-dim context vector from session data
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
      timePhase, timeCos, isWeekend, 0.5,             // [64..67] time
      sessionNorm, isLateNight, isEarlyMorning, 0.5,  // [68..71] session
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

  static List<double> _buildDefaultContext() => buildContext();
}
