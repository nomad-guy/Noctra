part of '../neural_recommender_engine.dart';

extension NeuralModelWeights on NeuralRecommenderEngine {
  static Future<void> doRestore() async {
    try {
      final state = await NoctraSqliteDatabase().loadNeuralModelState();
      if (state != null) {
        final restoredW1 = _restoreMatrix(state['w1'], NeuralRecommenderEngine._w1);
        final restoredW2 = _restoreMatrix(state['w2'], NeuralRecommenderEngine._w2);
        final restoredW3 = _restoreMatrix(state['w3'], NeuralRecommenderEngine._w3);

        if (restoredW1 && restoredW2) {
          if (restoredW3) {
            _restoreVector(state['b1'], NeuralRecommenderEngine._b1);
            _restoreVector(state['b2'], NeuralRecommenderEngine._b2);
            _restoreVector(state['b3'], NeuralRecommenderEngine._b3);
          }
          final w4Raw = state['w4'];
          if (w4Raw is List &&
              w4Raw.length == NeuralRecommenderEngine.hidden3Dimension) {
            _restoreVector(w4Raw, NeuralRecommenderEngine._w4);
          }
          NeuralRecommenderEngine._b4 =
              (state['b4'] as num?)?.toDouble() ?? NeuralRecommenderEngine._b4;
        }

        NeuralRecommenderEngine._trainStep =
            (state['trainStep'] as num?)?.toInt() ??
                NeuralRecommenderEngine._trainStep;
        NeuralRecommenderEngine._runningLoss =
            (state['runningLoss'] as num?)?.toDouble() ??
                NeuralRecommenderEngine._runningLoss;
        NeuralRecommenderEngine._runningAccuracy =
            (state['runningAccuracy'] as num?)?.toDouble() ??
                NeuralRecommenderEngine._runningAccuracy;
        NeuralRecommenderEngine._lossHistory
          ..clear()
          ..addAll((state['lossHistory'] as List? ?? [])
              .whereType<num>()
              .map((v) => v.toDouble())
              .take(100));
      }
    } catch (_) {
      // Inference remains available with deterministic cold-start model.
    } finally {
      NeuralRecommenderEngine._isRestored = true;
      NeuralRecommenderEngine._restoreFuture = null;
    }
  }

  static bool _restoreVector(dynamic raw, List<double> target) {
    if (raw is! List || raw.length != target.length) return false;
    if (raw.any((v) => v is! num)) return false;
    for (int i = 0; i < target.length; i++) {
      final v = (raw[i] as num).toDouble();
      if (!v.isFinite) return false;
      target[i] = v;
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

  static void persistState() {
    final snapshot = <String, dynamic>{
      'w1': NeuralRecommenderEngine._w1,
      'w2': NeuralRecommenderEngine._w2,
      'w3': NeuralRecommenderEngine._w3,
      'w4': List<double>.from(NeuralRecommenderEngine._w4),
      'b1': NeuralRecommenderEngine._b1,
      'b2': NeuralRecommenderEngine._b2,
      'b3': NeuralRecommenderEngine._b3,
      'b4': NeuralRecommenderEngine._b4,
      'trainStep': NeuralRecommenderEngine._trainStep,
      'runningLoss': NeuralRecommenderEngine._runningLoss,
      'runningAccuracy': NeuralRecommenderEngine._runningAccuracy,
      'lossHistory': List<double>.from(NeuralRecommenderEngine._lossHistory),
    };
    NeuralRecommenderEngine._pendingPersistence =
        NeuralRecommenderEngine._pendingPersistence
            .catchError((_) {})
            .then((_) => NoctraSqliteDatabase().saveNeuralModelState(snapshot));
    unawaited(NeuralRecommenderEngine._pendingPersistence);
  }
}
