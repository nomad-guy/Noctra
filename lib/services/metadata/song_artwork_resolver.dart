import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/utils/bounded_concurrency.dart';
import '../../core/utils/noctra_logger.dart';
import '../../data/models/song_model.dart';
import 'artist_metadata_service.dart';

/// High-speed artwork resolution for tracks imported without album art.
///
/// Multi-tier lookup cascade:
/// 1. Direct YouTube video ID thumbnail fast path (<0.1ms).
/// 2. In-memory bounded LRU cache (<0.1ms).
/// 3. Apple Music / iTunes Search API (HD 600x600 artwork).
/// 4. Deezer Track Graph API (HD 500x500 artwork).
/// 5. High-resolution artist photo fallback.
class SongArtworkResolver {
  SongArtworkResolver._();

  static final Map<String, String> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};
  static const int _maxCacheSize = 400;
  static final BoundedConcurrency _limiter = BoundedConcurrency(3);

  static final RegExp _cleanRegex =
      RegExp(r'\[.*?\]|\(.*?\)|ft\.?.*|feat\.?.*', caseSensitive: false);

  static String _songKey(Song song) {
    final title = song.title.replaceAll(_cleanRegex, '').trim().toLowerCase();
    final artist = song.artist.split(RegExp(r'[,&/]')).first.trim().toLowerCase();
    return '${title}__$artist';
  }

  /// Sets or updates cached artwork for a known track.
  static void setCachedArtwork(Song song, String artworkUrl) {
    if (artworkUrl.isEmpty) return;
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    if (song.id.isNotEmpty) {
      _cache[song.id] = artworkUrl;
    }
    _cache[_songKey(song)] = artworkUrl;
  }

  /// Resolve high-resolution artwork for [song] asynchronously.
  static Future<String?> resolveArtwork(Song song,
      {Duration timeout = const Duration(seconds: 4)}) {
    if (song.artworkUrl != null && song.artworkUrl!.isNotEmpty) {
      return Future.value(song.artworkUrl);
    }

    if (song.id.length == 11 &&
        !song.id.contains('_') &&
        !song.id.startsWith('jam_')) {
      final ytArt = 'https://i.ytimg.com/vi/${song.id}/hqdefault.jpg';
      setCachedArtwork(song, ytArt);
      return Future.value(ytArt);
    }

    if (song.id.isNotEmpty && _cache.containsKey(song.id)) {
      return Future.value(_cache[song.id]);
    }

    final key = _songKey(song);
    if (_cache.containsKey(key)) {
      return Future.value(_cache[key]);
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final future = _limiter.run(() => _resolveInternal(song, key, timeout));
    _inFlight[key] = future;
    return future.whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<String?> _resolveInternal(
      Song song, String key, Duration timeout) async {
    final cleanTitle =
        song.title.replaceAll(_cleanRegex, '').trim();
    final cleanArtist =
        song.artist.split(RegExp(r'[,&/]')).first.trim();

    final query = cleanArtist.isNotEmpty && cleanArtist != 'Various Artists'
        ? '$cleanTitle $cleanArtist'
        : cleanTitle;

    if (query.isEmpty) return null;

    // 1. Tier 1: iTunes Search API (official 600x600 cover art)
    try {
      final itunesUri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1');
      final res = await http.get(itunesUri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      }).timeout(timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final raw = results.first['artworkUrl100']?.toString();
          if (raw != null && raw.isNotEmpty) {
            final hdArt = raw.replaceAll('100x100bb', '600x600bb');
            setCachedArtwork(song, hdArt);
            return hdArt;
          }
        }
      }
    } catch (e) {
      NoctraLogger.d('iTunes artwork lookup skipped for $query: $e');
    }

    // 2. Tier 2: Deezer Track Search API
    try {
      final deezerUri = Uri.parse(
          'https://api.deezer.com/search/track?q=${Uri.encodeComponent(query)}&limit=1');
      final res = await http.get(deezerUri, headers: {
        'User-Agent': 'Mozilla/5.0'
      }).timeout(timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['data'] as List?;
        if (list != null && list.isNotEmpty) {
          final track = list.first as Map<String, dynamic>;
          final album = track['album'] as Map<String, dynamic>?;
          final art = album?['cover_big'] ?? album?['cover_medium'];
          if (art != null && art.toString().isNotEmpty) {
            final artStr = art.toString();
            setCachedArtwork(song, artStr);
            return artStr;
          }
        }
      }
    } catch (e) {
      NoctraLogger.d('Deezer artwork lookup skipped for $query: $e');
    }

    // 3. Tier 3: Artist photo fallback
    if (cleanArtist.isNotEmpty && cleanArtist != 'Various Artists') {
      try {
        final artistMeta =
            await ArtistMetadataService.fetchArtistInfo(cleanArtist);
        if (artistMeta.imageUrl != null && artistMeta.imageUrl!.isNotEmpty) {
          setCachedArtwork(song, artistMeta.imageUrl!);
          return artistMeta.imageUrl;
        }
      } catch (_) {}
    }

    return null;
  }
}
