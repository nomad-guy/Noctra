import '../domain/models/recommendation_event.dart';

/// Evaluates raw user playback interactions and produces qualified,
/// anti-poisoned recommendation events.
class EventQualifier {
  EventQualifier._();

  /// Qualifies a track playback completion signal.
  ///
  /// Prevents accidental taps (<10s) from heavily poisoning artist/genre affinity,
  /// while properly rewarding deep (>70%) and complete (>90%) listens.
  static (RecommendationEventType, double) qualifyPlayback({
    required int listenedSeconds,
    required int totalDurationSeconds,
  }) {
    if (listenedSeconds < 10) {
      // Fast skip: accidental tap or immediate dislike
      return (RecommendationEventType.fastSkip, -0.5);
    } else if (listenedSeconds < 30) {
      // Short skip: gave it a brief chance
      return (RecommendationEventType.shortSkip, -0.2);
    }

    if (totalDurationSeconds <= 0) {
      // Fallback if total duration was unknown
      return listenedSeconds >= 60
          ? (RecommendationEventType.partialListen, 0.4)
          : (RecommendationEventType.partialListen, 0.2);
    }

    final ratio = (listenedSeconds / totalDurationSeconds).clamp(0.0, 1.0);
    if (ratio < 0.5) {
      return (RecommendationEventType.partialListen, 0.2);
    } else if (ratio < 0.9) {
      return (RecommendationEventType.deepListen, 0.4 + (ratio * 0.4));
    } else {
      return (RecommendationEventType.completeListen, 1.0);
    }
  }

  /// Maps explicit user actions (like, add to playlist, download, replay)
  /// to their qualified high-confidence signal scores.
  static double scoreForExplicitAction(RecommendationEventType type) {
    switch (type) {
      case RecommendationEventType.favorite:
        return 3.0;
      case RecommendationEventType.playlistAdd:
        return 2.5;
      case RecommendationEventType.download:
        return 2.0;
      case RecommendationEventType.replay:
        return 1.5;
      case RecommendationEventType.searchSelect:
        return 1.2;
      default:
        return 0.3;
    }
  }
}
