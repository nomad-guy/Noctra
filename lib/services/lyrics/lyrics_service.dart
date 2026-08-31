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

  factory LyricsData.empty() => const LyricsData(
        isSynced: false,
        lines: [],
        plainText: 'No lyrics found for this track.\nEnjoy the pure acoustic flow.',
      );
}

class LyricsService {
  static final Map<String, LyricsData> _cache = {};
  static const int _maxCacheSize = 100;

  static void _setCache(String key, LyricsData data) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = data;
  }

  static bool _hasDevanagari(String text) => RegExp(r'[\u0900-\u097F]').hasMatch(text);

  static Future<LyricsData> fetchLyrics(Song song, {String preference = 'English / Global'}) async {
    final cacheKey = '${song.id}_$preference';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final cleanTitle = _sanitizeTitle(song.title);
    final primaryArtist = _extractPrimaryArtist(song.artist);
    final bool preferHindi = preference.toLowerCase().contains('hindi');

    // Tier 1 & 2: LRCLIB (Direct Match + Fuzzy Multi-Query Search)
    final queries = [
      if (cleanTitle.isNotEmpty && primaryArtist.isNotEmpty) '$cleanTitle $primaryArtist',
      if (cleanTitle.isNotEmpty) cleanTitle,
      if (song.title != cleanTitle) song.title,
    ];

    for (final q in queries) {
      try {
        final searchUri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(q)}');
        final sRes = await http.get(searchUri, headers: {'User-Agent': 'Noctra/1.0.4 (https://noctra.app)'}).timeout(const Duration(seconds: 4));
        if (sRes.statusCode == 200) {
          final sList = jsonDecode(sRes.body) as List?;
          if (sList != null && sList.isNotEmpty) {
            if (preferHindi) {
              final devItem = sList.firstWhere(
                (it) => _hasDevanagari(it['syncedLyrics'] ?? '') || _hasDevanagari(it['plainLyrics'] ?? ''),
                orElse: () => null,
              );
              if (devItem != null) {
                final syncedLrc = devItem['syncedLyrics'] as String?;
                if (syncedLrc != null && syncedLrc.isNotEmpty) {
                  final lines = _parseLrc(syncedLrc);
                  if (lines.isNotEmpty) {
                    final res = LyricsData(isSynced: true, lines: lines, plainText: devItem['plainLyrics'] ?? syncedLrc);
                    _setCache(cacheKey, res);
                    return res;
                  }
                }
                final plain = devItem['plainLyrics'] as String?;
                if (plain != null && plain.isNotEmpty) {
                  final res = LyricsData(isSynced: false, lines: const [], plainText: plain.trim());
                  _setCache(cacheKey, res);
                  return res;
                }
              }
            }

            // Standard synced match
            for (final item in sList) {
              final syncedLrc = item['syncedLyrics'] as String?;
              if (syncedLrc != null && syncedLrc.isNotEmpty) {
                final lines = _parseLrc(syncedLrc);
                if (lines.isNotEmpty) {
                  final res = LyricsData(isSynced: true, lines: lines, plainText: item['plainLyrics'] ?? syncedLrc);
                  _setCache(cacheKey, res);
                  return res;
                }
              }
            }

            // Plain text match
            for (final item in sList) {
              final plain = item['plainLyrics'] as String?;
              if (plain != null && plain.trim().isNotEmpty) {
                final res = LyricsData(isSynced: false, lines: const [], plainText: plain.trim());
                _setCache(cacheKey, res);
                return res;
              }
            }
          }
        }
      } catch (_) {}
    }

    // Tier 3: YouTube Music / InnerTube Musixmatch Extractor
    try {
      final ytLyrics = await _fetchInnerTubeLyrics(song.id, cleanTitle, primaryArtist);
      if (ytLyrics != null) {
        _setCache(cacheKey, ytLyrics);
        return ytLyrics;
      }
    } catch (_) {}

    // Tier 4: JioSaavn Autocomplete & PID Lyrics
    try {
      final searchUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${Uri.encodeComponent('$cleanTitle $primaryArtist')}',
      );
      final sRes = await http.get(searchUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
      if (sRes.statusCode == 200) {
        final sData = jsonDecode(sRes.body);
        final songsList = (sData['songs']?['data'] as List?) ?? [];
        for (final item in songsList) {
          final songId = item['id']?.toString() ?? '';
          if (songId.isNotEmpty) {
            final lyrUri = Uri.parse('https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&_format=json&_marker=0&cc=in&lyrics_id=$songId');
            final lRes = await http.get(lyrUri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
            if (lRes.statusCode == 200) {
              final lData = jsonDecode(lRes.body);
              final rawLyr = lData['lyrics'] as String?;
              if (rawLyr != null && rawLyr.isNotEmpty) {
                final clean = rawLyr.replaceAll('<br>', '\n').replaceAll('&quot;', '"').replaceAll('&amp;', '&').trim();
                final res = LyricsData(isSynced: false, lines: const [], plainText: clean);
                _setCache(cacheKey, res);
                return res;
              }
            }
          }
        }
      }
    } catch (_) {}

    return LyricsData.empty();
  }

  static Future<LyricsData?> _fetchInnerTubeLyrics(String rawSongId, String title, String artist) async {
    try {
      String videoId = rawSongId;
      if (videoId.startsWith('ytdlp_') || videoId.startsWith('yt_')) {
        videoId = videoId.replaceFirst('ytdlp_', '').replaceFirst('yt_', '');
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
        .replaceAll(RegExp(r'\|.*'), '')
        .replaceAll(RegExp(r'\b(feat|ft)\.?\s+.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(official\s+)?(music\s+)?(video|audio|lyrics?|track)\b.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+-\s+.*'), '')
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
