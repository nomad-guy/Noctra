import 'dart:async';
import 'dart:math';
import '../models/song_model.dart';
import '../sources/noctra_sqlite_database.dart';
import 'taste_vector_engine.dart';

part 'parts/neural_model_weights.dart';
part 'parts/neural_feature_builder.dart';
part 'parts/neural_training_engine.dart';

class NeuralRecommenderEngine {
  static const int inputDimension = 120;
  static const int hidden1Dimension = 64;
  static const int hidden2Dimension = 32;
  static const int hidden3Dimension = 16;
  static const double _learningRate = 0.001;

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

  static final List<List<double>> _w3 = List.generate(
    hidden3Dimension,
    (i) => List.generate(hidden2Dimension, (j) {
      final limit = sqrt(2.0 / hidden2Dimension);
      return (sin(i * 1.3 + j * 0.59) * limit * 0.8);
    }),
  );
  static final List<double> _b3 = List.filled(hidden3Dimension, 0.01);

  static final List<double> _w4 = List.generate(hidden3Dimension, (i) {
    final limit = sqrt(2.0 / hidden3Dimension);
    return (cos(i * 0.8) * limit * 0.8);
  });
  static double _b4 = 0.01;

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

  static Future<void> restoreFromDatabase() {
    if (_isRestored) return Future.value();
    return _restoreFuture ??= NeuralModelWeights.doRestore();
  }

  static double predictScore({
    required List<double> userVector,
    required Song song,
    List<double>? contextFeatures,
    List<double>? audioFeatures,
    List<double>? temporalFeatures,
    List<double>? patternFeatures,
    List<double>? socialFeatures,
  }) =>
      NeuralTrainingEngine.predictScore(
        userVector: userVector,
        song: song,
        contextFeatures: contextFeatures,
        audioFeatures: audioFeatures,
        temporalFeatures: temporalFeatures,
        patternFeatures: patternFeatures,
        socialFeatures: socialFeatures,
      );

  static double trainStep({
    required List<double> userVector,
    required Song song,
    required double target,
    List<double>? contextFeatures,
    List<double>? audioFeatures,
    List<double>? temporalFeatures,
    List<double>? patternFeatures,
    List<double>? socialFeatures,
  }) =>
      NeuralTrainingEngine.trainStep(
        userVector: userVector,
        song: song,
        target: target,
        contextFeatures: contextFeatures,
        audioFeatures: audioFeatures,
        temporalFeatures: temporalFeatures,
        patternFeatures: patternFeatures,
        socialFeatures: socialFeatures,
      );

  static double trainFromSignal({
    required List<double> userVector,
    required Song song,
    required String eventType,
    List<double>? contextFeatures,
    List<double>? audioFeatures,
    List<double>? temporalFeatures,
    List<double>? patternFeatures,
    List<double>? socialFeatures,
  }) =>
      NeuralTrainingEngine.trainFromSignal(
        userVector: userVector,
        song: song,
        eventType: eventType,
        contextFeatures: contextFeatures,
        audioFeatures: audioFeatures,
        temporalFeatures: temporalFeatures,
        patternFeatures: patternFeatures,
        socialFeatures: socialFeatures,
      );

  static List<double> buildContext({
    int sessionSongCount = 0,
    List<double>? momentumFeatures,
    List<double>? affinityFeatures,
  }) =>
      NeuralFeatureBuilder.buildContext(
        sessionSongCount: sessionSongCount,
        momentumFeatures: momentumFeatures,
        affinityFeatures: affinityFeatures,
      );

  static List<double> buildAudioFeatures({
    double energy = 0.5,
    double danceability = 0.5,
    double valence = 0.5,
    double tempo = 120.0,
    double acousticness = 0.5,
    double instrumentalness = 0.5,
    double speechiness = 0.5,
    double liveness = 0.5,
  }) =>
      NeuralFeatureBuilder.buildAudioFeatures(
        energy: energy,
        danceability: danceability,
        valence: valence,
        tempo: tempo,
        acousticness: acousticness,
        instrumentalness: instrumentalness,
        speechiness: speechiness,
        liveness: liveness,
      );

  static List<double> buildPatternFeatures({
    double avgSessionLength = 10.0,
    double genreDiversity = 0.5,
    double artistConcentration = 0.5,
    double skipRate = 0.3,
    double replayRatio = 0.5,
    double discoveryOpenness = 0.5,
    double timeSpentToday = 30.0,
    double moodShift = 0.3,
  }) =>
      NeuralFeatureBuilder.buildPatternFeatures(
        avgSessionLength: avgSessionLength,
        genreDiversity: genreDiversity,
        artistConcentration: artistConcentration,
        skipRate: skipRate,
        replayRatio: replayRatio,
        discoveryOpenness: discoveryOpenness,
        timeSpentToday: timeSpentToday,
        moodShift: moodShift,
      );

  static List<double> buildSocialFeatures({
    double popularityTier = 0.5,
    double releaseRecency = 0.5,
    double chartPresence = 0.0,
    double isrcMatchConfidence = 0.5,
    double lyricsAvailability = 0.5,
    double audioFingerprintMatch = 0.0,
    double crossPlatformCoverage = 0.5,
    double metadataQuality = 0.5,
  }) =>
      NeuralFeatureBuilder.buildSocialFeatures(
        popularityTier: popularityTier,
        releaseRecency: releaseRecency,
        chartPresence: chartPresence,
        isrcMatchConfidence: isrcMatchConfidence,
        lyricsAvailability: lyricsAvailability,
        audioFingerprintMatch: audioFingerprintMatch,
        crossPlatformCoverage: crossPlatformCoverage,
        metadataQuality: metadataQuality,
      );
}
