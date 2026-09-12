import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/noctra_logger.dart';
import '../../../data/models/migration_models.dart';

/// YouTube playlist page parser with InnerTube continuation paging.
///
/// The initial `ytInitialData` HTML payload only embeds the first ~100
/// videos of a playlist; [_collectYtContinuations] follows continuation
/// tokens through the InnerTube API so large playlists import completely.
class YoutubePlaylistParser {
  YoutubePlaylistParser._();

  static const _innertubeKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  static Future<ImportedPlaylist?> importFromUrl(String url) async {
    try {
      final match = RegExp(r'list=([a-zA-Z0-9_-]+)').firstMatch(url);
      final playlistId = match?.group(1);
      if (playlistId == null) return null;

      final res = await http.get(
        Uri.parse('https://www.youtube.com/playlist?list=$playlistId'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 8));

      String playlistName = 'YouTube Playlist';
      final tracks = <NormalizedTrack>[];

      if (res.statusCode == 200) {
        final html = res.body;
        final titleMatch =
            RegExp(r'<title>([^<]+) - YouTube</title>').firstMatch(html);
        if (titleMatch != null) {
          playlistName = titleMatch.group(1)?.trim() ?? playlistName;
        }

        const ytMarker = 'var ytInitialData = ';
        final ytIdx = html.indexOf(ytMarker);
        if (ytIdx != -1) {
          int endIdx = html.indexOf(';</script>', ytIdx);
          if (endIdx == -1) endIdx = html.indexOf('</script>', ytIdx);
          if (endIdx != -1) {
            final jsonStr = html
                .substring(ytIdx + ytMarker.length, endIdx)
                .trim()
                .replaceAll(RegExp(r';$'), '');
            try {
              final ytData = jsonDecode(jsonStr);
              final seen = <String>{};
              _collectYtTracks(ytData, tracks, seen);
              // Follow continuations so playlists past ~100 tracks are
              // fully imported.
              await _collectYtContinuations(ytData, tracks, seen);
            } catch (_) {}
          }
        }

        if (tracks.isEmpty) _fallbackParseYtHtml(html, tracks);
      }

      return ImportedPlaylist(
          name: playlistName, source: 'youtube', tracks: tracks);
    } catch (e) {
      NoctraLogger.w('Failed to import YouTube playlist from URL', e);
      return null;
    }
  }

  static (String, String) _splitTitleArtist(String t, String a) {
    if (t.contains(' - ') && (a == 'Various Artists' || a.isEmpty)) {
      final p = t.split(' - ');
      if (p.length == 2 && p[0].trim().isNotEmpty && p[1].trim().isNotEmpty) {
        return (p[1].trim(), p[0].trim());
      }
    }
    return (t, a);
  }

