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

  static final List<List<double>> _w1 = List.generate(
    hidden1Dimension,
    (i) => List.generate(inputDimension, (j) => sin(i * 1.7 + j * 0.43) * 0.14),
  );
  static final List<double> _b1 = List.filled(hidden1Dimension, 0.04);

  static final List<List<double>> _w2 = List.generate(
    hidden2Dimension,
    (i) => List.generate(hidden1Dimension, (j) => cos(i * 2.1 + j * 0.77) * 0.18),
  );
  static final List<double> _b2 = List.filled(hidden2Dimension, 0.02);

  static final List<double> _w3 = List.generate(hidden2Dimension, (i) => 0.22 + (sin(i * 0.9) * 0.1));
  static const double _b3 = 0.08;

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
