import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/utils/noctra_logger.dart';
import '../../../data/models/migration_models.dart';

class UrlPlaylistImporter {
  UrlPlaylistImporter._();

  static bool isPlaylistUrl(String text) {
    final lower = text.trim().toLowerCase();
    return lower.contains('spotify.com/playlist') ||
        lower.contains('youtube.com/playlist') ||
        lower.contains('music.youtube.com/playlist') ||
        lower.contains('open.spotify.com');
  }

  static Future<ImportedPlaylist?> importFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.contains('spotify.com')) {
      return _importSpotifyPlaylist(cleanUrl);
    } else if (cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be')) {
      return _importYouTubePlaylist(cleanUrl);
    }
    return null;
  }

  static Future<ImportedPlaylist?> _importSpotifyPlaylist(String url) async {
    try {
      final match = RegExp(r'(playlist|album)/([a-zA-Z0-9]+)').firstMatch(url);
      final entityType = match?.group(1) ?? 'playlist';
      final entityId = match?.group(2);
      if (entityId == null) return null;

      String playlistName = entityType == 'album' ? 'Spotify Album' : 'Spotify Playlist';
      try {
        final oRes = await http.get(Uri.parse(
          'https://open.spotify.com/oembed?url=https://open.spotify.com/$entityType/$entityId',
        )).timeout(const Duration(seconds: 6));
        if (oRes.statusCode == 200) {
          final oData = jsonDecode(oRes.body);
          if (oData is Map && oData['title'] != null) playlistName = oData['title'].toString();
        }
      } catch (_) {}

      final embedRes = await http.get(
        Uri.parse('https://open.spotify.com/embed/$entityType/$entityId'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 8));

      final tracks = <NormalizedTrack>[];
      String? playlistArtwork;
      if (embedRes.statusCode == 200) {
        final html = embedRes.body;
        const startMarker = '<script id="__NEXT_DATA__"';
        final startIdx = html.indexOf(startMarker);
        if (startIdx != -1) {
          final contentStart = html.indexOf('>', startIdx);
          final endIdx = html.indexOf('</script>', contentStart);
          if (contentStart != -1 && endIdx != -1) {
            try {
              final jsonStr = html.substring(contentStart + 1, endIdx);
              final data = jsonDecode(jsonStr);
              final entity = data['props']?['pageProps']?['state']?['data']?['entity'];
              if (entity is Map) {
                if (entity['name'] != null && playlistName == 'Spotify Playlist') {
                  playlistName = entity['name'].toString();
                }
                final coverSources = entity['coverArt']?['sources'] as List?;
                playlistArtwork = (coverSources != null && coverSources.isNotEmpty && coverSources.first is Map)
                    ? coverSources.first['url']?.toString()
                    : null;
                final trackList = entity['trackList'] as List? ?? [];
                for (final item in trackList) {
                  if (item is Map) {
                    final tTitle = item['title']?.toString() ?? '';
                    final tArtist = item['subtitle']?.toString() ?? '';
                    final durMs = item['duration'] is num ? (item['duration'] as num).toInt() : null;
                    if (tTitle.isNotEmpty) {
                      tracks.add(NormalizedTrack(
                        title: tTitle,
                        artist: tArtist.isNotEmpty ? tArtist : 'Various Artists',
                        source: 'spotify',
                        artworkUrl: playlistArtwork,
                        duration: durMs != null && durMs > 0 ? Duration(milliseconds: durMs) : null,
                      ));
                    }
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      if (tracks.isEmpty) {
        final trackRegex = RegExp(r'"name":"([^"]+)","artists":\[{"name":"([^"]+)"');
        for (final m in trackRegex.allMatches(embedRes.body)) {
          final tTitle = m.group(1) ?? '';
          final tArtist = m.group(2) ?? '';
          if (tTitle.isNotEmpty && !tracks.any((t) => t.title == tTitle)) {
            tracks.add(NormalizedTrack(
              title: tTitle,
              artist: tArtist.isNotEmpty ? tArtist : 'Various Artists',
              source: 'spotify',
              artworkUrl: playlistArtwork,
            ));
          }
        }
      }

      return ImportedPlaylist(name: playlistName, source: 'spotify', tracks: tracks);
    } catch (e) {
      NoctraLogger.w('Failed to import Spotify playlist from URL', e);
      return null;
    }
  }

  static Future<ImportedPlaylist?> _importYouTubePlaylist(String url) async {
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
        final titleMatch = RegExp(r'<title>([^<]+) - YouTube</title>').firstMatch(html);
        if (titleMatch != null) playlistName = titleMatch.group(1)?.trim() ?? playlistName;

        const ytMarker = 'var ytInitialData = ';
        final ytIdx = html.indexOf(ytMarker);
        if (ytIdx != -1) {
          int endIdx = html.indexOf(';</script>', ytIdx);
          if (endIdx == -1) endIdx = html.indexOf('</script>', ytIdx);
          if (endIdx != -1) {
            final jsonStr = html.substring(ytIdx + ytMarker.length, endIdx).trim().replaceAll(RegExp(r';$'), '');
            try {
              final ytData = jsonDecode(jsonStr);
              _collectYtTracks(ytData, tracks, <String>{});
            } catch (_) {}
          }
        }

        if (tracks.isEmpty) _fallbackParseYtHtml(html, tracks);
      }

      return ImportedPlaylist(name: playlistName, source: 'youtube', tracks: tracks);
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

  static void _collectYtTracks(dynamic node, List<NormalizedTrack> tracks, Set<String> seenIds) {
    if (node is Map) {
      if (node.containsKey('lockupViewModel')) {
        final lvm = node['lockupViewModel'];
        if (lvm is Map) {
          final cid = lvm['contentId']?.toString();
          if (cid != null && cid.isNotEmpty && seenIds.add(cid)) {
            final meta = lvm['metadata']?['lockupMetadataViewModel'];
            final rawTitle = meta?['title']?['content']?.toString() ?? '';
            final rows = meta?['metadata']?['contentMetadataViewModel']?['metadataRows'] as List?;
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
            final rawTitle = (tRuns != null && tRuns.isNotEmpty && tRuns.first is Map)
                ? tRuns.first['text']?.toString()
                : (pvr['title'] is Map ? pvr['title']['simpleText']?.toString() : null);
            final aRuns = pvr['shortBylineText']?['runs'] as List?;
            final rawArtist = (aRuns != null && aRuns.isNotEmpty && aRuns.first is Map)
                ? aRuns.first['text']?.toString() ?? 'Various Artists'
                : 'Various Artists';
            final durSec = int.tryParse(pvr['lengthSeconds']?.toString() ?? '');
            final (t, a) = _splitTitleArtist(rawTitle ?? '', rawArtist);
            if (t.isNotEmpty) {
              tracks.add(NormalizedTrack(
                title: t,
                artist: a,
                source: 'youtube',
                sourceId: vid,
                artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                duration: durSec != null && durSec > 0 ? Duration(seconds: durSec) : null,
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

  static void _fallbackParseYtHtml(String html, List<NormalizedTrack> tracks) {
    final chunks = html.split('"playlistVideoRenderer":');
    for (int i = 1; i < chunks.length; i++) {
      final chunk = chunks[i].length > 2500 ? chunks[i].substring(0, 2500) : chunks[i];
      final vid = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"').firstMatch(chunk)?.group(1);
      final rawTitle = RegExp(r'"title":\{"runs":\[\{"text":"([^"]+)"\}\]\}').firstMatch(chunk)?.group(1) ??
          RegExp(r'"title":\{"simpleText":"([^"]+)"\}').firstMatch(chunk)?.group(1);
      final rawArtist = RegExp(r'"shortBylineText":\{"runs":\[\{"text":"([^"]+)"\}\]\}').firstMatch(chunk)?.group(1) ??
          'Various Artists';
      final durSec = int.tryParse(RegExp(r'"lengthSeconds":"(\d+)"').firstMatch(chunk)?.group(1) ?? '');
      final (t, a) = _splitTitleArtist(rawTitle ?? '', rawArtist);
      if (t.isNotEmpty && !tracks.any((tk) => tk.sourceId == vid && vid != null)) {
        tracks.add(NormalizedTrack(
          title: t,
          artist: a,
          source: 'youtube',
          sourceId: vid,
          artworkUrl: vid != null ? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg' : null,
          duration: durSec != null && durSec > 0 ? Duration(seconds: durSec) : null,
        ));
      }
    }
  }

  static ImportedPlaylist importFromTracklistText(String text, {String playlistName = 'Imported Tracklist'}) {
    final tracks = <NormalizedTrack>[];
    for (final raw in text.split('\n')) {
      final clean = raw.trim().replaceAll(RegExp(r'^\d+[\.\)]\s*'), '');
      if (clean.isEmpty) continue;
      String title = clean;
      String artist = 'Various Artists';
      for (final sep in [' - ', ' – ', ' by ']) {
        if (clean.contains(sep)) {
          final p = clean.split(sep);
          title = p[0].trim();
          artist = p.sublist(1).join(sep).trim();
          break;
        }
      }
      tracks.add(NormalizedTrack(title: title, artist: artist, source: 'text'));
    }
    return ImportedPlaylist(name: playlistName, source: 'text', tracks: tracks);
  }
}