  /// Follows YouTube's continuation tokens through the InnerTube API.
  /// Never throws; stops after a bounded number of pages.
  static Future<void> _collectYtContinuations(
      dynamic root, List<NormalizedTrack> tracks, Set<String> seenIds) async {
    final tokens = <String>[];
    void findTokens(dynamic node) {
      if (node is Map) {
        final t = node['continuationCommand']?['token'];
        if (t is String && t.isNotEmpty) tokens.add(t);
        node.values.forEach(findTokens);
      } else if (node is List) {
        for (final item in node) {
          findTokens(item);
        }
      }
    }

    findTokens(root);
    const maxPages = 30; // hard cap: ~3000 extra tracks per import
    for (int page = 0; page < maxPages && tokens.isNotEmpty; page++) {
      final token = tokens.removeAt(0);
      try {
        final res = await http
            .post(
              Uri.parse(
                  'https://www.youtube.com/youtubei/v1/browse?key=$_innertubeKey'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              },
              body: jsonEncode({
                'context': {
                  'client': {
                    'clientName': 'WEB',
                    'clientVersion': '2.20240401.00.00',
                  }
                },
                'continuation': token,
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body);
        _collectYtTracks(data, tracks, seenIds);
        findTokens(data); // pages can chain further continuations
      } catch (_) {
        // Network hiccup on one page must not kill the whole import.
      }
    }
  }

  static void _collectYtTracks(
      dynamic node, List<NormalizedTrack> tracks, Set<String> seenIds) {
    if (node is Map) {
      if (node.containsKey('lockupViewModel')) {
        final lvm = node['lockupViewModel'];
        if (lvm is Map) {
          final cid = lvm['contentId']?.toString();
          if (cid != null && cid.isNotEmpty && seenIds.add(cid)) {
            final meta = lvm['metadata']?['lockupMetadataViewModel'];
            final rawTitle = meta?['title']?['content']?.toString() ?? '';
            final rows =
                meta?['metadata']?['contentMetadataViewModel']?['metadataRows']
                    as List?;
            final parts = (rows != null && rows.isNotEmpty && rows.first is Map)
                ? rows.first['metadataParts'] as List?
                : null;
            String rawArtist = 'Various Artists';
            if (parts != null && parts.isNotEmpty && parts.first is Map) {
              final tMap = parts.first['text'];
              if (tMap is Map && tMap['content'] != null) {
                final c = tMap['content'].toString();
                if (c.isNotEmpty) rawArtist = c;
              }
            }
            final (t, a) = _splitTitleArtist(rawTitle, rawArtist);
            if (t.isNotEmpty) {
              tracks.add(NormalizedTrack(
                title: t,
                artist: a,
                source: 'youtube',
                sourceId: cid,
                artworkUrl: 'https://i.ytimg.com/vi/$cid/hqdefault.jpg',
              ));
            }
          }
        }
      } else if (node.containsKey('playlistVideoRenderer')) {
        final pvr = node['playlistVideoRenderer'];
        if (pvr is Map) {
          final vid = pvr['videoId']?.toString();
          if (vid != null && vid.isNotEmpty && seenIds.add(vid)) {
            final tRuns = pvr['title']?['runs'] as List?;
            final rawTitle =
                (tRuns != null && tRuns.isNotEmpty && tRuns.first is Map)
                    ? tRuns.first['text']?.toString()
                    : (pvr['title'] is Map
                        ? pvr['title']['simpleText']?.toString()
                        : null);
            final aRuns = pvr['shortBylineText']?['runs'] as List?;
            final rawArtist = (aRuns != null &&
                    aRuns.isNotEmpty &&
                    aRuns.first is Map)
                ? aRuns.first['text']?.toString() ?? 'Various Artists'
                : 'Various Artists';
            final durSec =
                int.tryParse(pvr['lengthSeconds']?.toString() ?? '');
            final (t, a) = _splitTitleArtist(rawTitle ?? '', rawArtist);
            if (t.isNotEmpty) {
              tracks.add(NormalizedTrack(
                title: t,
                artist: a,
                source: 'youtube',
                sourceId: vid,
                artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                duration: durSec != null && durSec > 0
                    ? Duration(seconds: durSec)
                    : null,
              ));
            }
          }
        }
      }
      for (final val in node.values) {
        _collectYtTracks(val, tracks, seenIds);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectYtTracks(item, tracks, seenIds);
      }
    }
  }

  static void _fallbackParseYtHtml(
      String html, List<NormalizedTrack> tracks) {
    final chunks = html.split('"playlistVideoRenderer":');
    for (int i = 1; i < chunks.length; i++) {
      final chunk =
          chunks[i].length > 2500 ? chunks[i].substring(0, 2500) : chunks[i];
      final vid =
          RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"').firstMatch(chunk)?.group(1);
      final rawTitle =
          RegExp(r'"title":\{"runs":\[\{"text":"([^"]+)"\}\]\}')
                  .firstMatch(chunk)
                  ?.group(1) ??
              RegExp(r'"title":\{"simpleText":"([^"]+)"\}')
                  .firstMatch(chunk)
                  ?.group(1);
      final rawArtist =
          RegExp(r'"shortBylineText":\{"runs":\[\{"text":"([^"]+)"\}\]\}')
                  .firstMatch(chunk)
                  ?.group(1) ??
              'Various Artists';
      final durSec = int.tryParse(
          RegExp(r'"lengthSeconds":"(\d+)"').firstMatch(chunk)?.group(1) ??
              '');
      final (t, a) = _splitTitleArtist(rawTitle ?? '', rawArtist);
      if (t.isNotEmpty &&
          !tracks.any((tk) => tk.sourceId == vid && vid != null)) {
        tracks.add(NormalizedTrack(
          title: t,
          artist: a,
          source: 'youtube',
          sourceId: vid,
          artworkUrl:
              vid != null ? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg' : null,
          duration: durSec != null && durSec > 0
              ? Duration(seconds: durSec)
              : null,
        ));
      }
    }
  }
}
