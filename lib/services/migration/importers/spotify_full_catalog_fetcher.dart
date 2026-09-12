import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/noctra_logger.dart';
import '../../../data/models/migration_models.dart';

/// Fetches the FULL track list of a Spotify playlist/album via Spotify's
/// private web API in 100-item pages.
///
/// Why this exists: the public embed page (`open.spotify.com/embed/...`)
/// silently truncates its embedded `__NEXT_DATA__` payload at ~100 tracks,
/// so imported playlists longer than 100 songs lost every track after the
/// hundredth. The private API paginates with `offset`/`limit` and returns
/// the complete catalog.
class SpotifyFullCatalogFetcher {
  SpotifyFullCatalogFetcher._();

  static const _pageSize = 100;
  static const _maxPages = 20; // hard cap: 2000 tracks per import
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  /// Appends all tracks found for [entityType]/[entityId] into [out].
  /// Returns true when at least one page was fetched successfully — callers
  /// keep the embed-page parser as fallback otherwise. Never throws.
  static Future<bool> fetchAllTracks(
    String entityType,
    String entityId,
    List<NormalizedTrack> out,
  ) async {
    try {
      bool fetchedAny = false;
      for (int page = 0; page < _maxPages; page++) {
        final offset = page * _pageSize;
        final uri = Uri.parse(
            'https://api.spotify.com/v1/$entityType/$entityId/tracks?offset=$offset&limit=$_pageSize');
        final res = await http
            .get(uri, headers: {'User-Agent': _ua})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) {
          if (page == 0) return false; // endpoint unavailable → fallback
          break;
        }
        final data = jsonDecode(res.body);
        if (data is! Map) break;
        final items = data['items'];
        if (items is! List || items.isEmpty) break;
        fetchedAny = true;

        int added = 0;
        for (final item in items) {
          if (item is! Map) continue;
          final raw = entityType == 'album' ? item : item['track'];
          final track = _trackFromItem(raw, out);
          if (track != null) {
            out.add(track);
            added++;
          }
        }

        // Total is only reported on page 0; stop when we have all of it.
        final total = (data['total'] is num) ? (data['total'] as num).toInt() : null;
        if (total == null || out.length >= total || added == 0) break;
      }
      return fetchedAny;
    } catch (e) {
      NoctraLogger.d('SpotifyFullCatalogFetcher: paging failed — $e');
      return false;
    }
  }

  /// Extracts one track from a playlist `track` object or an album item
  /// (albums wrap the track in `item` directly). Dedupes against [out].
  static NormalizedTrack? _trackFromItem(dynamic raw, List<NormalizedTrack> out) {
    if (raw is! Map) return null;
    final title = raw['name']?.toString() ?? '';
    if (title.isEmpty) return null;
    final artists = <String>[];
    final artistList = raw['artists'];
    if (artistList is List) {
      for (final a in artistList) {
        if (a is Map && a['name'] != null) artists.add(a['name'].toString());
      }
    }
    final artist = artists.isNotEmpty ? artists.join(', ') : 'Various Artists';
    if (out.any((t) => t.title == title && t.artist == artist)) {
      return null; // duplicate (paging overlap / local+featured splits)
    }
    final durMs = raw['duration_ms'];
    return NormalizedTrack(
      title: title,
      artist: artist,
      source: 'spotify',
      duration: (durMs is num && durMs > 0)
          ? Duration(milliseconds: durMs.toInt())
          : null,
    );
  }
}
