import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/networking/network_quality.dart';
import '../../core/utils/noctra_logger.dart';
import '../../core/utils/playback_settings_store.dart';

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

/// Explicit mobile streaming data-saver policy.
enum StreamingPolicy {
  audiophileExtreme('Audiophile Extreme', 'Always bit-perfect FLAC / 320k'),
  smartNetwork('Smart Wi-Fi / Mobile', 'Bit-perfect FLAC on Wi-Fi, efficient Opus on mobile data'),
  dataSaver('Data Saver', 'Opus 96-128kbps low-bandwidth profile');

  final String displayName;
  final String description;

  const StreamingPolicy(this.displayName, this.description);
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

  StreamingPolicy _streamingPolicy = StreamingPolicy.smartNetwork;
  StreamingPolicy get streamingPolicy => _streamingPolicy;

  bool _normalizeVolume = true;
  bool get normalizeVolume => _normalizeVolume;

  bool _gaplessPlayback = true;
  bool get gaplessPlayback => _gaplessPlayback;

  bool _hydrated = false;
  StreamSubscription<NetworkQuality>? _networkSub;

  /// Effective policy for the CURRENT network: Smart policy becomes
  /// data-saver on mobile data / poor networks and audiophile on good
  /// Wi-Fi. Other policies pass through unchanged.
  StreamingPolicy get effectivePolicy {
    if (_streamingPolicy != StreamingPolicy.smartNetwork) return _streamingPolicy;
    final net = NetworkQualityService.instance;
    if (net.isOffline) return _streamingPolicy;
    return (net.onMobileData || net.quality == NetworkQuality.poor)
        ? StreamingPolicy.dataSaver
        : StreamingPolicy.audiophileExtreme;
  }

  /// Restores persisted quality/codec/policy/processing settings. Called
  /// from main() before any UI can read the service — on Windows the process
  /// fully exits between launches so this must happen at startup.
  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    final s = PlaybackSettingsStore.instance;
    _streamQuality = StreamQuality.values.firstWhere(
        (q) => q.name == s.streamQuality,
        orElse: () => StreamQuality.lossless);
    _preferredCodec = AudioCodec.values.firstWhere(
        (c) => c.name == s.preferredCodec,
        orElse: () => AudioCodec.mp3);
    _streamingPolicy = StreamingPolicy.values.firstWhere(
        (p) => p.name == s.streamingPolicy,
        orElse: () => StreamingPolicy.smartNetwork);
    _normalizeVolume = s.normalizeVolume;
    _gaplessPlayback = s.gaplessPlayback;

