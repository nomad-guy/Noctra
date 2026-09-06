enum AudioQualityTier {
  hiResLossless,
  lossless,
  dolbyAtmos,
  high,
  standard,
}

enum AudioQualityPreference {
  autoBest,
  preferLossless,
  highQuality,
  dataSaver,
}

class AudioStreamInfo {
  final String url;
  final AudioQualityTier tier;
  final String codec;
  final int? sampleRate;
  final int? bitDepth;
  final int? bitrateKbps;
  final String sourceId;

  const AudioStreamInfo({
    required this.url,
    required this.tier,
    required this.codec,
    this.sampleRate,
    this.bitDepth,
    this.bitrateKbps,
    required this.sourceId,
  });

  bool get isLossless =>
      tier == AudioQualityTier.hiResLossless || tier == AudioQualityTier.lossless;

  bool get isSpatial =>
      tier == AudioQualityTier.dolbyAtmos ||
      codec.toUpperCase().contains('ATMOS') ||
      codec.toUpperCase().contains('EAC3');

  String get badgeLabel {
    switch (tier) {
      case AudioQualityTier.hiResLossless:
        final bd = bitDepth != null ? '$bitDepth-BIT' : 'HI-RES';
        return 'HI-RES $bd';
      case AudioQualityTier.lossless:
        final bd = bitDepth != null ? '$bitDepth-BIT' : 'FLAC';
        return 'LOSSLESS $bd';
      case AudioQualityTier.dolbyAtmos:
        return 'DOLBY ATMOS';
      case AudioQualityTier.high:
        return bitrateKbps != null ? '$bitrateKbps KBPS' : '320 KBPS';
      case AudioQualityTier.standard:
        return 'HQ';
    }
  }

  String get shortLabel {
    switch (tier) {
      case AudioQualityTier.hiResLossless:
        return 'HI-RES';
      case AudioQualityTier.lossless:
        return 'FLAC';
      case AudioQualityTier.dolbyAtmos:
        return 'ATMOS';
      case AudioQualityTier.high:
        return '320K';
      case AudioQualityTier.standard:
        return 'HQ';
    }
  }

  String get detailsLabel {
    final parts = <String>[codec.toUpperCase()];
    if (bitDepth != null && sampleRate != null) {
      final srKhz = (sampleRate! / 1000).toStringAsFixed(1);
      final cleanSr = srKhz.endsWith('.0')
          ? srKhz.substring(0, srKhz.length - 2)
          : srKhz;
      parts.add('$bitDepth-bit / $cleanSr kHz');
    } else if (sampleRate != null) {
      parts.add('${(sampleRate! / 1000).toStringAsFixed(1)} kHz');
    }
    if (bitrateKbps != null) {
      parts.add('$bitrateKbps kbps');
    }
    return parts.join(' • ');
  }

  factory AudioStreamInfo.hiResFlac({
    required String url,
    int bitDepth = 24,
    int sampleRate = 96000,
    int bitrateKbps = 2304,
    String sourceId = 'tidal_hires',
  }) {
    return AudioStreamInfo(
      url: url,
      tier: AudioQualityTier.hiResLossless,
      codec: 'FLAC',
      bitDepth: bitDepth,
      sampleRate: sampleRate,
      bitrateKbps: bitrateKbps,
      sourceId: sourceId,
    );
  }

  factory AudioStreamInfo.losslessFlac({
    required String url,
    int bitDepth = 16,
    int sampleRate = 44100,
    int bitrateKbps = 1411,
    String sourceId = 'tidal_lossless',
  }) {
    return AudioStreamInfo(
      url: url,
      tier: AudioQualityTier.lossless,
      codec: 'FLAC',
      bitDepth: bitDepth,
      sampleRate: sampleRate,
      bitrateKbps: bitrateKbps,
      sourceId: sourceId,
    );
  }

  factory AudioStreamInfo.dolbyAtmos({
    required String url,
    int bitrateKbps = 768,
    String sourceId = 'tidal_atmos',
  }) {
    return AudioStreamInfo(
      url: url,
      tier: AudioQualityTier.dolbyAtmos,
      codec: 'E-AC-3 JOC (Atmos)',
      sampleRate: 48000,
      bitrateKbps: bitrateKbps,
      sourceId: sourceId,
    );
  }

  factory AudioStreamInfo.highQuality({
    required String url,
    int bitrateKbps = 320,
    String codec = 'AAC',
    int sampleRate = 44100,
    String sourceId = 'jiosaavn_320k',
  }) {
    return AudioStreamInfo(
      url: url,
      tier: AudioQualityTier.high,
      codec: codec,
      sampleRate: sampleRate,
      bitrateKbps: bitrateKbps,
      sourceId: sourceId,
    );
  }

  factory AudioStreamInfo.standard({
    required String url,
    int bitrateKbps = 160,
    String codec = 'OPUS',
    int sampleRate = 48000,
    String sourceId = 'innertube_opus',
  }) {
    return AudioStreamInfo(
      url: url,
      tier: AudioQualityTier.standard,
      codec: codec,
      sampleRate: sampleRate,
      bitrateKbps: bitrateKbps,
      sourceId: sourceId,
    );
  }

  factory AudioStreamInfo.fromUrl(
    String url, {
    String sourceId = 'unknown',
    int? sampleRate,
    int? bitDepth,
    int? bitrateKbps,
  }) {
    final lower = url.toLowerCase();
    if (lower.contains('atmos') ||
        lower.contains('eac3') ||
        sourceId.contains('atmos')) {
      return AudioStreamInfo.dolbyAtmos(
        url: url,
        bitrateKbps: bitrateKbps ?? 768,
        sourceId: sourceId,
      );
    }
    if (lower.endsWith('.flac') ||
        lower.contains('.flac?') ||
        sourceId.contains('flac') ||
        sourceId.contains('tidal') ||
        sourceId.contains('qobuz')) {
      if (bitDepth != null && bitDepth >= 24) {
        return AudioStreamInfo.hiResFlac(
          url: url,
          bitDepth: bitDepth,
          sampleRate: sampleRate ?? 96000,
          bitrateKbps: bitrateKbps ?? 2304,
          sourceId: sourceId,
        );
      }
      return AudioStreamInfo.losslessFlac(
        url: url,
        bitDepth: bitDepth ?? 16,
        sampleRate: sampleRate ?? 44100,
        bitrateKbps: bitrateKbps ?? 1411,
        sourceId: sourceId,
      );
    }
    if (sourceId.contains('320') ||
        lower.contains('320') ||
        sourceId.contains('saavn')) {
      return AudioStreamInfo.highQuality(
        url: url,
        bitrateKbps: bitrateKbps ?? 320,
        codec: 'AAC',
        sampleRate: sampleRate ?? 44100,
        sourceId: sourceId,
      );
    }
    return AudioStreamInfo.standard(
      url: url,
      bitrateKbps: bitrateKbps ?? 160,
      codec: lower.contains('opus') ? 'OPUS' : 'AAC',
      sampleRate: sampleRate ?? 48000,
      sourceId: sourceId,
    );
  }
}
