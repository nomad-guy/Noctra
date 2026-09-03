part of '../neural_recommender_engine.dart';

extension NeuralTrainingEngine on NeuralRecommenderEngine {
  static double predictScore({
    required List<double> userVector,
    required Song song,
    List<double>? contextFeatures,
    List<double>? audioFeatures,
    List<double>? temporalFeatures,
    List<double>? patternFeatures,
    List<double>? socialFeatures,
  }) {
    final songVec = song.hasUsableEmbedding
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    final input = NeuralFeatureBuilder.buildInput(
      userVector,
      songVec,
      contextFeatures,
      audioFeatures,
      temporalFeatures,
      patternFeatures,
      socialFeatures,
    );

    final h1 = forwardLayer(input, NeuralRecommenderEngine._w1, NeuralRecommenderEngine._b1);
    final h2 = forwardLayer(h1, NeuralRecommenderEngine._w2, NeuralRecommenderEngine._b2);
    final h3 = forwardLayer(h2, NeuralRecommenderEngine._w3, NeuralRecommenderEngine._b3);

    double out = NeuralRecommenderEngine._b4;
    for (int i = 0; i < NeuralRecommenderEngine.hidden3Dimension; i++) {
      out += NeuralRecommenderEngine._w4[i] * h3[i];
    }
    final double mlpScore = 1.0 / (1.0 + exp(-out.clamp(-10.0, 10.0)));

    final double cosine =
        TasteVectorEngine.cosineSimilarity(userVector, songVec);
    return (mlpScore * 0.55 + cosine * 0.45).clamp(0.01, 0.99);
  }

  static List<double> forwardLayer(
      List<double> input, List<List<double>> weights, List<double> bias) {
    final output = List<double>.filled(weights.length, 0.0);
    for (int i = 0; i < weights.length; i++) {
      double sum = bias[i];
      for (int j = 0; j < input.length && j < weights[i].length; j++) {
        sum += weights[i][j] * input[j];
      }
      output[i] = sum > 0 ? sum : sum * 0.1;
    }
    return output;
  }

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
    final songVec = song.hasUsableEmbedding
        ? song.featureVector
        : TasteVectorEngine.extractSongEmbedding(song);

    final input = NeuralFeatureBuilder.buildInput(
      userVector,
      songVec,
      contextFeatures,
      audioFeatures,
      temporalFeatures,
      patternFeatures,
      socialFeatures,
    );

    final h1 = forwardLayer(input, NeuralRecommenderEngine._w1, NeuralRecommenderEngine._b1);
    final h2 = forwardLayer(h1, NeuralRecommenderEngine._w2, NeuralRecommenderEngine._b2);
    final h3 = forwardLayer(h2, NeuralRecommenderEngine._w3, NeuralRecommenderEngine._b3);

    double out = NeuralRecommenderEngine._b4;
    for (int i = 0; i < NeuralRecommenderEngine.hidden3Dimension; i++) {
      out += NeuralRecommenderEngine._w4[i] * h3[i];
    }
    final double pred = 1.0 / (1.0 + exp(-out.clamp(-10.0, 10.0)));

    final double epsilon = 1e-7;
    final double loss = -(target * log(pred + epsilon) +
        (1 - target) * log(1 - pred + epsilon));

    final double dOut = pred - target;

    final dh3 = List<double>.filled(NeuralRecommenderEngine.hidden3Dimension, 0.0);
    for (int i = 0; i < NeuralRecommenderEngine.hidden3Dimension; i++) {
      dh3[i] = dOut * NeuralRecommenderEngine._w4[i];
      NeuralRecommenderEngine._w4[i] -=
          NeuralRecommenderEngine._learningRate * dOut * h3[i];
    }
    NeuralRecommenderEngine._b4 -= NeuralRecommenderEngine._learningRate * dOut;

    final dh2 = backwardLayer(h3, h2, dh3, NeuralRecommenderEngine._w3,
        NeuralRecommenderEngine._b3, NeuralRecommenderEngine._learningRate);

    final dh1 = backwardLayer(h2, h1, dh2, NeuralRecommenderEngine._w2,
        NeuralRecommenderEngine._b2, NeuralRecommenderEngine._learningRate);

    backwardLayerToInput(input, h1, dh1, NeuralRecommenderEngine._w1,
        NeuralRecommenderEngine._b1, NeuralRecommenderEngine._learningRate);

    NeuralRecommenderEngine._trainStep++;
    NeuralRecommenderEngine._runningLoss += loss;
    final bool correct =
        (pred >= 0.5 && target >= 0.5) || (pred < 0.5 && target < 0.5);
    NeuralRecommenderEngine._runningAccuracy =
        (NeuralRecommenderEngine._runningAccuracy * 0.99 +
            (correct ? 1.0 : 0.0) * 0.01);
    if (NeuralRecommenderEngine._trainStep % 50 == 0) {
      NeuralRecommenderEngine._lossHistory.add(loss);
    }
    if (NeuralRecommenderEngine._lossHistory.length > 100) {
      NeuralRecommenderEngine._lossHistory.removeAt(0);
    }
    if (NeuralRecommenderEngine._trainStep % 20 == 0) {
      NeuralModelWeights.persistState();
    }

    return loss;
  }

  static List<double> backwardLayer(
    List<double> output,
    List<double> input,
    List<double> dOutput,
    List<List<double>> weights,
    List<double> bias,
    double lr,
  ) {
    final dInput = List<double>.filled(input.length, 0.0);
    for (int i = 0; i < output.length; i++) {
      final double deriv = output[i] > 0 ? 1.0 : 0.1;
      for (int j = 0; j < input.length; j++) {
        dInput[j] += dOutput[i] * weights[i][j];
        weights[i][j] -= lr * dOutput[i] * deriv * input[j];
      }
      bias[i] -= lr * dOutput[i];
    }
    return dInput;
  }

  static void backwardLayerToInput(
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
}
