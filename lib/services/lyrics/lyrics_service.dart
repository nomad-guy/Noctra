import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/song_model.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({required this.timestamp, required this.text});
}

class LyricsData {
  final bool isSynced;
  final List<LyricLine> lines;
  final String plainText;

  const LyricsData({
    required this.isSynced,
    required this.lines,
    required this.plainText,
  });

  static LyricsData empty(String title) => LyricsData(
        isSynced: false,
        lines: const [],
        plainText: 'Lyrics currently unavailable for "$title".\nEnjoy the 320kbps CD lossless soundscape.',
      );
}

class LyricsService {
  static final Map<String, LyricsData> _cache = {};

  static Future<LyricsData> fetchLyrics(Song song, {String preference = 'English / Global'}) async {
    final cacheKey = '${song.id}_$preference';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final cleanTitle = _sanitizeTitle(song.title);
    final primaryArtist = _extractPrimaryArtist(song.artist);

    // Tier 1: Lrclib (True Millisecond-Synced LRC Lyrics)
    try {
      final uri = Uri.parse('https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(primaryArtist)}&track_name=${Uri.encodeComponent(cleanTitle)}');
      final res = await http.get(uri, headers: {'User-Agent': 'Noctra/1.0.0 (https://noctra.app)'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final syncedLrc = data['syncedLyrics'] as String?;
        if (syncedLrc != null && syncedLrc.isNotEmpty) {
          final lines = _parseLrc(syncedLrc);
          if (lines.isNotEmpty) {
            final result = LyricsData(isSynced: true, lines: lines, plainText: data['plainLyrics'] ?? syncedLrc);
            _cache[cacheKey] = result;
            return result;
          }
        }
        final plain = data['plainLyrics'] as String?;
        if (plain != null && plain.isNotEmpty) {
          final result = LyricsData(isSynced: false, lines: const [], plainText: plain.trim());
          _cache[cacheKey] = result;
          return result;
        }
      }
    } catch (_) {}

    // Tier 2: Lrclib Global Database Fuzzy Search
    try {
      final searchUri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent('$cleanTitle $primaryArtist')}');
      final sRes = await http.get(searchUri, headers: {'User-Agent': 'Noctra/1.0.0'}).timeout(const Duration(seconds: 4));
      if (sRes.statusCode == 200) {
        final sList = jsonDecode(sRes.body) as List?;
        if (sList != null && sList.isNotEmpty) {
          for (final item in sList) {
            final syncedLrc = item['syncedLyrics'] as String?;
            if (syncedLrc != null && syncedLrc.isNotEmpty) {
              final lines = _parseLrc(syncedLrc);
              if (lines.isNotEmpty) {
                final result = LyricsData(isSynced: true, lines: lines, plainText: item['plainLyrics'] ?? syncedLrc);
                _cache[cacheKey] = result;
                return result;
              }
            }
          }
        }
      }
    } catch (_) {}

    // Tier 3: YouTube Music / InnerTube Official Musixmatch Extractor (Echo Music Engine)
    try {
      final ytLyrics = await _fetchInnerTubeLyrics(song.id, cleanTitle, primaryArtist);
      if (ytLyrics != null) {
        _cache[cacheKey] = ytLyrics;
        return ytLyrics;
      }
    } catch (_) {}

    // Tier 4: JioSaavn Official Master Lyrics (Original Hindi & Regional Script)
    try {
      final searchUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${Uri.encodeComponent('$cleanTitle $primaryArtist')}',
      );
      final sRes = await http.get(searchUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
      if (sRes.statusCode == 200) {
        final sData = jsonDecode(sRes.body);
        final songsList = (sData['songs']?['data'] as List?) ?? [];
        if (songsList.isNotEmpty) {
          final songId = songsList[0]['id']?.toString() ?? '';
          if (songId.isNotEmpty) {
            final lyrUri = Uri.parse('https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&_format=json&_marker=0&cc=in&lyrics_id=$songId');
            final lRes = await http.get(lyrUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
            if (lRes.statusCode == 200) {
              final lData = jsonDecode(lRes.body);
              final rawLyr = lData['lyrics'] as String?;
              if (rawLyr != null && rawLyr.isNotEmpty) {
                final clean = rawLyr.replaceAll('<br>', '\n').replaceAll('&quot;', '"').replaceAll('&amp;', '&').trim();
                final result = LyricsData(isSynced: false, lines: const [], plainText: clean);
                _cache[cacheKey] = result;
                return result;
              }
            }
          }
        }
      }
    } catch (_) {}

    // Tier 5: Lyrics.ovh Global REST API
    try {
      final uri = Uri.parse('https://api.lyrics.ovh/v1/${Uri.encodeComponent(primaryArtist)}/${Uri.encodeComponent(cleanTitle)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawLyrics = data['lyrics'] as String?;
        if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
          final result = LyricsData(isSynced: false, lines: const [], plainText: rawLyrics.trim());
          _cache[cacheKey] = result;
          return result;
        }
      }
    } catch (_) {}

    final empty = LyricsData.empty(song.title);
    _cache[cacheKey] = empty;
    return empty;
  }

