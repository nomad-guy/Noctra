import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../data/models/song_model.dart';
import '../audio/stream_quality_service.dart';
import 'stream_resolver_base.dart';
import 'track_matching_guard.dart';

class InnerTubeMusicResolver implements StreamResolver {
  @override
  String get sourceId => 'innertube_stream';
  @override
  Future<bool> canResolve(Song song) async => !song.id.startsWith('jam_');

  static final List<Map<String, dynamic>> innerTubeClients = [
    {
      'clientName': 'ANDROID_TESTSUITE',
      'clientVersion': '1.9',
      'androidSdkVersion': 30
    },
    {
      'clientName': 'ANDROID_MUSIC',
      'clientVersion': '6.42.52',
      'androidSdkVersion': 34
    },
    {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240820.01.00',
      'hl': 'en',
      'gl': 'US'
    },
    {
      'clientName': 'TVHTML5',
      'clientVersion': '7.20240801.12.00',
      'theme': 'TVHTML5'
    }
  ];

  static Map<String, dynamic>? _extractCandidateInfo(dynamic item) {
    if (item == null || item is! Map) return null;
    final responsive = item['musicResponsiveListItemRenderer'] as Map?;
    if (responsive == null) return null;
    final vid = responsive['playlistItemData']?['videoId']?.toString() ??
        responsive['navigationEndpoint']?['watchEndpoint']?['videoId']
            ?.toString();
    if (vid == null || vid.length != 11) return null;

    String candTitle = '';
    String candArtist = '';
    Duration? candDuration;

    final flexCols = responsive['flexColumns'] as List?;
    if (flexCols != null && flexCols.isNotEmpty) {
      final col0Runs = (flexCols[0]
              as Map?)?['musicResponsiveListItemFlexColumnRenderer']?['text']
          ?['runs'] as List?;
      if (col0Runs != null && col0Runs.isNotEmpty) {
        candTitle = col0Runs
            .map((r) => (r as Map?)?['text']?.toString() ?? '')
            .join();
      }
      if (flexCols.length > 1) {
        final col1Runs = (flexCols[1]
                as Map?)?['musicResponsiveListItemFlexColumnRenderer']?['text']
            ?['runs'] as List?;
        if (col1Runs != null && col1Runs.isNotEmpty) {
          final texts = col1Runs
              .map((r) => (r as Map?)?['text']?.toString() ?? '')
              .where((t) => t != ' • ')
              .toList();
          if (texts.isNotEmpty) {
            candArtist = texts[0];
          }
          for (final t in texts) {
            if (t.contains(':')) {
              candDuration = TrackMatchingGuard.parseDurationString(t);
            }
          }
        }
      }
    }
    return {
      'videoId': vid,
      'title': candTitle,
      'artist': candArtist,
      'duration': candDuration,
    };
  }

  @override
  Future<String?> resolveStreamUrl(Song song) async {
    try {
      String videoId = song.id;
      if (videoId.length != 11 || videoId.contains('_')) {
        final cleanTitle = song.title.replaceAll(RegExp(r'\[.*?\]'), '').trim();
        final cleanArtist = song.artist.split(RegExp(r'[,&/]')).first.trim();
        final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
        final sBody = jsonEncode({
          'query': '$cleanTitle $cleanArtist',
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20240820.01.00',
              'hl': 'en',
              'gl': 'US'
            }
          }
        });
        final sRes = await http.post(sUri, body: sBody, headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 6));
        if (sRes.statusCode == 200) {
          final sData = jsonDecode(sRes.body);
          final contents = sData['contents']?['tabbedSearchResultsRenderer']
                  ?['tabs']?[0]?['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List?;
          if (contents != null) {
            for (final sec in contents) {
              final secMap = sec as Map;
              final itemSections =
                  secMap['itemSectionRenderer']?['contents'] as List?;
              final shelfItems =
                  secMap['musicShelfRenderer']?['contents'] as List?;
              final allItems = [...?itemSections, ...?shelfItems];
              for (final item in allItems) {
                final cand = _extractCandidateInfo(item);
                if (cand != null) {
                  final candTitle = cand['title'] as String;
                  final candArtist = cand['artist'] as String;
                  final candDur = cand['duration'] as Duration?;
                  if (TrackMatchingGuard.isSafeMatch(
                    targetTitle: song.title,
                    targetArtist: song.artist,
                    targetDuration: song.duration,
                    candidateTitle:
                        candTitle.isNotEmpty ? candTitle : song.title,
                    candidateArtist:
                        candArtist.isNotEmpty ? candArtist : song.artist,
                    candidateDuration: candDur,
                  )) {
                    videoId = cand['videoId'] as String;
                    break;
                  }
                }
              }
              if (videoId.length == 11 && !videoId.contains('_')) break;
            }
          }
        }
      }

      if (videoId.length == 11) {
        if (!kIsWeb) {
          try {
            final nativeUrl =
                await const MethodChannel('com.nomadguy.noctra/native_resolver')
                    .invokeMethod<String>('extractInnerTube', {
              'videoId': videoId
            }).timeout(const Duration(seconds: 3));
            if (nativeUrl != null && nativeUrl.isNotEmpty) return nativeUrl;
          } catch (_) {}
        }

        for (final client in innerTubeClients) {
          try {
            final pUri =
                Uri.parse('https://music.youtube.com/youtubei/v1/player');
            final pBody = jsonEncode({
              'videoId': videoId,
              'context': {'client': client}
            });
            final pRes = await http.post(pUri, body: pBody, headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(seconds: 3));
            if (pRes.statusCode == 200) {
              final pData = jsonDecode(pRes.body);
              final formats =
                  pData['streamingData']?['adaptiveFormats'] as List?;
              if (formats != null && formats.isNotEmpty) {
                final audioStreams = formats
                    .where((f) =>
                        (f['mimeType'] as String?)?.contains('audio') == true)
                    .toList();
                if (audioStreams.isNotEmpty) {
                  final qualityService = StreamQualityService();
                  final List<Map<String, dynamic>> formatMaps = audioStreams
                      .map((f) => {
                            'mimeType': f['mimeType'] ?? '',
                            'bitrate': f['bitrate'] ?? 0,
                            'url': f['url'] ?? '',
                          })
                      .toList();
                  final bestUrl = qualityService.selectBestQuality(formatMaps);
                  if (bestUrl.isNotEmpty) return bestUrl;
                  audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0)
                      .compareTo((a['bitrate'] as num?) ?? 0));
                  final url = audioStreams[0]['url'] as String?;
                  if (url != null && url.isNotEmpty) return url;
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return null;
  }
}
