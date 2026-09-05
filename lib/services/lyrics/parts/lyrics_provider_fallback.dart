import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lyrics_matcher.dart';
import '../lyrics_service.dart';

class LyricsProviderFallback {
  /// JioSaavn lyrics endpoint with [songId] percent-encoded so a hostile
  /// id cannot smuggle extra query parameters or fragments into the URL.
  /// Public so deterministic tests can pin the exact wire shape.
  static Uri jioSaavnLyricsUri(String songId) => Uri.parse(
      'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&_format=json&_marker=0&cc=in&lyrics_id=${Uri.encodeComponent(songId)}');

  static Future<LyricsData?> fetchMusixmatchLyrics(
      String cleanTitle, String primaryArtist, String rawTitle) async {
    try {
      final query = Uri.encodeComponent('$rawTitle $primaryArtist');
      final uri = Uri.parse('https://lrclib.net/api/search?q=$query');
      final res = await http.get(uri, headers: {
        'User-Agent': 'Noctra/1.0.4 (https://noctra.app)'
      }).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List?;
        if (list != null && list.isNotEmpty) {
          final matches = list.where((it) {
            final t = (it['trackName'] as String?) ?? '';
            return LyricsMatcher.titlesMatch(rawTitle, t);
          }).toList();

          for (final item in matches) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.isNotEmpty) {
              final lines = LyricsMatcher.parseLrc(synced);
              if (lines.isNotEmpty) {
                return LyricsData(
                    isSynced: true,
                    lines: lines,
                    plainText: item['plainLyrics'] ?? synced);
              }
            }
            final plain = item['plainLyrics'] as String?;
            if (plain != null && plain.trim().isNotEmpty) {
              return LyricsData(
                  isSynced: false, lines: const [], plainText: plain.trim());
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<LyricsData?> fetchJioSaavnLyrics(
      String rawTitle, String cleanTitle, String primaryArtist) async {
    try {
      final searchUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${Uri.encodeComponent('$cleanTitle $primaryArtist')}',
      );
      final sRes = await http.get(searchUri, headers: {
        'User-Agent': 'Mozilla/5.0'
      }).timeout(const Duration(seconds: 4));
      if (sRes.statusCode == 200) {
        final sData = jsonDecode(sRes.body);
        final songsList = (sData['songs']?['data'] as List?) ?? [];
        for (final item in songsList) {
          final songId = item['id']?.toString() ?? '';
          final jiosaavnTitle = (item['title'] as String?) ?? '';
          final titleMatch = songId.isNotEmpty &&
              jiosaavnTitle.isNotEmpty &&
              LyricsMatcher.titlesMatch(rawTitle, jiosaavnTitle);
          if (titleMatch) {
            final lyrUri = jioSaavnLyricsUri(songId);
            final lRes = await http.get(lyrUri, headers: {
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(seconds: 4));
            if (lRes.statusCode == 200) {
              final lData = jsonDecode(lRes.body);
              final rawLyr = lData['lyrics'] as String?;
              if (rawLyr != null && rawLyr.isNotEmpty) {
                final clean = rawLyr
                    .replaceAll('<br>', '\n')
                    .replaceAll('&quot;', '"')
                    .replaceAll('&amp;', '&')
                    .replaceAll('<p>', '')
                    .replaceAll('</p>', '')
                    .replaceAll('<strong>', '')
                    .replaceAll('</strong>', '')
                    .replaceAll('<i>', '')
                    .replaceAll('</i>', '')
                    .replaceAll('<br/>', '\n')
                    .replaceAll('<BR/>', '\n')
                    .replaceAll('<BR>', '\n')
                    .replaceAll('<br />', '\n')
                    .replaceAll(RegExp(r'<[^>]+>'), '')
                    .trim();
                if (clean.isNotEmpty && LyricsMatcher.isValidLyrics(clean)) {
                  return LyricsData(
                      isSynced: false, lines: const [], plainText: clean);
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
