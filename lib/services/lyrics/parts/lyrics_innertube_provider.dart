import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lyrics_service.dart';

class LyricsInnertubeProvider {
  static Future<LyricsData?> fetchInnerTubeLyrics(
      String rawSongId, String title, String artist) async {
    try {
      String videoId = rawSongId;
      if (videoId.startsWith('ytdlp_') || videoId.startsWith('yt_')) {
        videoId = videoId.replaceFirst('ytdlp_', '').replaceFirst('yt_', '');
      }
      if (videoId.length == 11) {
        final nextUri = Uri.parse('https://music.youtube.com/youtubei/v1/next');
        final nextBody = jsonEncode({
          'videoId': videoId,
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20240820.01.00',
              'hl': 'en',
              'gl': 'US'
            }
          }
        });
        final nextRes = await http.post(nextUri, body: nextBody, headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 4));
        if (nextRes.statusCode == 200) {
          final nextData = jsonDecode(nextRes.body);
          final tabs = nextData['contents']
                      ?['singleColumnMusicWatchNextResultsRenderer']
                  ?['tabbedRenderer']?['watchNextTabbedResultsRenderer']
              ?['tabs'] as List?;
          final lyricsTab = tabs?.firstWhere(
              (t) =>
                  t['tabRenderer']?['title'] == 'Lyrics' ||
                  t['tabRenderer']?['endpoint']?['browseEndpoint']?['browseId']
                          ?.toString()
                          .startsWith('FE') ==
                      true,
              orElse: () => null);
          final browseId = lyricsTab?['tabRenderer']?['endpoint']
              ?['browseEndpoint']?['browseId'];
          if (browseId != null) {
            final bUri =
                Uri.parse('https://music.youtube.com/youtubei/v1/browse');
            final bBody = jsonEncode({
              'browseId': browseId,
              'context': {
                'client': {
                  'clientName': 'WEB_REMIX',
                  'clientVersion': '1.20240820.01.00',
                  'hl': 'en',
                  'gl': 'US'
                }
              }
            });
            final bRes = await http.post(bUri, body: bBody, headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(seconds: 4));
            if (bRes.statusCode == 200) {
              final bData = jsonDecode(bRes.body);
              final desc = bData['contents']?['sectionListRenderer']
                      ?['contents']?[0]?['musicDescriptionShelfRenderer']
                  ?['description']?['runs'] as List?;
              if (desc != null && desc.isNotEmpty) {
                final fullText =
                    desc.map((r) => r['text'] ?? '').join('').trim();
                if (fullText.isNotEmpty) {
                  return LyricsData(
                      isSynced: false, lines: const [], plainText: fullText);
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