  static Future<LyricsData?> _fetchInnerTubeLyrics(String songId, String title, String artist) async {
    try {
      String videoId = songId;
      if (videoId.length != 11 || videoId.contains('_')) {
        final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
        final sBody = jsonEncode({
          'query': '$title $artist',
          'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}
        });
        final sRes = await http.post(sUri, body: sBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
        if (sRes.statusCode == 200) {
          final sData = jsonDecode(sRes.body);
          final contents = sData['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
          if (contents != null && contents is List) {
            for (final section in contents) {
              final items = section['musicShelfRenderer']?['contents'] ?? section['musicCardShelfRenderer']?['contents'];
              if (items is List && items.isNotEmpty) {
                final top = items[0]['musicResponsiveListItemRenderer']?['playlistItemData']?['videoId'];
                if (top != null) { videoId = top.toString(); break; }
              }
            }
          }
        }
      }

      if (videoId.length == 11) {
        final nextUri = Uri.parse('https://music.youtube.com/youtubei/v1/next');
        final nextBody = jsonEncode({
          'videoId': videoId,
          'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}
        });
        final nextRes = await http.post(nextUri, body: nextBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
        if (nextRes.statusCode == 200) {
          final nextData = jsonDecode(nextRes.body);
          final tabs = nextData['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs'] as List?;
          final lyricsTab = tabs?.firstWhere((t) => t['tabRenderer']?['title'] == 'Lyrics' || t['tabRenderer']?['endpoint']?['browseEndpoint']?['browseId']?.toString().startsWith('FE') == true, orElse: () => null);
          final browseId = lyricsTab?['tabRenderer']?['endpoint']?['browseEndpoint']?['browseId'];
          if (browseId != null) {
            final bUri = Uri.parse('https://music.youtube.com/youtubei/v1/browse');
            final bBody = jsonEncode({
              'browseId': browseId,
              'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}
            });
            final bRes = await http.post(bUri, body: bBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
            if (bRes.statusCode == 200) {
              final bData = jsonDecode(bRes.body);
              final desc = bData['contents']?['sectionListRenderer']?['contents']?[0]?['musicDescriptionShelfRenderer']?['description']?['runs'] as List?;
              if (desc != null && desc.isNotEmpty) {
                final fullText = desc.map((r) => r['text'] ?? '').join('').trim();
                if (fullText.isNotEmpty) {
                  return LyricsData(isSynced: false, lines: const [], plainText: fullText);
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String _sanitizeTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'feat\..*', caseSensitive: false), '')
        .replaceAll(RegExp(r'ft\..*', caseSensitive: false), '')
        .replaceAll(RegExp(r'official.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'video.*', caseSensitive: false), '')
        .trim();
  }

  static String _extractPrimaryArtist(String artist) {
    final split = artist.split(RegExp(r'[,&/]'));
    return split.isNotEmpty ? split[0].trim() : artist;
  }

  static List<LyricLine> _parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final rawLine in lrc.split('\n')) {
      final match = regExp.firstMatch(rawLine);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3)!;
        final ms = int.parse(msStr.length == 2 ? '${msStr}0' : msStr);
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        }
      }
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
