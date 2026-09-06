/// Enum defining all recognized user interaction signal types.
enum RecommendationEventType {
  fastSkip,
  shortSkip,
  partialListen,
  deepListen,
  completeListen,
  favorite,
  replay,
  playlistAdd,
  download,
  searchSelect,
  unknown,
}

/// Qualified, immutable behavioral event model capturing a user interaction.
class RecommendationEvent {
  final String id;
  final int timestamp;
  final String sessionId;
  final String trackId;
  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final RecommendationEventType eventType;
  final int durationListenedMs;
  final int totalDurationMs;
  final double completionRatio;
  final double signalScore;
  final String? audioFeaturesJson;

  const RecommendationEvent({
    required this.id,
    required this.timestamp,
    required this.sessionId,
    required this.trackId,
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    required this.eventType,
    required this.durationListenedMs,
    required this.totalDurationMs,
    required this.completionRatio,
    required this.signalScore,
    this.audioFeaturesJson,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp,
        'sessionId': sessionId,
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'eventType': eventType.name,
        'durationListenedMs': durationListenedMs,
        'totalDurationMs': totalDurationMs,
        'completionRatio': completionRatio,
        'signalScore': signalScore,
        'audioFeaturesJson': audioFeaturesJson,
      };

  factory RecommendationEvent.fromMap(Map<String, dynamic> map) {
    return RecommendationEvent(
      id: map['id']?.toString() ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      sessionId: map['sessionId']?.toString() ?? '',
      trackId: map['trackId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      artist: map['artist']?.toString() ?? '',
      album: map['album']?.toString(),
      genre: map['genre']?.toString(),
      eventType: RecommendationEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => RecommendationEventType.unknown,
      ),
      durationListenedMs: (map['durationListenedMs'] as num?)?.toInt() ?? 0,
      totalDurationMs: (map['totalDurationMs'] as num?)?.toInt() ?? 0,
      completionRatio: (map['completionRatio'] as num?)?.toDouble() ?? 0.0,
      signalScore: (map['signalScore'] as num?)?.toDouble() ?? 0.0,
      audioFeaturesJson: map['audioFeaturesJson'] as String?,
    );
  }
}
