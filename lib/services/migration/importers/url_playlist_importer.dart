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
    } else if (cleanUrl.contains('youtube.com') ||
        cleanUrl.contains('youtu.be')) {
      return _importYouTubePlaylist(cleanUrl);
    }
    return null;
  }

  static Future<ImportedPlaylist?> _importSpotifyPlaylist(String url) async {
    try {
      final reg = RegExp(r'playlist/([a-zA-Z0-9]+)');
      final match = reg.firstMatch(url);
      final playlistId = match?.group(1);
      if (playlistId == null) return null;

      String playlistName = 'Spotify Playlist';
      try {
        final oembedUri = Uri.parse(
            'https://open.spotify.com/oembed?url=https://open.spotify.com/playlist/$playlistId');
        final oembedRes = await http.get(oembedUri).timeout(const Duration(seconds: 6));
        if (oembedRes.statusCode == 200) {
          final oembedData = jsonDecode(oembedRes.body);
          if (oembedData is Map && oembedData['title'] != null) {
            playlistName = oembedData['title'].toString();
          }
        }
      } catch (_) {}

      final embedUri =
          Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
      final embedRes = await http.get(embedUri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 8));

      final tracks = <NormalizedTrack>[];
      if (embedRes.statusCode == 200) {
        final html = embedRes.body;
        final nextDataMatch = RegExp(
                r'<script id="__NEXT_DATA__" type="application/json">([^<]+)</script>')
            .firstMatch(html);
        if (nextDataMatch != null) {
          final jsonStr = nextDataMatch.group(1);
          if (jsonStr != null) {
            final data = jsonDecode(jsonStr);
            final entity = data['props']?['pageProps']?['state']?['data']?['entity'];
            if (entity is Map) {
              if (entity['name'] != null && playlistName == 'Spotify Playlist') {
                playlistName = entity['name'].toString();
              }
              final trackList = entity['trackList'] as List? ?? [];
              for (final item in trackList) {
                if (item is Map) {
                  final tTitle = item['title']?.toString() ?? '';
                  final tArtist = item['subtitle']?.toString() ?? '';
                  if (tTitle.isNotEmpty) {
                    tracks.add(NormalizedTrack(
                      title: tTitle,
                      artist: tArtist.isNotEmpty ? tArtist : 'Various Artists',
                      source: 'spotify',
                    ));
                  }
                }
              }
            }
          }
        }
      }

      if (tracks.isEmpty) {
        // Fallback: search for title tags in HTML
        final trackRegex = RegExp(r'"name":"([^"]+)","artists":\[{"name":"([^"]+)"');
        for (final m in trackRegex.allMatches(embedRes.body)) {
          final tTitle = m.group(1) ?? '';
          final tArtist = m.group(2) ?? '';
          if (tTitle.isNotEmpty && !tracks.any((t) => t.title == tTitle)) {
            tracks.add(NormalizedTrack(
              title: tTitle,
              artist: tArtist.isNotEmpty ? tArtist : 'Various Artists',
              source: 'spotify',
            ));
          }
        }
      }

      return ImportedPlaylist(
        name: playlistName,
        source: 'spotify',
        tracks: tracks,
      );
    } catch (e) {
      NoctraLogger.w('Failed to import Spotify playlist from URL', e);
      return null;
    }
  }

  static Future<ImportedPlaylist?> _importYouTubePlaylist(String url) async {
    try {
      final reg = RegExp(r'list=([a-zA-Z0-9_-]+)');
      final match = reg.firstMatch(url);
      final playlistId = match?.group(1);
      if (playlistId == null) return null;

      final uri =
          Uri.parse('https://www.youtube.com/playlist?list=$playlistId');
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 8));

      String playlistName = 'YouTube Playlist';
      final tracks = <NormalizedTrack>[];

      if (res.statusCode == 200) {
        final html = res.body;
        final titleMatch = RegExp(r'<title>([^<]+) - YouTube</title>').firstMatch(html);
        if (titleMatch != null) {
          playlistName = titleMatch.group(1)?.trim() ?? playlistName;
        }

        final videoRegex = RegExp(
            r'"title":\{"runs":\[\{"text":"([^"]+)"\}\]\}.*?"shortBylineText":\{"runs":\[\{"text":"([^"]+)"');
        for (final m in videoRegex.allMatches(html)) {
          final vTitle = m.group(1) ?? '';
          final vAuthor = m.group(2) ?? '';
          if (vTitle.isNotEmpty && !tracks.any((t) => t.title == vTitle)) {
            tracks.add(NormalizedTrack(
              title: vTitle,
              artist: vAuthor.isNotEmpty ? vAuthor : 'YouTube',
              source: 'youtube',
            ));
          }
        }
      }

      return ImportedPlaylist(
        name: playlistName,
        source: 'youtube',
        tracks: tracks,
      );
    } catch (e) {
      NoctraLogger.w('Failed to import YouTube playlist from URL', e);
      return null;
    }
  }

  static ImportedPlaylist importFromTracklistText(
    String text, {
    String playlistName = 'Imported Tracklist',
  }) {
    final lines = text.split('\n');
    final tracks = <NormalizedTrack>[];

    for (final line in lines) {
      final clean = line.trim().replaceAll(RegExp(r'^\d+[\.\)]\s*'), '');
      if (clean.isEmpty) continue;

      String title = clean;
      String artist = 'Various Artists';

      if (clean.contains(' - ')) {
        final parts = clean.split(' - ');
        title = parts[0].trim();
        artist = parts.sublist(1).join(' - ').trim();
      } else if (clean.contains(' – ')) {
        final parts = clean.split(' – ');
        title = parts[0].trim();
        artist = parts.sublist(1).join(' – ').trim();
      } else if (clean.contains(' by ')) {
        final parts = clean.split(' by ');
        title = parts[0].trim();
        artist = parts.sublist(1).join(' by ').trim();
      }

      tracks.add(NormalizedTrack(
        title: title,
        artist: artist,
        source: 'text',
      ));
    }

    return ImportedPlaylist(
      name: playlistName,
      source: 'text',
      tracks: tracks,
    );
  }
}
