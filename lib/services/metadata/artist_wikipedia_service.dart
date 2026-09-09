import 'dart:convert';
import 'package:http/http.dart' as http;

class ArtistWikipediaResult {
  final String? bio;
  final String? shortDescription;
  final String? imageUrl;

  const ArtistWikipediaResult({
    this.bio,
    this.shortDescription,
    this.imageUrl,
  });
}

/// Fully dynamic Wikipedia metadata and biography resolver.
/// Discovers and verifies music entities with zero static lookup tables.
class ArtistWikipediaService {
  static const String _userAgent =
      'NoctraPlayer/1.0.6 (https://github.com/nomad-guy/Noctra; dev@noctra.app)';

  /// Clean wiki reference markers, parenthetical phonetic symbols, and extra whitespace.
  static String cleanBioText(String raw) {
    return raw
        .replaceAll(RegExp(r'\[\d+\]|\[citation needed\]|\[edit\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(\s*/[^/]+/.*?\)', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts a clean, sentence-bounded summary limit so bios never end with broken words or dots.
  static String formatBioSnippet(String fullBio, {int maxSentences = 2, int maxChars = 220}) {
    if (fullBio.isEmpty) return '';
    final clean = cleanBioText(fullBio);

    // Split on sentence boundaries (period, exclamation, question mark followed by space)
    final sentenceMatches = RegExp(r'[^.!?]+[.!?]').allMatches(clean).map((m) => m.group(0)!.trim()).toList();
    if (sentenceMatches.isNotEmpty) {
      final takeCount = sentenceMatches.length >= maxSentences ? maxSentences : sentenceMatches.length;
      final snippet = sentenceMatches.take(takeCount).join(' ');
      if (snippet.length <= maxChars) {
        return snippet;
      }
    }

    // Fallback: If the first sentence alone exceeds maxChars, cut cleanly at the last whole word
    if (clean.length > maxChars) {
      final slice = clean.substring(0, maxChars);
      final lastSpace = slice.lastIndexOf(' ');
      if (lastSpace > 60) {
        return '${slice.substring(0, lastSpace)}...';
      }
      return '$slice...';
    }
    return clean;
  }

  /// Dynamically verifies whether a Wikipedia page represents a genuine musical entity.
  static bool _isValidMusicEntity(String desc, String extract) {
    final d = desc.toLowerCase();
    final e = extract.toLowerCase();

    // Rejection of non-music Wikipedia pages
    if (d.contains('emperor') ||
        d.contains('dynasty') ||
        d.contains('monarch') ||
        d.contains('concept') ||
        d.contains('given name') ||
        d.contains('surname') ||
        d.contains('politician') ||
        d.contains('cricketer') ||
        d.contains('footballer') ||
        d.contains('village') ||
        d.contains('district') ||
        d.contains('species') ||
        d.contains('film directed')) {
      return false;
    }

    return d.contains('singer') ||
        d.contains('musician') ||
        d.contains('band') ||
        d.contains('rapper') ||
        d.contains('composer') ||
        d.contains('songwriter') ||
        d.contains('producer') ||
        d.contains('playback') ||
        d.contains('vocalist') ||
        d.contains('duo') ||
        d.contains('artist') ||
        d.contains('music director') ||
        e.contains('singer') ||
        e.contains('musician') ||
        e.contains('rapper') ||
        e.contains('songwriter') ||
        e.contains('playback singer') ||
        e.contains('discography') ||
        e.contains('record producer') ||
        e.contains('album') ||
        e.contains('debut single');
  }

  /// Fetches bio and portrait dynamically from Wikipedia for any given artist name.
  static Future<ArtistWikipediaResult?> fetchBioAndImage(String effectiveName) async {
    final cleanName = effectiveName.trim();
    if (cleanName.isEmpty) return null;

    String? bio;
    String? shortDesc;
    String? resolvedImageUrl;

    // Stage 1: Try direct page summary
    try {
      final directUri = Uri.parse(
          'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanName)}');
      final res = await http.get(directUri, headers: {
        'User-Agent': _userAgent,
      }).timeout(const Duration(milliseconds: 2000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final ptype = (data['type'] as String?)?.toLowerCase();
        if (ptype != 'disambiguation') {
          final desc = data['description'] as String? ?? '';
          final extract = data['extract'] as String? ?? '';
          if (_isValidMusicEntity(desc, extract)) {
            bio = cleanBioText(extract);
            shortDesc = desc.isNotEmpty ? desc : 'Official Artist Profile';
            final thumb = data['thumbnail']?['source'] ?? data['originalimage']?['source'];
            if (thumb != null && thumb.toString().isNotEmpty) {
              resolvedImageUrl = thumb.toString();
            }
          }
        }
      }
    } catch (_) {}

    // Stage 2: Dynamic full-text music entity search on Wikipedia
    if (bio == null || bio.isEmpty) {
      try {
        final searchUri = Uri.parse(
            'https://en.wikipedia.org/w/api.php?action=query&list=search'
            '&srsearch=${Uri.encodeComponent('$cleanName singer OR musician OR rapper OR band')}'
            '&format=json&srlimit=5');
        final res = await http.get(searchUri, headers: {
          'User-Agent': _userAgent,
        }).timeout(const Duration(milliseconds: 2200));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final searchList = json['query']?['search'] as List<dynamic>?;
          if (searchList != null && searchList.isNotEmpty) {
            for (final item in searchList) {
              if (item is! Map) continue;
              final candTitle = item['title']?.toString() ?? '';
              if (candTitle.isEmpty) continue;
              final lowerCand = candTitle.toLowerCase();
              if (lowerCand.startsWith('list of ') ||
                  lowerCand.contains('discography') ||
                  lowerCand.contains('awards and nominations')) {
                continue;
              }

              // Fetch summary of this dynamically found music candidate
              try {
                final candUri = Uri.parse(
                    'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(candTitle)}');
                final candRes = await http.get(candUri, headers: {
                  'User-Agent': _userAgent,
                }).timeout(const Duration(milliseconds: 1800));

                if (candRes.statusCode == 200) {
                  final sdata = jsonDecode(candRes.body) as Map<String, dynamic>;
                  final desc = sdata['description'] as String? ?? '';
                  final extract = sdata['extract'] as String? ?? '';
                  if (_isValidMusicEntity(desc, extract)) {
                    bio = cleanBioText(extract);
                    shortDesc = desc.isNotEmpty ? desc : 'Official Artist Profile';
                    final thumb = sdata['thumbnail']?['source'] ?? sdata['originalimage']?['source'];
                    if (thumb != null && thumb.toString().isNotEmpty) {
                      resolvedImageUrl = thumb.toString();
                    }
                    break;
                  }
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }

    if (bio == null && resolvedImageUrl == null && shortDesc == null) {
      return null;
    }

    return ArtistWikipediaResult(
      bio: bio,
      shortDescription: shortDesc,
      imageUrl: resolvedImageUrl,
    );
  }
}
