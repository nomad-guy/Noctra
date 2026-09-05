import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../data/models/song_model.dart';
import '../lyrics_matcher.dart';
import '../lyrics_service.dart';

class LyricsLrclibProvider {
  static Future<LyricsData?> searchLrclibDirect({
    required Song song,
    required String cleanTitle,
    required String primaryArtist,
    required bool preferHindi,
  }) async {
    final queries = [
      if (cleanTitle.isNotEmpty && primaryArtist.isNotEmpty)
        '$cleanTitle $primaryArtist',
      if (cleanTitle.isNotEmpty) cleanTitle,
      if (song.title != cleanTitle) song.title,
    ];

    final langHint = preferHindi ? '&lang=hi' : '';

    for (final q in queries) {
      try {
        final searchUri = Uri.parse(
            'https://lrclib.net/api/search?q=${Uri.encodeComponent(q)}$langHint');
        final sRes = await http.get(searchUri, headers: {
          'User-Agent': 'Noctra/1.0.4 (https://noctra.app)'
        }).timeout(const Duration(seconds: 4));
        if (sRes.statusCode == 200) {
          final sList = jsonDecode(sRes.body) as List?;
          if (sList != null && sList.isNotEmpty) {
            final verified = sList.where((it) {
              final lrclibTitle = (it['trackName'] as String?) ?? '';
              final lrclibArtist = (it['artistName'] as String?) ?? '';
              return LyricsMatcher.titlesMatch(song.title, lrclibTitle) &&
                  LyricsMatcher.artistMatches(primaryArtist, lrclibArtist);
            }).toList();
            final candidates = verified.isNotEmpty ? verified : [];

            if (preferHindi) {
              final devItem = candidates.firstWhere(
                (it) =>
                    LyricsMatcher.hasDevanagari(it['syncedLyrics'] ?? '') ||
                    LyricsMatcher.hasDevanagari(it['plainLyrics'] ?? ''),
                orElse: () => null,
              );
              if (devItem != null) {
                final syncedLrc = devItem['syncedLyrics'] as String?;
                if (syncedLrc != null &&
                    syncedLrc.isNotEmpty &&
                    LyricsMatcher.isValidLyrics(syncedLrc)) {
                  final lines = LyricsMatcher.parseLrc(syncedLrc);
                  if (lines.isNotEmpty) {
                    return LyricsData(
                        isSynced: true,
                        lines: lines,
                        plainText: devItem['plainLyrics'] ?? syncedLrc);
                  }
                }
                final plain = devItem['plainLyrics'] as String?;
                if (plain != null &&
                    plain.isNotEmpty &&
                    LyricsMatcher.isValidLyrics(plain)) {
                  return LyricsData(
                      isSynced: false,
                      lines: const [],
                      plainText: plain.trim());
                }
              }
            } else {
              final latinItem = candidates.firstWhere(
                (it) {
                  final lyrics = it['syncedLyrics'] as String? ?? '';
                  return lyrics.isNotEmpty &&
                      !LyricsMatcher.hasNonLatinScript(lyrics);
                },
                orElse: () => null,
              );
              if (latinItem != null) {
                final syncedLrc = latinItem['syncedLyrics'] as String?;
                if (syncedLrc != null &&
                    syncedLrc.isNotEmpty &&
                    LyricsMatcher.isValidLyrics(syncedLrc)) {
                  final lines = LyricsMatcher.parseLrc(syncedLrc);
                  if (lines.isNotEmpty) {
                    return LyricsData(
                        isSynced: true,
                        lines: lines,
                        plainText: latinItem['plainLyrics'] ?? syncedLrc);
                  }
                }
              }
            }

            for (final item in candidates) {
              final syncedLrc = item['syncedLyrics'] as String?;
              if (syncedLrc != null &&
                  syncedLrc.isNotEmpty &&
                  LyricsMatcher.isValidLyrics(syncedLrc)) {
                final lines = LyricsMatcher.parseLrc(syncedLrc);
                if (lines.isNotEmpty) {
                  return LyricsData(
                      isSynced: true,
                      lines: lines,
                      plainText: item['plainLyrics'] ?? syncedLrc);
                }
              }
            }

            for (final item in candidates) {
              final plain = item['plainLyrics'] as String?;
              if (plain != null &&
                  plain.trim().isNotEmpty &&
                  LyricsMatcher.isValidLyrics(plain)) {
                return LyricsData(
                    isSynced: false, lines: const [], plainText: plain.trim());
              }
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<LyricsData?> searchLrclibFallback({
    required Song song,
    required String cleanTitle,
    required String primaryArtist,
  }) async {
    try {
      final fallbackQueries = [
        if (primaryArtist.isNotEmpty) '$cleanTitle $primaryArtist',
        if (primaryArtist.isNotEmpty) '${song.title} $primaryArtist',
      ];
      for (final fq in fallbackQueries) {
        if (fq.isEmpty) continue;
        final uri = Uri.parse(
            'https://lrclib.net/api/search?q=${Uri.encodeComponent(fq)}');
        final res = await http.get(uri, headers: {
          'User-Agent': 'Noctra/1.0.4 (https://noctra.app)'
        }).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List?;
          if (list != null && list.isNotEmpty) {
            for (final item in list) {
              final lrclibTitle = (item['trackName'] as String?) ?? '';
              final lrclibArtist = (item['artistName'] as String?) ?? '';
              if (!LyricsMatcher.titlesMatch(song.title, lrclibTitle)) {
                continue;
              }
              if (primaryArtist.isNotEmpty &&
                  !LyricsMatcher.artistMatches(primaryArtist, lrclibArtist)) {
                continue;
              }
              final syncedLrc = item['syncedLyrics'] as String?;
              if (syncedLrc != null &&
                  syncedLrc.isNotEmpty &&
                  LyricsMatcher.isValidLyrics(syncedLrc)) {
                final lines = LyricsMatcher.parseLrc(syncedLrc);
                if (lines.isNotEmpty) {
                  return LyricsData(
                      isSynced: true,
                      lines: lines,
                      plainText: item['plainLyrics'] ?? syncedLrc);
                }
              }
              final plain = item['plainLyrics'] as String?;
              if (plain != null &&
                  plain.trim().isNotEmpty &&
                  LyricsMatcher.isValidLyrics(plain)) {
                return LyricsData(
                    isSynced: false, lines: const [], plainText: plain.trim());
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
