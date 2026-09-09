import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/utils/noctra_logger.dart';

/// Pure-Dart implementation of YouTube Music InnerTube next / radio queue extraction.
/// Fully ports the functionality of Kotlin's NoctraNativeStreamEngine.fetchRadioTracks.
class InnerTubeRadioApi {
  InnerTubeRadioApi._();

  static const String _endpoint =
      'https://music.youtube.com/youtubei/v1/next';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  /// Fetches the dynamic radio queue for a given YouTube [videoId].
  static Future<List<Map<String, dynamic>>?> fetchRadioTracks(
    String videoId, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (videoId.length != 11) return null;

    final client = http.Client();
    try {
      final payload = jsonEncode({
        'videoId': videoId,
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20260213.01.00',
            'hl': 'en',
            'gl': 'US',
          }
        }
      });

      final res = await client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _userAgent,
              'X-Goog-Api-Format-Version': '1',
            },
            body: payload,
          )
          .timeout(timeout);

      if (res.statusCode != 200 || res.body.isEmpty) return null;

      final root = jsonDecode(res.body);
      if (root is! Map) return null;

      final contents = root['contents']?['singleColumnMusicWatchNextResultsRenderer']
          ?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs'];
      if (contents is! List || contents.isEmpty) return null;

      final panelContents = contents[0]?['tabRenderer']?['content']
          ?['musicQueueRenderer']?['content']?['playlistPanelRenderer']
          ?['contents'];
      if (panelContents is! List) return null;

      final results = <Map<String, dynamic>>[];
      for (final item in panelContents) {
        if (item is! Map) continue;
        final renderer = item['playlistPanelVideoRenderer'];
        if (renderer is! Map) continue;

        final vid = renderer['videoId']?.toString() ?? '';
        if (vid.length != 11) continue;

        final titleRuns = renderer['title']?['runs'] as List?;
        final title = (titleRuns != null && titleRuns.isNotEmpty)
            ? titleRuns[0]['text']?.toString() ?? ''
            : '';

        final bylineRuns = renderer['longBylineText']?['runs'] as List?;
        final artist = (bylineRuns != null && bylineRuns.isNotEmpty)
            ? bylineRuns[0]['text']?.toString() ?? 'YouTube Music'
            : 'YouTube Music';

        final lengthRuns = renderer['lengthText']?['runs'] as List?;
        final durStr = (lengthRuns != null && lengthRuns.isNotEmpty)
            ? lengthRuns[0]['text']?.toString() ?? '3:30'
            : '3:30';

        if (title.isNotEmpty) {
          results.add({
            'id': vid,
            'title': title,
            'artist': artist,
            'duration': durStr,
            'thumbnail': 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
          });
        }
      }

      return results;
    } catch (e) {
      NoctraLogger.w('InnerTubeRadioApi fetchRadioTracks failed for $videoId: $e');
      return null;
    } finally {
      client.close();
    }
  }
}
