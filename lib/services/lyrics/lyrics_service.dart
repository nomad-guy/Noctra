import '../../data/models/song_model.dart';
import 'lyrics_matcher.dart';
import 'parts/lyrics_innertube_provider.dart';
import 'parts/lyrics_lrclib_provider.dart';
import 'parts/lyrics_provider_fallback.dart';

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
        plainText:
            'No lyrics found for this track.\nEnjoy the pure acoustic flow.',
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

  static Future<LyricsData> fetchLyrics(Song song,
      {String preference = 'English / Global'}) async {
    final cacheKey = '${song.id}_$preference';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final cleanTitle = LyricsMatcher.sanitizeTitle(song.title);
    final primaryArtist = LyricsMatcher.extractPrimaryArtist(song.artist);
    final preferenceKey = preference.toLowerCase();
    final bool preferHindi =
        preferenceKey.contains('romanized') || preferenceKey == 'hi';

    // Tier 1 & 2: LRCLIB (Direct Match + Fuzzy Multi-Query Search)
    final lrclibResult = await LyricsLrclibProvider.searchLrclibDirect(
      song: song,
      cleanTitle: cleanTitle,
      primaryArtist: primaryArtist,
      preferHindi: preferHindi,
    );
    if (lrclibResult != null) {
      _setCache(cacheKey, lrclibResult);
      return lrclibResult;
    }

    // Tier 3: Musixmatch (via broad LRCLIB search)
    final mmLyrics = await LyricsProviderFallback.fetchMusixmatchLyrics(
      cleanTitle,
      primaryArtist,
      song.title,
    );
    if (mmLyrics != null) {
      _setCache(cacheKey, mmLyrics);
      return mmLyrics;
    }

    // Tier 4: YouTube Music / InnerTube Musixmatch Extractor
    final ytLyrics = await LyricsInnertubeProvider.fetchInnerTubeLyrics(
      song.id,
      cleanTitle,
      primaryArtist,
    );
    if (ytLyrics != null) {
      _setCache(cacheKey, ytLyrics);
      return ytLyrics;
    }

    // Tier 5: JioSaavn Autocomplete & PID Lyrics
    final jioLyrics = await LyricsProviderFallback.fetchJioSaavnLyrics(
      song.title,
      cleanTitle,
      primaryArtist,
    );
    if (jioLyrics != null) {
      _setCache(cacheKey, jioLyrics);
      return jioLyrics;
    }

    // Tier 6: Last resort — LRCLIB search with artist+title combination
    final fallbackLyrics = await LyricsLrclibProvider.searchLrclibFallback(
      song: song,
      cleanTitle: cleanTitle,
      primaryArtist: primaryArtist,
    );
    if (fallbackLyrics != null) {
      _setCache(cacheKey, fallbackLyrics);
      return fallbackLyrics;
    }

    return LyricsData.empty();
  }

  // ── Test-only public wrappers for private helpers ──
  static bool titlesMatchForTest(String a, String b) =>
      LyricsMatcher.titlesMatch(a, b);
  static bool hasNonLatinScriptForTest(String text) =>
      LyricsMatcher.hasNonLatinScript(text);
  static List<LyricLine> parseLrcForTest(String lrc) =>
      LyricsMatcher.parseLrc(lrc);
  static String sanitizeTitleForTest(String title) =>
      LyricsMatcher.sanitizeTitle(title);
  static void setCacheForTest(String key, LyricsData data) =>
      _setCache(key, data);
  static void setCacheForSong(Song song, LyricsData data) {
    _setCache('${song.id}_English / Global (Standard)', data);
    _setCache('${song.id}_Romanized Hindi/Punjabi', data);
    _setCache('${song.id}_Devanagari Hindi', data);
  }

  static void clearCacheForTest() => _cache.clear();
}
