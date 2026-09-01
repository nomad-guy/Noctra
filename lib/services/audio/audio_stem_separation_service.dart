import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/noctra_logger.dart';

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

/// On-device audio stem separation using Android native ML pipeline.
/// Separates audio into vocals, drums, bass, and other instrumentals.
class AudioStemSeparationService {
  static final AudioStemSeparationService _instance =
      AudioStemSeparationService._internal();
  factory AudioStemSeparationService() => _instance;
  AudioStemSeparationService._internal();

  static const _channel =
      MethodChannel('com.noctra.app/audio_stem_separation');

  final _progressController =
      StreamController<StemSeparationProgress>.broadcast();
  Stream<StemSeparationProgress> get progressStream =>
      _progressController.stream;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Separate a song's audio into stems.
  /// [audioSource] can be a file path or stream URL.
  /// [songId] is used for caching and output file naming.
  Future<StemSeparationResult?> separate({
    required String audioSource,
    required String songId,
    StemSeparationModel model = StemSeparationModel.light,
  }) async {
    if (_isProcessing) {
      NoctraLogger.w('Stem separation already in progress', null);
      return null;
    }
    if (kIsWeb) {
      NoctraLogger.w('Stem separation not supported on web', null);
      return null;
    }

    _isProcessing = true;
    _progressController.add(StemSeparationProgress(
      stage: 'preparing',
      progress: 0.0,
      message: 'Preparing audio for separation...',
    ));

    try {
      final sw = Stopwatch()..start();

      // Get output directory
      final appDir = await getApplicationDocumentsDirectory();
      final stemsDir = Directory('${appDir.path}/NoctraStems/$songId');
      if (!stemsDir.existsSync()) {
        stemsDir.createSync(recursive: true);
      }

      // Check for cached results
      final cachedResult = _checkCache(stemsDir);
      if (cachedResult != null) {
        NoctraLogger.d(
            'Stem separation cache hit for song $songId');
        _isProcessing = false;
        return cachedResult;
      }

      // Determine input source
      String inputPath = audioSource;
      if (audioSource.startsWith('http')) {
        _progressController.add(StemSeparationProgress(
          stage: 'downloading',
          progress: 0.1,
          message: 'Downloading audio for processing...',
        ));
        inputPath = await _downloadForSeparation(audioSource, songId);
        if (inputPath.isEmpty) {
          _isProcessing = false;
          return null;
        }
      }

      // Call native separation
      _progressController.add(StemSeparationProgress(
        stage: 'separating',
        progress: 0.2,
        message: 'Running neural stem separation...',
      ));

      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('separateStems', {
        'inputPath': inputPath,
        'outputDir': stemsDir.path,
        'model': model.name,
      });

      if (result == null) {
        _isProcessing = false;
        return null;
      }

      sw.stop();

      // Parse results
      final stems = <AudioStem>[];
      final stemNames = {
        'vocals': 'Vocals',
        'drums': 'Drums',
        'bass': 'Bass',
        'other': 'Other',
      };

      for (final entry in stemNames.entries) {
        final filePath = '${stemsDir.path}/${entry.key}.wav';
        final file = File(filePath);
        if (file.existsSync()) {
          stems.add(AudioStem(
            name: entry.key,
            displayName: entry.value,
            audioFile: file,
            durationSeconds:
                (result['duration'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }

      final separationResult = StemSeparationResult(
        stems: stems,
        processingTimeMs: sw.elapsedMilliseconds,
        modelUsed: model.name,
      );

      _progressController.add(StemSeparationProgress(
        stage: 'complete',
        progress: 1.0,
        message: 'Separation complete! ${stems.length} stems created.',
      ));

      _isProcessing = false;
      return separationResult;
    } catch (e) {
      NoctraLogger.e('Stem separation failed', e);
      _progressController.add(StemSeparationProgress(
        stage: 'error',
        progress: 0.0,
        message: 'Separation failed: ${e.toString()}',
      ));
      _isProcessing = false;
      return null;
    }
  }

  /// Download audio file temporarily for stem separation.
  Future<String> _downloadForSeparation(String url, String songId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/stem_input_$songId.wav');
      if (tempFile.existsSync() && tempFile.lengthSync() > 1024) {
        return tempFile.path;
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final sink = tempFile.openWrite();
      await response.pipe(sink);
      client.close();

      return tempFile.path;
    } catch (e) {
      NoctraLogger.e('Failed to download audio for separation', e);
      return '';
    }
  }

  /// Check for cached stem separation results.
  StemSeparationResult? _checkCache(Directory stemsDir) {
    final stemNames = ['vocals', 'drums', 'bass', 'other'];
    final displayNames = {
      'vocals': 'Vocals',
      'drums': 'Drums',
      'bass': 'Bass',
      'other': 'Other',
    };

    final stems = <AudioStem>[];
    for (final name in stemNames) {
      final file = File('${stemsDir.path}/$name.wav');
      if (!file.existsSync()) return null;
      stems.add(AudioStem(
        name: name,
        displayName: displayNames[name]!,
        audioFile: file,
        durationSeconds: 0.0,
      ));
    }

    if (stems.length == 4) {
      return StemSeparationResult(
        stems: stems,
        processingTimeMs: 0,
        modelUsed: 'cached',
      );
    }
    return null;
  }

  /// Delete cached stems for a song.
  Future<void> deleteStems(String songId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final stemsDir = Directory('${appDir.path}/NoctraStems/$songId');
      if (stemsDir.existsSync()) {
        stemsDir.deleteSync(recursive: true);
      }
    } catch (e) {
      NoctraLogger.w('Failed to delete stems for $songId', e);
    }
  }

  /// Get the path to cached stems for a song.
  Future<String?> getCachedStemsPath(String songId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final stemsDir = Directory('${appDir.path}/NoctraStems/$songId');
    return stemsDir.existsSync() ? stemsDir.path : null;
  }

  void dispose() {
    _progressController.close();
  }
}

/// Progress tracking for stem separation.
class StemSeparationProgress {
  final String stage; // 'preparing', 'downloading', 'separating', 'complete', 'error'
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
