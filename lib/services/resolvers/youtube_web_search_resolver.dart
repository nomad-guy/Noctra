import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/song_model.dart';
import 'innertube_resolver.dart';
import 'stream_resolver_base.dart';
import 'track_matching_guard.dart';

class YoutubeWebSearchResolver implements StreamResolver {
  @override
  String get sourceId => 'youtube_web_search';
  @override
  Future<bool> canResolve(Song song) async =>
      !kIsWeb && !song.id.startsWith('jam_');

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
      final sUri = Uri.parse('https://www.youtube.com/youtubei/v1/search');
      final sBody = jsonEncode({
        'query': '$cleanTitle $cleanArtist audio',
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240801.00.00',
            'hl': 'en',
            'gl': 'US',
          }
        }
      });
      final sRes = await http.post(sUri, body: sBody, headers: {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }).timeout(const Duration(seconds: 5));
      if (sRes.statusCode != 200) return null;
      final sData = jsonDecode(sRes.body);
      String? videoId;
      final contents = sData['contents']?['twoColumnSearchResultsRenderer']
          ?['primaryContents']?['sectionListRenderer']?['contents'] as List?;
      if (contents != null) {
        for (final sec in contents) {
          final items =
              (sec as Map)['itemSectionRenderer']?['contents'] as List?;
          if (items != null) {
            for (final item in items) {
              final vr = (item as Map?)?['videoRenderer'] as Map?;
              final vid = vr?['videoId']?.toString();
              if (vid != null && vid.length == 11) {
                final candTitle = vr?['title']?['runs']?[0]?['text']?.toString() ??
                    vr?['title']?['simpleText']?.toString() ?? '';
                final candArtist = vr?['ownerText']?['runs']?[0]?['text']?.toString() ?? '';
                final durationText = vr?['lengthText']?['simpleText']?.toString();
                final candDuration = TrackMatchingGuard.parseDurationString(durationText);

                if (TrackMatchingGuard.isSafeMatch(
                  targetTitle: song.title,
                  targetArtist: song.artist,
                  targetDuration: song.duration,
                  candidateTitle: candTitle.isNotEmpty ? candTitle : song.title,
                  candidateArtist: candArtist.isNotEmpty ? candArtist : song.artist,
                  candidateDuration: candDuration,
                )) {
                  videoId = vid;
                  break;
                }
              }
            }
          }
          if (videoId != null) break;
        }
      }
      if (videoId == null || videoId.length != 11) return null;

      for (final client in InnerTubeMusicResolver.innerTubeClients) {
        try {
          final pUri = Uri.parse('https://www.youtube.com/youtubei/v1/player');
          final pBody = jsonEncode({
            'videoId': videoId,
            'context': {'client': client}
          });
          final pRes = await http.post(pUri, body: pBody, headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0'
          }).timeout(const Duration(seconds: 4));
          if (pRes.statusCode == 200) {
            final pData = jsonDecode(pRes.body);
            final formats = pData['streamingData']?['adaptiveFormats'] as List?;
            if (formats != null && formats.isNotEmpty) {
              final audioStreams = formats
                  .where((f) =>
                      (f['mimeType'] as String?)?.contains('audio') == true)
                  .toList();
              if (audioStreams.isNotEmpty) {
                audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0)
                    .compareTo((a['bitrate'] as num?) ?? 0));
                final url = audioStreams[0]['url'] as String?;
                if (url != null && url.isNotEmpty) return url;
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }
}
