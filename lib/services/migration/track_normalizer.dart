import '../../data/models/migration_models.dart';

/// Normalizes imported track metadata for consistent matching.
class TrackNormalizer {
  /// Normalize a track for matching — does NOT destroy original metadata.
  static NormalizedTrack normalize(NormalizedTrack track) {
    return track.copyWith(
      title: _normalizeTitle(track.title),
      artist: _normalizeArtist(track.artist),
      album: track.album != null ? _normalizeTitle(track.album!) : null,
    );
  }

  static String _normalizeTitle(String title) {
    var s = title.trim();
    // Remove common suffixes that vary across services
    s = s.replaceAll(
        RegExp(r'\s*\(feat\.?\s*[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*ft\.?\s+.*', caseSensitive: false), '');
    s = s.replaceAll(
        RegExp(
            r'\s*[-–—]\s*(Remaster(ed)?|Deluxe|Radio Edit|Clean|Explicit|Remix|Live|Acoustic|Version|Edit).*',
            caseSensitive: false),
        '');
    s = s.replaceAll(RegExp(r'\s*\[Remaster(ed)?\]', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\(Remaster(ed)?\)', caseSensitive: false), '');
    // Unicode normalization
    s = _normalizeUnicode(s);
    // Lowercase + collapse whitespace
    s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove punctuation except apostrophes and hyphens
    s = s.replaceAll(RegExp(r"[^\w\s'-]"), '');
    return s;
  }

  static String _normalizeArtist(String artist) {
    var s = artist.trim();
    s = s.replaceAll(
        RegExp(r'\s*(feat\.?|ft\.?)\s+.*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*[,&/]\s+.*'), '');
    s = _normalizeUnicode(s);
    s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r"[^\w\s'-]"), '');
    return s;
  }

  static String _normalizeUnicode(String s) {
    s = s
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e');
    s = s
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a');
    s = s
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i');
    s = s
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o');
    s = s
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u');
    s = s.replaceAll('ñ', 'n').replaceAll('ç', 'c').replaceAll('ß', 'ss');
    return s;
  }
}