    // Smart policy reacts to network changes live (Wi-Fi ↔ mobile data).
    _networkSub ??= NetworkQualityService.instance.qualityStream.listen((_) {
      _emitSettings();
    });
  }

  final _settingsController =
      StreamController<StreamQualitySettings>.broadcast();
  Stream<StreamQualitySettings> get settingsStream =>
      _settingsController.stream;

  /// Sets the active streaming policy.
  void setStreamingPolicy(StreamingPolicy policy) {
    _streamingPolicy = policy;
    if (policy == StreamingPolicy.dataSaver) {
      _streamQuality = StreamQuality.low;
      _preferredCodec = AudioCodec.opus;
    } else if (policy == StreamingPolicy.audiophileExtreme) {
      _streamQuality = StreamQuality.hiRes;
      _preferredCodec = AudioCodec.flac;
    }
    PlaybackSettingsStore.instance.save(
      streamingPolicy: policy.name,
      streamQuality: _streamQuality.name,
      preferredCodec: _preferredCodec.name,
    );
    _emitSettings();
  }

  /// Set the streaming quality preference.
  Future<void> setStreamQuality(StreamQuality quality) async {
    _streamQuality = quality;
    PlaybackSettingsStore.instance.save(streamQuality: quality.name);
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
    PlaybackSettingsStore.instance.save(preferredCodec: codec.name);
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
    PlaybackSettingsStore.instance.save(normalizeVolume: normalize);
    _emitSettings();
  }

  /// Toggle gapless playback.
  void setGaplessPlayback(bool gapless) {
    _gaplessPlayback = gapless;
    PlaybackSettingsStore.instance.save(gaplessPlayback: gapless);
    _emitSettings();
  }

  /// Get the best available quality URL from a list of adaptive format URLs.
  /// Returns the URL that best matches the user's quality preference.
  String selectBestQuality(List<Map<String, dynamic>> adaptiveFormats) {
    if (adaptiveFormats.isEmpty) return '';

    // Smart policy: the CURRENT network decides the target bitrate, not the
    // user's stored quality — big data savings on mobile, full quality on
    // Wi-Fi, zero configuration.
    final effective = effectivePolicy == StreamingPolicy.dataSaver
        ? StreamQuality.medium
        : _streamQuality;
    final targetKbps = effective.bitrate;

    // Filter audio streams only
    final audioStreams = adaptiveFormats
        .where((f) => (f['mimeType'] as String?)?.contains('audio') == true)
        .toList();

    if (audioStreams.isEmpty) return '';

    // Sort streams according to quality and codec preferences.
    audioStreams.sort((a, b) {
      final aMime = ((a['mimeType'] as String?) ?? '').toLowerCase();
      final bMime = ((b['mimeType'] as String?) ?? '').toLowerCase();
      final aBps = ((a['bitrate'] as num?) ?? 0).toDouble();
      final bBps = ((b['bitrate'] as num?) ?? 0).toDouble();

      final pref = _preferredCodec.name.toLowerCase();
      final aPref = aMime.contains(pref) || (pref == 'opus' && aMime.contains('webm'));
      final bPref = bMime.contains(pref) || (pref == 'opus' && bMime.contains('webm'));

      // Hi-Res mode: prefer FLAC, then preferred codec, then highest bitrate (descending)
      if (effective == StreamQuality.hiRes) {
        final aFlac = aMime.contains('flac');
        final bFlac = bMime.contains('flac');
        if (aFlac != bFlac) return aFlac ? -1 : 1;
        if (aPref != bPref) return aPref ? -1 : 1;
        final aOpus = aMime.contains('opus') || aMime.contains('webm');
        final bOpus = bMime.contains('opus') || bMime.contains('webm');
        if (aOpus != bOpus) return aOpus ? -1 : 1;
        return bBps.compareTo(aBps); // Highest bitrate first
      }

      // Target bitrate mode: find closest bitrate to target
      final targetBps = targetKbps * 1000.0;
      final aDiff = (aBps - targetBps).abs();
      final bDiff = (bBps - targetBps).abs();

      if ((aDiff - bDiff).abs() > 16000) return aDiff.compareTo(bDiff);
      if (aPref != bPref) return aPref ? -1 : 1;
      if (effective == StreamQuality.lossless) {
        final aOpus = aMime.contains('opus') || aMime.contains('webm');
        final bOpus = bMime.contains('opus') || bMime.contains('webm');
        if (aOpus != bOpus) return aOpus ? -1 : 1;
      }
      return aDiff.compareTo(bDiff);
    });

    final selected = audioStreams.first;
    final url = selected['url'] as String? ?? '';
    final actualBitrate = (selected['bitrate'] as num?) ?? 0;
    NoctraLogger.d(
        'Selected stream: ${actualBitrate}kbps (target: ${targetKbps}kbps, '
        'policy: ${effectivePolicy.name})');

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
      streamingPolicy: _streamingPolicy,
      normalizeVolume: _normalizeVolume,
      gaplessPlayback: _gaplessPlayback,
    ));
  }
}

/// Current stream quality settings snapshot.
class StreamQualitySettings {
  final StreamQuality streamQuality;
  final AudioCodec preferredCodec;
  final StreamingPolicy streamingPolicy;
  final bool normalizeVolume;
  final bool gaplessPlayback;

  const StreamQualitySettings({
    required this.streamQuality,
    required this.preferredCodec,
    required this.streamingPolicy,
    required this.normalizeVolume,
    required this.gaplessPlayback,
  });
}
