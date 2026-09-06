import '../../../../shared/models/models.dart';

/// Execution context for a recommendation retrieval session.
class RecommendationContext {
  final String? vibeKey;
  final String? naturalPrompt;
  final Song? seedSong;
  final int targetCount;
  final bool preferDeepCuts;
  final int hourOfDay;
  final int sessionSongCount;
  final List<double>? momentumFeatures;

  const RecommendationContext({
    this.vibeKey,
    this.naturalPrompt,
    this.seedSong,
    this.targetCount = 15,
    this.preferDeepCuts = false,
    required this.hourOfDay,
    this.sessionSongCount = 0,
    this.momentumFeatures,
  });

  factory RecommendationContext.now({
    String? vibeKey,
    String? naturalPrompt,
    Song? seedSong,
    int targetCount = 15,
    bool preferDeepCuts = false,
    int sessionSongCount = 0,
    List<double>? momentumFeatures,
  }) {
    return RecommendationContext(
      vibeKey: vibeKey,
      naturalPrompt: naturalPrompt,
      seedSong: seedSong,
      targetCount: targetCount,
      preferDeepCuts: preferDeepCuts,
      hourOfDay: DateTime.now().hour,
      sessionSongCount: sessionSongCount,
      momentumFeatures: momentumFeatures,
    );
  }
}
