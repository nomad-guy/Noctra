part of '../neural_recommender_engine.dart';

extension NeuralFeatureBuilder on NeuralRecommenderEngine {
  static List<double> buildInput(
    List<double> userVec,
    List<double> songVec,
    List<double>? ctx,
    List<double>? audio,
    List<double>? temporal,
    List<double>? pattern,
    List<double>? social,
  ) {
    final input = List<double>.filled(NeuralRecommenderEngine.inputDimension, 0.5);

    for (int i = 0; i < 32 && i < userVec.length; i++) {
      input[i] = userVec[i];
    }
    for (int i = 0; i < 32 && i < songVec.length; i++) {
      input[32 + i] = songVec[i];
    }
    final context = ctx ?? buildContext();
    for (int i = 0; i < 24 && i < context.length; i++) {
      input[64 + i] = context[i];
    }
    final audioFeats = audio ?? List.filled(8, 0.5);
    for (int i = 0; i < 8 && i < audioFeats.length; i++) {
      input[88 + i] = audioFeats[i];
    }
    final tempFeats = temporal ?? buildTemporalFeatures();
    for (int i = 0; i < 8 && i < tempFeats.length; i++) {
      input[96 + i] = tempFeats[i];
    }
    final patFeats = pattern ?? List.filled(8, 0.5);
    for (int i = 0; i < 8 && i < patFeats.length; i++) {
      input[104 + i] = patFeats[i];
    }
    final socFeats = social ?? List.filled(8, 0.5);
    for (int i = 0; i < 8 && i < socFeats.length; i++) {
      input[112 + i] = socFeats[i];
    }

    return input;
  }

  static List<double> buildTemporalFeatures() {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;
    final month = now.month;

    return [
      sin(dayOfWeek / 7.0 * 2 * pi),
      cos(dayOfWeek / 7.0 * 2 * pi),
      sin(month / 12.0 * 2 * pi),
      cos(month / 12.0 * 2 * pi),
      sin(hour / 24.0 * 2 * pi),
      cos(hour / 24.0 * 2 * pi),
      dayOfWeek >= 6 ? 1.0 : 0.0,
      (month == 12 || month == 1) ? 1.0 : 0.0,
    ];
  }

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
      timePhase, timeCos, isWeekend, 0.5,
      sessionNorm, isLateNight, isEarlyMorning, 0.5,
    ];

    final momentum = momentumFeatures ?? List.filled(8, 0.5);
    for (int i = 0; i < 8; i++) {
      ctx.add(i < momentum.length ? momentum[i] : 0.5);
    }

    final affinity = affinityFeatures ?? List.filled(8, 0.5);
    for (int i = 0; i < 8; i++) {
      ctx.add(i < affinity.length ? affinity[i] : 0.5);
    }

    return ctx;
  }

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
      (tempo / 200.0).clamp(0.0, 1.0),
      acousticness.clamp(0.0, 1.0),
      instrumentalness.clamp(0.0, 1.0),
      speechiness.clamp(0.0, 1.0),
      liveness.clamp(0.0, 1.0),
    ];
  }

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
