/// Centralizes conservative artist extraction for provider responses.
///
/// Provider-supplied structured artist runs take precedence. Legacy subtitle
/// text is filtered to prevent track-type badges ('Song', 'Video', 'Single')
/// or movie/album names from corrupting the artist identity.
class ArtistMetadataNormalizer {
  static const Set<String> _typeBadges = {
    'song',
    'video',
    'single',
    'album',
    'ep',
    'artist',
    'podcast',
    'playlist',
    'channel',
    'topic',
    'official',
  };

  static bool _isBadgeOrSeparator(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty || lower == '•' || lower == '|' || lower == '·' || lower == '-') {
      return true;
    }
    if (_typeBadges.contains(lower)) return true;
    // Check if it's a duration (e.g. 3:45) or year (e.g. 2024)
    if (RegExp(r'^\d+:\d{2}$').hasMatch(lower)) return true;
    if (RegExp(r'^\d{4}$').hasMatch(lower)) return true;
    if (lower.contains('views') || lower.contains('plays')) return true;
    return false;
  }

  static String fromYouTubeRuns(List<dynamic>? runs, {String fallback = ''}) {
    if (runs == null || runs.isEmpty) return fromLegacyText(fallback);

    final artists = <String>[];

    // Pass 1: Look for explicit artist channel navigation endpoints
    for (final raw in runs) {
      if (raw is! Map) continue;
      final text = raw['text']?.toString().trim() ?? '';
      if (_isBadgeOrSeparator(text)) continue;

      final browseEndpoint = raw['navigationEndpoint']?['browseEndpoint'] as Map?;
      final browseId = browseEndpoint?['browseId']?.toString() ?? '';
      final pageType = browseEndpoint?['browseEndpointContextSupportedConfigs']
          ?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';

      if (browseId.startsWith('UC') || pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
        artists.add(text);
      }
    }

    if (artists.isNotEmpty) {
      return artists.toSet().join(', ');
    }

    // Pass 2: Look through runs and skip type badges (e.g. 'Song', 'Video')
    for (final raw in runs) {
      if (raw is! Map) continue;
      final text = raw['text']?.toString().trim() ?? '';
      if (_isBadgeOrSeparator(text)) continue;

      // First non-badge run is the artist name
      return _cleanArtistString(text);
    }

    return fromLegacyText(runs.map((run) => (run is Map ? run['text'] : '') ?? '').join());
  }

  static String fromLegacyText(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Unknown Artist';

    // Split on bullet separators or pipe separators
    final parts = value
        .split(RegExp(r'\s*[•|·]\s*'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    for (final part in parts) {
      if (_isBadgeOrSeparator(part)) continue;
      return _cleanArtistString(part);
    }

    // Fallback if every part was classified as badge
    return _cleanArtistString(parts.isNotEmpty ? parts.first : value);
  }

  static String _cleanArtistString(String artist) {
    return artist
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String identityKey(String artist) =>
      artist.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
