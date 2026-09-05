class StreamResolutionMetadata {
  final String songId;
  final String songTitle;
  final String resolverUsed;
  final String? resolvedUrl;
  final int resolutionMs;
  final DateTime timestamp;

  StreamResolutionMetadata({
    required this.songId,
    required this.songTitle,
    required this.resolvedUrl,
    required this.resolverUsed,
    required this.resolutionMs,
    required this.timestamp,
  });
}
