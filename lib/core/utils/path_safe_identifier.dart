/// Converts arbitrary external identifiers (song ids, room names, etc.)
/// into a single safe filesystem path segment.
///
/// Song ids are attacker-influenced values (Jam peers, metadata providers,
/// resolver results). Using them verbatim in paths would allow `../`
/// traversal out of a storage directory. This helper keeps only
/// `[A-Za-z0-9_-]`, replaces every other character with `_`, collapses
/// runs, trims edges, and bounds the length so the result can never form
/// a separator, a `.`/`..` segment, or an oversized component.
///
/// The transformation is deterministic, so the same raw id always maps to
/// the same segment on every device and every peer.
String safePathSegment(
  String raw, {
  int maxLength = 80,
  String fallback = 'segment',
}) {
  var seg = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  seg = seg.replaceAll(RegExp(r'_+'), '_');
  seg = seg.replaceAll(RegExp(r'^_+|_+$'), '');
  if (seg.isEmpty) seg = fallback;
  if (seg.length > maxLength) {
    seg = seg.substring(0, maxLength);
    seg = seg.replaceAll(RegExp(r'^_+|_+$'), '');
  }
  if (seg.isEmpty) seg = fallback;
  return seg;
}

/// True when [segment] is a plain, single path component that cannot
/// escape its parent directory (no separators, no dot segments, no
/// absolute prefix, bounded length).
bool isSafePathSegment(String segment) {
  if (segment.isEmpty || segment.length > 255) return false;
  if (segment == '.' || segment == '..') return false;
  if (segment.startsWith('/') ||
      segment.startsWith('\\') ||
      segment.contains('/') ||
      segment.contains('\\')) {
    return false;
  }
  return true;
}
