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

class ArtistWikipediaService {
  static const String _userAgent =
      'NoctraPlayer/1.0.6 (https://github.com/nomad-guy/Noctra; dev@noctra.app)';

  static Future<ArtistWikipediaResult?> fetchBioAndImage(
      String effectiveName) async {
    String? bio;
    String? shortDesc;
    String? resolvedImageUrl;

    final candidates = [
      effectiveName,
      '$effectiveName (musician)',
      '$effectiveName (singer)',
      '$effectiveName (band)',
      '$effectiveName (rapper)',
      '$effectiveName (composer)',
    ];

    for (final candidate in candidates) {
      if (bio != null && bio.isNotEmpty) break;
      try {
        final wikiUri = Uri.parse(
            'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(candidate)}');
        final res = await http.get(wikiUri, headers: {
          'User-Agent': _userAgent,
        }).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final ptype = (data['type'] as String?)?.toLowerCase();
          if (ptype == 'disambiguation') continue;

          final title = (data['title'] as String? ?? '').toLowerCase();
          if (title.startsWith('list of ') ||
              title.contains('discography') ||
              title.contains('awards and nominations')) {
            continue;
          }

          final desc = (data['description'] as String? ?? '').toLowerCase();
          final extract = (data['extract'] as String? ?? '').toLowerCase();

          final bool isMusicEntity = desc.contains('singer') ||
              desc.contains('musician') ||
              desc.contains('band') ||
              desc.contains('rapper') ||
              desc.contains('composer') ||
              desc.contains('songwriter') ||
              desc.contains('artist') ||
              desc.contains('producer') ||
              desc.contains('playback') ||
              desc.contains('vocalist') ||
              extract.contains('singer') ||
              extract.contains('musician') ||
              extract.contains('band') ||
              extract.contains('rapper') ||
              extract.contains('album') ||
              extract.contains('song') ||
              extract.contains('discography') ||
              extract.contains('playback singer');

          if (isMusicEntity) {
            bio = data['extract'];
            shortDesc = data['description'] ?? 'Official Artist Profile';
            final thumb = data['thumbnail']?['source'] ??
                data['originalimage']?['source'];
            if (thumb != null && thumb.toString().isNotEmpty) {
              resolvedImageUrl = thumb.toString();
            }
            break;
          }
        }
      } catch (_) {}
    }

    if (bio == null) {
      try {
        final searchUri = Uri.parse(
            'https://en.wikipedia.org/w/api.php?action=opensearch&search=${Uri.encodeComponent(effectiveName)}&limit=6&namespace=0&format=json');
        final res = await http.get(searchUri, headers: {
          'User-Agent': _userAgent,
        }).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body);
          if (list is List && list.length >= 2) {
            final titles = list[1] as List?;
            if (titles != null) {
              for (final item in titles) {
                final t = item.toString();
                final lowerT = t.toLowerCase();
                if (lowerT.contains('(musician)') ||
                    lowerT.contains('(singer)') ||
                    lowerT.contains('(band)') ||
                    lowerT.contains('(rapper)')) {
                  final summaryUri = Uri.parse(
                      'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(t)}');
                  final sres = await http.get(summaryUri, headers: {
                    'User-Agent': _userAgent,
                  }).timeout(const Duration(milliseconds: 2500));
                  if (sres.statusCode == 200) {
                    final sdata =
                        jsonDecode(sres.body) as Map<String, dynamic>;
                    bio = sdata['extract'];
                    shortDesc =
                        sdata['description'] ?? 'Official Artist Profile';
                    break;
                  }
                }
              }
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
