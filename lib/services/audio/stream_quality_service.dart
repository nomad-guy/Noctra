import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/utils/noctra_logger.dart';

/// Audio stream quality and codec configuration.
enum StreamQuality {
  low('Low (96 kbps)', 96, 'mp3'),
  medium('Medium (128 kbps)', 128, 'mp3'),
  high('High (192 kbps)', 192, 'mp3'),
  veryHigh('Very High (256 kbps)', 256, 'aac'),
  lossless('Lossless (320 kbps)', 320, 'mp3'),
  hiRes('Hi-Res (FLAC)', 0, 'flac');

  final String displayName;
  final int bitrate;
  final String codec;

  const StreamQuality(this.displayName, this.bitrate, this.codec);
}

/// Audio codec types for playback.
enum AudioCodec {
  mp3('MP3', 'Most compatible, lossy compression'),
  aac('AAC', 'Better quality than MP3 at same bitrate'),
  flac('FLAC', 'Lossless, larger file size'),
  opus('Opus', 'Best compression efficiency, newer codec'),
  vorbis('Vorbis', 'Open source, good quality');

  final String displayName;
  final String description;

  const AudioCodec(this.displayName, this.description);
}

/// CODEC and resolution settings for audio streaming and download.
class StreamQualityService {
  static final StreamQualityService _instance =
      StreamQualityService._internal();
  factory StreamQualityService() => _instance;
  StreamQualityService._internal();

  static const _channel =
      MethodChannel('com.nomadguy.noctra/audio_quality');

  StreamQuality _streamQuality = StreamQuality.lossless;
  StreamQuality get streamQuality => _streamQuality;

  AudioCodec _preferredCodec = AudioCodec.mp3;
  AudioCodec get preferredCodec => _preferredCodec;

  bool _normalizeVolume = true;
  bool get normalizeVolume => _normalizeVolume;

  bool _gaplessPlayback = true;
  bool get gaplessPlayback => _gaplessPlayback;

  final _settingsController =
      StreamController<StreamQualitySettings>.broadcast();
  Stream<StreamQualitySettings> get settingsStream =>
      _settingsController.stream;

  /// Set the streaming quality preference.
  Future<void> setStreamQuality(StreamQuality quality) async {
    _streamQuality = quality;
    _emitSettings();
    try {
      await _channel.invokeMethod('setStreamQuality', {
        'bitrate': quality.bitrate,
        'codec': quality.codec,
      });
    } catch (e) {
      NoctraLogger.w('Failed to set stream quality natively', e);
    }
  }

  /// Set preferred codec for playback.
  Future<void> setPreferredCodec(AudioCodec codec) async {
    _preferredCodec = codec;
    _emitSettings();
    try {
      await _channel.invokeMethod('setPreferredCodec', {
        'codec': codec.name,
      });
    } catch (e) {
      NoctraLogger.w('Failed to set codec natively', e);
    }
  }

  /// Toggle volume normalization (replay gain).
  void setNormalizeVolume(bool normalize) {
    _normalizeVolume = normalize;
    _emitSettings();
  }

  /// Toggle gapless playback.
  void setGaplessPlayback(bool gapless) {
    _gaplessPlayback = gapless;
    _emitSettings();
  }

  /// Get the best available quality URL from a list of adaptive format URLs.
  /// Returns the URL that best matches the user's quality preference.
  String selectBestQuality(List<Map<String, dynamic>> adaptiveFormats) {
    if (adaptiveFormats.isEmpty) return '';

    // Filter audio streams only
    final audioStreams = adaptiveFormats
        .where((f) => (f['mimeType'] as String?)?.contains('audio') == true)
        .toList();

    if (audioStreams.isEmpty) return '';

    // Sort by codec transparency and bitrate preference.
    // Opus 48kHz is prioritized for lossless/hiRes modes as it aligns with Android's
    // 48kHz native mixer and preserves 20kHz frequency bandwidth.
    audioStreams.sort((a, b) {
      final aMime = ((a['mimeType'] as String?) ?? '').toLowerCase();
      final bMime = ((b['mimeType'] as String?) ?? '').toLowerCase();
      final aIsOpus = aMime.contains('opus') || aMime.contains('webm');
      final bIsOpus = bMime.contains('opus') || bMime.contains('webm');

      if (_streamQuality == StreamQuality.lossless ||
          _streamQuality == StreamQuality.hiRes) {
        if (aIsOpus != bIsOpus) return aIsOpus ? -1 : 1;
      }

      final aBps = ((a['bitrate'] as num?) ?? 0).toDouble();
      final bBps = ((b['bitrate'] as num?) ?? 0).toDouble();
      final targetBps = _streamQuality.bitrate * 1000.0; // kbps → bps

      final aDiff = (aBps - targetBps).abs();
      final bDiff = (bBps - targetBps).abs();
      return aDiff.compareTo(bDiff);
    });

    final selected = audioStreams.first;
    final url = selected['url'] as String? ?? '';
    final actualBitrate = (selected['bitrate'] as num?) ?? 0;
    NoctraLogger.d(
        'Selected stream: ${actualBitrate}kbps (target: ${_streamQuality.bitrate}kbps)');

    return url;
  }

  /// Get recommended quality for download based on network and storage.
  StreamQuality getRecommendedDownloadQuality() {
    // Default to highest quality for downloads
    return StreamQuality.lossless;
  }

  /// Calculate estimated file size for a song duration at given quality.
  static double estimateFileSizeMB(int durationSeconds, StreamQuality quality) {
    if (quality == StreamQuality.hiRes) {
      // FLAC: ~10MB per minute
      return (durationSeconds / 60.0) * 10.0;
    }
    // Lossy: bitrate in kbps → MB = bitrate * duration / 8 / 1024
    return (quality.bitrate * durationSeconds) / (8.0 * 1024.0);
  }

  void _emitSettings() {
    _settingsController.add(StreamQualitySettings(
      streamQuality: _streamQuality,
      preferredCodec: _preferredCodec,
      normalizeVolume: _normalizeVolume,
      gaplessPlayback: _gaplessPlayback,
    ));
  }
}

/// Current stream quality settings snapshot.
class StreamQualitySettings {
  final StreamQuality streamQuality;
  final AudioCodec preferredCodec;
  final bool normalizeVolume;
  final bool gaplessPlayback;

  const StreamQualitySettings({
    required this.streamQuality,
    required this.preferredCodec,
    required this.normalizeVolume,
    required this.gaplessPlayback,
  });
}
