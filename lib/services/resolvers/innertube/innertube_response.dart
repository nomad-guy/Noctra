import '../../audio/stream_quality_service.dart';

/// Maximum adaptive-format count considered by [selectBestDirectAudioUrl]
/// (sanity bound against pathological responses).
const int _maxFormatsConsidered = 200;

/// Playability classification for an InnerTube `/player` response.
enum InnerTubePlayability {
  ok,
  loginRequired,
  ageRestricted,
  live,
  unavailable,
  unknown,
}

/// Classifies `playabilityStatus.status`/`reason` into a failure class so the
/// resolver can decide whether another client/retry can help.
InnerTubePlayability classifyInnerTubePlayability(
  String? status,
  String? reason,
) {
  final s = (status ?? '').toUpperCase();
  if (s == 'OK') return InnerTubePlayability.ok;
  final r = (reason ?? '').toLowerCase();
  // Age refusals often surface as LOGIN_REQUIRED with an age reason; they must
  // be classified before the generic login-required branch so the cascade
  // stops instead of retrying with a visitor data that cannot help.
  if (s == 'AGE_CHECK_REQUIRED' ||
      s == 'AGE_VERIFICATION_REQUIRED' ||
      s == 'CONTENT_CHECK_REQUIRED' ||
      r.contains('age-restricted') ||
      r.contains('age verification')) {
    return InnerTubePlayability.ageRestricted;
  }
  if (s == 'LOGIN_REQUIRED' || r.contains('sign in')) {
    return InnerTubePlayability.loginRequired;
  }
  if (s.startsWith('LIVE') || r.contains('live')) {
    return InnerTubePlayability.live;
  }
  if (s == 'UNPLAYABLE' ||
      s == 'ERROR' ||
      s == 'VIDEO_UNAVAILABLE' ||
      s == 'UNKNOWN') {
    return InnerTubePlayability.unavailable;
  }
  return InnerTubePlayability.unknown;
}

/// Parsed `/player` response surface used by the cascade.
class InnerTubePlayerData {
  final InnerTubePlayability playability;
  final String? statusReason;
  final List<dynamic>? adaptiveFormats;
  final int expiresInSeconds;

  const InnerTubePlayerData({
    required this.playability,
    this.statusReason,
    this.adaptiveFormats,
    this.expiresInSeconds = 0,
  });
}

/// Selects the best playable audio URL from `adaptiveFormats`.
///
/// Only formats that already carry a direct pre-signed `https` URL qualify —
/// `signatureCipher`/`cipher`-only formats (and video-only formats) are
/// rejected because this resolver deliberately does not run the JS decipher.
String? selectBestDirectAudioUrl(List<dynamic>? adaptiveFormats) {
  if (adaptiveFormats == null || adaptiveFormats.isEmpty) return null;
  final direct = <Map<String, dynamic>>[];
  var seen = 0;
  for (final raw in adaptiveFormats) {
    seen++;
    if (seen > _maxFormatsConsidered) break;
    if (raw is! Map) continue;
    final mime = raw['mimeType']?.toString() ?? '';
    final url = raw['url']?.toString() ?? '';
    if (!mime.contains('audio')) continue;
    if (url.isEmpty || !url.startsWith('https://') || url.length < 16) {
      continue;
    }
    direct.add({
      'mimeType': mime,
      'bitrate': raw['bitrate'] ?? 0,
      'url': url,
    });
  }
  if (direct.isEmpty) return null;
  final picked = StreamQualityService().selectBestQuality(direct);
  return picked.isEmpty ? null : picked;
}
