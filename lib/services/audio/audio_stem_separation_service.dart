import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/noctra_logger.dart';
import '../../core/utils/path_safe_identifier.dart';
import 'stem_input_downloader.dart';
import 'stem_models.dart';

export 'stem_models.dart';

/// On-device audio stem separation. The Android backend uses a
/// spectral-band splitter (FFT → frequency-band mask → IFFT) and
/// is NOT a neural model. Vocals / drums / bass / other are
/// produced by isolating fixed frequency bands of the input.
/// The interface and naming are kept for backward compatibility
/// with the rest of the app, but the engine is a DSP band
/// splitter, not a learned model.
///
/// Model types live in stem_models.dart and network input fetching
/// lives in stem_input_downloader.dart to keep this file small.
class AudioStemSeparationService {
  static final AudioStemSeparationService _instance =
      AudioStemSeparationService._internal();
  factory AudioStemSeparationService() => _instance;
  AudioStemSeparationService._internal();

  static const _channel =
      MethodChannel('com.nomadguy.noctra/audio_stem_separation');

  final _progressController =
      StreamController<StemSeparationProgress>.broadcast();
  Stream<StemSeparationProgress> get progressStream =>
      _progressController.stream;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Maps an attacker-influenced [songId] to a single safe directory
  /// segment so stem paths can never escape `NoctraStems/` (e.g. via a
  /// Jam peer-supplied id containing `../` or absolute separators).
  @visibleForTesting
  static String stemDirName(String songId) => safePathSegment(songId);

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
      final stemsDir =
          Directory('${appDir.path}/NoctraStems/${stemDirName(songId)}');
      if (!stemsDir.existsSync()) {
        stemsDir.createSync(recursive: true);
      }

      // Check for cached results
      final cachedResult = _checkCache(stemsDir);
      if (cachedResult != null) {
        NoctraLogger.d('Stem separation cache hit for song $songId');
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
        inputPath = await StemInputDownloader.download(audioSource, songId);
        if (inputPath.isEmpty) {
          _isProcessing = false;
          return null;
        }
      }

      // Call native separation
      _progressController.add(StemSeparationProgress(
        stage: 'separating',
        progress: 0.2,
        message: 'Running spectral band split...',
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
            durationSeconds: (result['duration'] as num?)?.toDouble() ?? 0.0,
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
      final stemsDir =
          Directory('${appDir.path}/NoctraStems/${stemDirName(songId)}');
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
    final stemsDir =
        Directory('${appDir.path}/NoctraStems/${stemDirName(songId)}');
    return stemsDir.existsSync() ? stemsDir.path : null;
  }

  void dispose() {
    _progressController.close();
  }
}
