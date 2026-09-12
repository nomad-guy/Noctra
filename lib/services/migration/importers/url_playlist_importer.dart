import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/noctra_logger.dart';
import '../../../data/models/migration_models.dart';
import 'spotify_full_catalog_fetcher.dart';
import 'youtube_playlist_parser.dart';

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
      return YoutubePlaylistParser.importFromUrl(cleanUrl);
    }
    return null;
  }

  static Future<ImportedPlaylist?> _importSpotifyPlaylist(String url) async {
    try {
      final match = RegExp(r'(playlist|album)/([a-zA-Z0-9]+)').firstMatch(url);
      final entityType = match?.group(1) ?? 'playlist';
      final entityId = match?.group(2);
      if (entityId == null) return null;

      String playlistName =
          entityType == 'album' ? 'Spotify Album' : 'Spotify Playlist';
      try {
        final oRes = await http.get(Uri.parse(
          'https://open.spotify.com/oembed?url=https://open.spotify.com/$entityType/$entityId',
        )).timeout(const Duration(seconds: 6));
        if (oRes.statusCode == 200) {
          final oData = jsonDecode(oRes.body);
          if (oData is Map && oData['title'] != null) {
            playlistName = oData['title'].toString();
          }
        }
      } catch (_) {}

      final tracks = <NormalizedTrack>[];

      // PRIMARY: the private Spotify API returns the FULL track list in
      // 100-item pages. The public embed page silently truncates at 100
      // tracks, which cut off everything past track 100 in large playlists.
      await SpotifyFullCatalogFetcher.fetchAllTracks(
          entityType, entityId, tracks);

      // FALLBACK (and name/artwork source): the embed page's __NEXT_DATA__.
      final embedRes = await http.get(
        Uri.parse('https://open.spotify.com/embed/$entityType/$entityId'),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 8));

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
              final entity =
                  data['props']?['pageProps']?['state']?['data']?['entity'];
              if (entity is Map) {
                if (entity['name'] != null &&
                    playlistName == 'Spotify Playlist') {
                  playlistName = entity['name'].toString();
                }
                final coverSources = entity['coverArt']?['sources'] as List?;
                playlistArtwork =
                    (coverSources != null && coverSources.isNotEmpty && coverSources.first is Map)
                        ? coverSources.first['url']?.toString()
                        : null;
                final trackList = entity['trackList'] as List? ?? [];
                for (final item in trackList) {
                  if (item is Map) {
                    final tTitle = item['title']?.toString() ?? '';
                    final tArtist = item['subtitle']?.toString() ?? '';
                    final durMs = item['duration'] is num
                        ? (item['duration'] as num).toInt()
                        : null;
                    // Skip duplicates when the primary API path already
                    // returned this track (title+artist key).
                    if (tTitle.isNotEmpty &&
                        !tracks.any((t) =>
                            t.title == tTitle &&
                            t.artist ==
                                (tArtist.isNotEmpty
                                    ? tArtist
                                    : 'Various Artists'))) {
                      tracks.add(NormalizedTrack(
                        title: tTitle,
                        artist: tArtist.isNotEmpty
                            ? tArtist
                            : 'Various Artists',
                        source: 'spotify',
                        artworkUrl: playlistArtwork,
                        duration: durMs != null && durMs > 0
                            ? Duration(milliseconds: durMs)
                            : null,
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
        final trackRegex =
            RegExp(r'"name":"([^"]+)","artists":\[\{"name":"([^"]+)"');
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
      // If the API path got fewer than the embed page offers (or vice versa),
      // keep whichever parsed more tracks.

      return ImportedPlaylist(
          name: playlistName, source: 'spotify', tracks: tracks);
    } catch (e) {
      NoctraLogger.w('Failed to import Spotify playlist from URL', e);
      return null;
    }
  }

  static ImportedPlaylist importFromTracklistText(String text,
      {String playlistName = 'Imported Tracklist'}) {
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
    return ImportedPlaylist(
        name: playlistName, source: 'text', tracks: tracks);
  }
}
