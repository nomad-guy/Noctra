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

  /// Validate that lyrics text is plausible — not too short, not corrupted.
  static bool _isValidLyrics(String text) {
    if (text.trim().length < 20) return false; // Too short to be real lyrics
    // Check for excessive garbage characters (mojibake / encoding errors)
    final printableRatio = text.replaceAll(RegExp(r'[\x00-\x08\x0E-\x1F]'), '').length / text.length;
    if (printableRatio < 0.85) return false;
    // Reject if more than 30% of lines are just 1-2 chars (fragmented/corrupted)
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      final shortLines = lines.where((l) => l.trim().length <= 2).length;
      if (shortLines / lines.length > 0.3) return false;
    }
    return true;
  }

  static Future<LyricsData> fetchLyrics(Song song, {String preference = 'English / Global'}) async {
    final cacheKey = '${song.id}_$preference';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final cleanTitle = _sanitizeTitle(song.title);
    final primaryArtist = _extractPrimaryArtist(song.artist);
    final bool preferHindi = preference.toLowerCase().contains('hindi');

    // Tier 1 & 2: LRCLIB (Direct Match + Fuzzy Multi-Query Search)
    // Build queries: prefer title+artist first, then title only, then raw title.
    final queries = [
      if (cleanTitle.isNotEmpty && primaryArtist.isNotEmpty) '$cleanTitle $primaryArtist',
      if (cleanTitle.isNotEmpty) cleanTitle,
      if (song.title != cleanTitle) song.title,
    ];

    // LRCLIB language hint for Hindi songs
    final langHint = preferHindi ? '&lang=hi' : '';

    for (final q in queries) {
      try {
        final searchUri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(q)}$langHint');
        final sRes = await http.get(searchUri, headers: {'User-Agent': 'Noctra/1.0.4 (https://noctra.app)'}).timeout(const Duration(seconds: 4));
        if (sRes.statusCode == 200) {
          final sList = jsonDecode(sRes.body) as List?;
          if (sList != null && sList.isNotEmpty) {
            // Filter: title MUST match. Artist match is a strong bonus.
            final verified = sList.where((it) {
              final lrclibTitle = (it['trackName'] as String?) ?? '';
              return _titlesMatch(song.title, lrclibTitle);
            }).toList();
            // Only use unverified results as absolute last resort (empty verified)
            final candidates = verified.isNotEmpty ? verified : [];

            if (preferHindi) {
              // Find a result with Devanagari lyrics (Hindi/Urdu)
              final devItem = candidates.firstWhere(
                (it) => _hasDevanagari(it['syncedLyrics'] ?? '') || _hasDevanagari(it['plainLyrics'] ?? ''),
                orElse: () => null,
              );
              if (devItem != null) {
                final syncedLrc = devItem['syncedLyrics'] as String?;
                if (syncedLrc != null && syncedLrc.isNotEmpty && _isValidLyrics(syncedLrc)) {
                  final lines = _parseLrc(syncedLrc);
                  if (lines.isNotEmpty) {
                    final res = LyricsData(isSynced: true, lines: lines, plainText: devItem['plainLyrics'] ?? syncedLrc);
                    _setCache(cacheKey, res);
                    return res;
                  }
                }
                final plain = devItem['plainLyrics'] as String?;
                if (plain != null && plain.isNotEmpty && _isValidLyrics(plain)) {
                  final res = LyricsData(isSynced: false, lines: const [], plainText: plain.trim());
                  _setCache(cacheKey, res);
                  return res;
                }
              }
            } else {
              // Prioritize Latin synced lyrics from verified matches
              final latinItem = candidates.firstWhere(
                (it) => !_hasDevanagari(it['syncedLyrics'] ?? '') && (it['syncedLyrics'] as String? ?? '').isNotEmpty,
                orElse: () => null,
              );
              if (latinItem != null) {
                final syncedLrc = latinItem['syncedLyrics'] as String?;
                if (syncedLrc != null && syncedLrc.isNotEmpty && _isValidLyrics(syncedLrc)) {
                  final lines = _parseLrc(syncedLrc);
                  if (lines.isNotEmpty) {
                    final res = LyricsData(isSynced: true, lines: lines, plainText: latinItem['plainLyrics'] ?? syncedLrc);
                    _setCache(cacheKey, res);
                    return res;
                  }
                }
              }
            }

            // Fallback: any synced lyrics from verified matches
            for (final item in candidates) {
              final syncedLrc = item['syncedLyrics'] as String?;
              if (syncedLrc != null && syncedLrc.isNotEmpty && _isValidLyrics(syncedLrc)) {
                final lines = _parseLrc(syncedLrc);
                if (lines.isNotEmpty) {
                  final res = LyricsData(isSynced: true, lines: lines, plainText: item['plainLyrics'] ?? syncedLrc);
                  _setCache(cacheKey, res);
                  return res;
                }
              }
            }

            // Last resort: any plain text from verified matches
            for (final item in candidates) {
              final plain = item['plainLyrics'] as String?;
              if (plain != null && plain.trim().isNotEmpty && _isValidLyrics(plain)) {
                final res = LyricsData(isSynced: false, lines: const [], plainText: plain.trim());
                _setCache(cacheKey, res);
                return res;
              }
            }
          }
        }
      } catch (_) {}
    }

    // Tier 3: Musixmatch (via lrclib proxy + direct search)
    try {
      final mmLyrics = await _fetchMusixmatchLyrics(cleanTitle, primaryArtist, song.title);
      if (mmLyrics != null) {
        _setCache(cacheKey, mmLyrics);
        return mmLyrics;
      }
    } catch (_) {}

    // Tier 4: YouTube Music / InnerTube Musixmatch Extractor
    try {
      final ytLyrics = await _fetchInnerTubeLyrics(song.id, cleanTitle, primaryArtist);
      if (ytLyrics != null) {
        _setCache(cacheKey, ytLyrics);
        return ytLyrics;
      }
    } catch (_) {}

    // Tier 5: JioSaavn Autocomplete & PID Lyrics
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
          final jiosaavnTitle = (item['title'] as String?) ?? '';
          // Only fetch lyrics if JioSaavn title matches our song
          if (songId.isNotEmpty && (jiosaavnTitle.isEmpty || _titlesMatch(song.title, jiosaavnTitle))) {
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

  /// Tier 3: Musixmatch lyrics via their public web search.
  static Future<LyricsData?> _fetchMusixmatchLyrics(String cleanTitle, String primaryArtist, String rawTitle) async {
    // Musixmatch doesn't have a free API, but their lyrics are indexed by
    // LRCLIB under the 'mus' provider. We already get those from Tier 1.
    // This tier tries a broader LRCLIB search using the raw (unsanitized)
    // title + artist to catch songs the sanitized query missed.
    try {
      final query = Uri.encodeComponent('$rawTitle $primaryArtist');
      final uri = Uri.parse('https://lrclib.net/api/search?q=$query');
      final res = await http.get(uri, headers: {'User-Agent': 'Noctra/1.0.4 (https://noctra.app)'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List?;
        if (list != null && list.isNotEmpty) {
          // Strict title match only
          final matches = list.where((it) {
            final t = (it['trackName'] as String?) ?? '';
            return _titlesMatch(rawTitle, t);
          }).toList();

          for (final item in matches) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.isNotEmpty) {
              final lines = _parseLrc(synced);
              if (lines.isNotEmpty) {
                return LyricsData(isSynced: true, lines: lines, plainText: item['plainLyrics'] ?? synced);
              }
            }
            final plain = item['plainLyrics'] as String?;
            if (plain != null && plain.trim().isNotEmpty) {
              return LyricsData(isSynced: false, lines: const [], plainText: plain.trim());
            }
          }
        }
      }
    } catch (_) {}
    return null;
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
        .replaceAll(RegExp(r'\b(feat|ft|featuring)\.?\s+.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(official\s+)?(music\s+)?(video|audio|lyrics?|track|hd|hq|4k)\b.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+-\s+.*'), '')
        .trim();
  }

  /// Simple title similarity check — returns true if two titles are likely
  /// the same song (ignores case, punctuation, extra whitespace).
  static String _normalizeForMatch(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F]'), '').trim();

  static bool _titlesMatch(String a, String b) {
    final na = _normalizeForMatch(a), nb = _normalizeForMatch(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    // One contains the other — but only if the shorter one is >= 5 chars
    // to avoid "Noor" matching "Noor-e-Jahan" or "Pathak" matching any Pathak song
    if (na.length >= 5 && na.contains(nb)) return true;
    if (nb.length >= 5 && nb.contains(na)) return true;
    // Levenshtein distance check
    final maxDist = (na.length < nb.length ? na.length : nb.length) ~/ 3;
    if (maxDist < 2) return false;
    return _levenshtein(na, nb) <= maxDist;
  }

  static int _levenshtein(String a, String b) {
    final la = a.length, lb = b.length;
    var prev = List<int>.generate(lb + 1, (j) => j);
    for (int i = 1; i <= la; i++) {
      final curr = List<int>.filled(lb + 1, 0);
      curr[0] = i;
      for (int j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      }
      prev = curr;
    }
    return prev[lb];
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
