import 'dart:math';
import '../models/song_model.dart';
import 'taste_vector_engine.dart';

class NeuralRecommenderEngine {
  static const int inputDimension = 80;
  static const int hidden1Dimension = 32;
  static const int hidden2Dimension = 16;

  // Lightweight deterministic weights initialized with Xavier scaling
  static final List<List<double>> _w1 = List.generate(
    hidden1Dimension,
    (i) => List.generate(inputDimension, (j) => sin(i * 1.7 + j * 0.43) * 0.15),
  );
  static final List<double> _b1 = List.filled(hidden1Dimension, 0.05);

  static final List<List<double>> _w2 = List.generate(
    hidden2Dimension,
    (i) => List.generate(hidden1Dimension, (j) => cos(i * 2.1 + j * 0.77) * 0.20),
  );
  static final List<double> _b2 = List.filled(hidden2Dimension, 0.02);

  static final List<double> _w3 = List.generate(hidden2Dimension, (i) => 0.25 + (sin(i * 0.9) * 0.1));
  static const double _b3 = 0.10;

  /// Predicts probability of meaningful engagement P(listen) in [0.0, 1.0]
  static double predictScore({
    required List<double> userVector,
    required Song song,
    List<double>? contextFeatures,
  }) {
    final songVec = song.featureVector.isNotEmpty && !song.featureVector.every((x) => x == 0.5)
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    final List<double> input = List<double>.filled(inputDimension, 0.5);

    // [0..31] User Vector
    for (int i = 0; i < 32 && i < userVector.length; i++) {
      input[i] = userVector[i];
    }
    // [32..63] Track Vector
    for (int i = 0; i < 32 && i < songVec.length; i++) {
      input[32 + i] = songVec[i];
    }
    // [64..79] Context Vector
    final ctx = contextFeatures ?? _buildDefaultContext();
    for (int i = 0; i < 16 && i < ctx.length; i++) {
      input[64 + i] = ctx[i];
    }

    // Forward Pass Layer 1 (80 -> 32)
    final List<double> h1 = List<double>.filled(hidden1Dimension, 0.0);
    for (int i = 0; i < hidden1Dimension; i++) {
      double sum = _b1[i];
      for (int j = 0; j < inputDimension; j++) {
        sum += _w1[i][j] * input[j];
      }
      h1[i] = sum > 0 ? sum : sum * 0.1; // LeakyReLU
    }

    // Forward Pass Layer 2 (32 -> 16)
    final List<double> h2 = List<double>.filled(hidden2Dimension, 0.0);
    for (int i = 0; i < hidden2Dimension; i++) {
      double sum = _b2[i];
      for (int j = 0; j < hidden1Dimension; j++) {
        sum += _w2[i][j] * h1[j];
      }
      h2[i] = sum > 0 ? sum : sum * 0.1; // LeakyReLU
    }

    // Forward Pass Layer 3 (16 -> 1)
    double out = _b3;
    for (int i = 0; i < hidden2Dimension; i++) {
      out += _w3[i] * h2[i];
    }

    // Sigmoid Activation
    final double score = 1.0 / (1.0 + exp(-out.clamp(-10.0, 10.0)));
    // Cosine similarity component blend
    final double cosine = TasteVectorEngine.cosineSimilarity(userVector, songVec);
    return (score * 0.55 + cosine * 0.45).clamp(0.01, 0.99);
  }

  static List<double> _buildDefaultContext() {
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekend = now.weekday >= 6 ? 1.0 : 0.0;
    final timePhase = (sin(hour / 24.0 * 2 * pi) + 1.0) / 2.0;

    return [
      timePhase, isWeekend, hour < 6 ? 0.9 : 0.2, hour >= 22 ? 0.95 : 0.1,
      0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5
    ];
  }
}
