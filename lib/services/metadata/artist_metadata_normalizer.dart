/// Centralizes conservative artist extraction for provider responses.
///
/// Provider-supplied structured artist runs take precedence. Legacy subtitle
/// text is only trimmed at known metadata separators; punctuation in a name
/// such as "Earth, Wind & Fire" remains intact.
class ArtistMetadataNormalizer {
  static String fromYouTubeRuns(List<dynamic>? runs, {String fallback = ''}) {
    if (runs == null || runs.isEmpty) return fromLegacyText(fallback);
    final artists = <String>[];
    for (final raw in runs) {
      if (raw is! Map) continue;
      final text = raw['text']?.toString().trim() ?? '';
      if (text.isEmpty || text == '•') continue;
      final browseId =
          raw['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString();
      if (browseId != null && browseId.startsWith('UC')) {
        artists.add(text);
      }
    }
    if (artists.isNotEmpty) return artists.toSet().join(', ');
    return fromLegacyText(runs.map((run) => (run as Map)['text'] ?? '').join());
  }

  static String fromLegacyText(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Unknown Artist';
    final metadataStart = value.indexOf(RegExp(r'\s•\s'));
    return (metadataStart < 0 ? value : value.substring(0, metadataStart))
        .trim();
  }

  static String identityKey(String artist) =>
      artist.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
