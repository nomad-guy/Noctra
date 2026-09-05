import 'dart:io';

/// Represents a single separated audio stem.
class AudioStem {
  final String name; // 'vocals', 'drums', 'bass', 'other'
  final String displayName;
  final File? audioFile;
  final double durationSeconds;

  const AudioStem({
    required this.name,
    required this.displayName,
    required this.audioFile,
    required this.durationSeconds,
  });
}

/// Result of a stem separation operation.
class StemSeparationResult {
  final List<AudioStem> stems;
  final int processingTimeMs;
  final String modelUsed;

  const StemSeparationResult({
    required this.stems,
    required this.processingTimeMs,
    required this.modelUsed,
  });
}

/// Progress tracking for stem separation.
class StemSeparationProgress {
  final String
      stage; // 'preparing', 'downloading', 'separating', 'complete', 'error'
  final double progress; // 0.0 to 1.0
  final String message;

  const StemSeparationProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });
}

/// Available stem separation models.
enum StemSeparationModel {
  /// Lightweight model (~50MB), faster processing, good quality.
  light,

  /// High-quality model (~200MB), slower processing, best quality.
  hq,

  /// Karaoke-optimized model, removes vocals only.
  karaoke,
}
