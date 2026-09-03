import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/noctra_logger.dart';
import '../../data/models/download_location.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/taste_vector_engine.dart';
import '../../data/sources/noctra_local_database.dart';
import '../metadata/artist_metadata_service.dart';
import '../resolvers/stream_resolver.dart';
import '../metadata/spotify_oembed_service.dart';
import '../audio/stream_quality_service.dart';

class ArtistDiscography {
  final List<Song> topTracks;
  final List<Map<String, dynamic>> albums, singles, similarArtists;
  ArtistDiscography(
      {required this.topTracks,
      required this.albums,
      required this.singles,
      required this.similarArtists});
}

class _SearchCacheEntry {
  final List<Song> results;
  final int expiresAt;
  _SearchCacheEntry(this.results, this.expiresAt);
}

class MusicService {
  static final downloadProgressController =
      StreamController<Map<String, double>>.broadcast();
  static Stream<Map<String, double>> get downloadProgressStream =>
      downloadProgressController.stream;

  static final Map<String, _SearchCacheEntry> _searchCache = {};
  static final Map<String, Future<List<Song>>> _searchInFlight = {};
  static const int _maxSearchCacheSize = 60;
  static const int _searchCacheTtlMs = 5 * 60 * 1000; // 5 minutes

  static Future<List<Song>> search(String query, {String source = 'all'}) =>
      searchTracks(query, source: source);

  static Future<List<Song>> searchTracks(String query,
      {String source = 'all'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return fetchTrendingTracks();

    final cacheKey = '$source:${clean.toLowerCase()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_searchCache.containsKey(cacheKey)) {
      final entry = _searchCache[cacheKey]!;
      if (now < entry.expiresAt) {
        // Move to most recent for LRU
        _searchCache.remove(cacheKey);
        _searchCache[cacheKey] = entry;
        return entry.results;
      } else {
        _searchCache.remove(cacheKey);
      }
    }

    if (_searchInFlight.containsKey(cacheKey)) {
      return _searchInFlight[cacheKey]!;
    }

    final future = _searchTracksUncached(clean, source: source);
    _searchInFlight[cacheKey] = future;
    try {
      final results = await future;
      if (results.isNotEmpty) {
        if (_searchCache.length >= _maxSearchCacheSize) {
          _searchCache.remove(_searchCache.keys.first);
        }
        _searchCache[cacheKey] = _SearchCacheEntry(results, now + _searchCacheTtlMs);
      }
      return results;
    } finally {
      _searchInFlight.remove(cacheKey);
    }
  }

  static Future<List<Song>> _searchTracksUncached(String clean,
      {String source = 'all'}) async {
    if (SpotifyOEmbedService.isSpotifyUrl(clean)) {
      final spotifyMeta = await SpotifyOEmbedService.fetchMetadata(clean);
      if (spotifyMeta != null) {
        final matches = await searchTracks(
            '${spotifyMeta.title} ${spotifyMeta.authorName}');
        if (matches.isNotEmpty) {
          final first = matches.first;
          final sSong = Song(
              id: first.id,
              title: spotifyMeta.title,
              artist: spotifyMeta.authorName,
              album: 'Spotify Global',
              artworkUrl: spotifyMeta.thumbnailUrl ?? first.artworkUrl,
              streamUrl: first.streamUrl,
              duration: first.duration,
              genre: first.genre,
              featureVector: first.featureVector);
          return [sSong, ...matches.skip(1)];
        }
      }
    }

    final List<Song> mergedResults = [];
    final Set<String> seenIds = {};
    final Set<String> seenKeys = {};

    void addSong(Song s) {
      if (s.title.isEmpty) return;
      // Prefer id-based dedup; fall back to title+artist for sources
      // that generate synthetic ids (e.g. lrc_*, itunes_*)
      if (s.id.isNotEmpty &&
          !s.id.startsWith('lrc_') &&
          !s.id.startsWith('itunes_')) {
        if (!seenIds.add(s.id)) return;
      }
      final key =
          '${s.title.toLowerCase().trim()}_${s.artist.toLowerCase().trim()}';
      if (!seenKeys.add(key)) return;
      mergedResults.add(s);
    }

    final src = source.toLowerCase().trim();
    final bool querySaavn = src == 'all' || src == 'saavn' || src == 'jiosaavn';
    final bool queryYt = src == 'all' || src == 'youtube' || src == 'ytmusic';
    final bool queryItunes = src == 'all' || src == 'itunes' || src == 'apple';

    final futures = <Future>[];

    if (!kIsWeb && querySaavn) {
      futures.add(() async {
        try {
          final List<dynamic>? nativeSongs =
              await const MethodChannel('com.nomadguy.noctra/native_resolver')
                  .invokeListMethod('searchJioSaavn', {
            'query': clean,
            'limit': 20
          }).timeout(const Duration(seconds: 4));
          if (nativeSongs != null) {
            for (final m in nativeSongs) {
              final map = m as Map;
              addSong(Song(
                  id: (map['id'] ??
                          'jio_${(map['title']?.toString() ?? '').hashCode}_${(map['artist']?.toString() ?? '').hashCode}')
                      .toString(),
                  title: (map['title'] ?? 'Unknown Track').toString(),
                  artist: (map['artist'] ?? 'Unknown Artist').toString(),
                  album: (map['album'] ?? '320k Master').toString(),
                  artworkUrl: map['thumbnail'] as String?,
                  streamUrl: (map['stream_url'] as String?)?.isNotEmpty == true
                      ? map['stream_url'] as String?
                      : null,
                  duration: Duration(
                      seconds: (map['duration'] as num?)?.toInt() ?? 210),
                  genre: (map['source'] ?? '320k High-Fidelity').toString(),
                  featureVector: _deriveFeatureVector(
                      map['title']?.toString() ?? '',
                      artist: map['artist']?.toString() ?? '',
                      genre: map['source']?.toString() ?? '')));
            }
          }
        } catch (_) {}
      }());
    }

    if (queryYt) {
      futures.add(() async {
        try {
          final sUri =
              Uri.parse('https://music.youtube.com/youtubei/v1/search');
          final sBody = jsonEncode({
            'query': clean,
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
          }).timeout(const Duration(seconds: 4));
          if (sRes.statusCode == 200) {
            final sData = jsonDecode(sRes.body);
            _parseYtMusicSearchResults(sData, addSong);

            // If few results, also try artist-specific search
            if (mergedResults.length < 3) {
              try {
                final aUri =
                    Uri.parse('https://music.youtube.com/youtubei/v1/search');
                final aBody = jsonEncode({
                  'query': '$clean songs',
                  'context': {
                    'client': {
                      'clientName': 'WEB_REMIX',
                      'clientVersion': '1.20240820.01.00',
                      'hl': 'en',
                      'gl': 'US'
                    }
                  }
                });
                final aRes = await http.post(aUri, body: aBody, headers: {
                  'Content-Type': 'application/json',
                  'User-Agent': 'Mozilla/5.0'
                }).timeout(const Duration(seconds: 4));
                if (aRes.statusCode == 200) {
                  _parseYtMusicSearchResults(jsonDecode(aRes.body), addSong);
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }());
    }

    if (queryItunes) {
      futures.add(() async {
        try {
          final res = await http
              .get(Uri.parse(
                  'https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=song&limit=25'))
              .timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final results = jsonDecode(res.body)['results'] as List?;
            if (results != null) {
              for (final item in results) {
                addSong(Song(
                    id: 'itunes_${item['trackId']}',
                    title: item['trackName'] ?? 'Unknown Track',
                    artist: item['artistName'] ?? 'Unknown Artist',
                    album: item['collectionName'] ?? 'Master Album',
                    artworkUrl: (item['artworkUrl100'] as String?)
                        ?.replaceAll('100x100bb', '600x600bb'),
                    streamUrl: null,
                    duration: Duration(
                        milliseconds: item['trackTimeMillis'] ?? 210000),
                    genre: item['primaryGenreName'] ?? 'Global',
                    featureVector: _deriveFeatureVector(item['trackName'] ?? '',
                        artist: item['artistName'] ?? '',
                        album: item['collectionName'] ?? '',
                        genre: item['primaryGenreName'] ?? '')));
              }
            }
          }
        } catch (_) {}
      }());
    }

    if (src == 'all' && (clean.split(' ').length >= 2 || clean.length > 10)) {
      futures.add(() async {
        try {
          final lUri = Uri.parse(
              'https://lrclib.net/api/search?q=${Uri.encodeComponent(clean)}');
          final lRes = await http.get(lUri, headers: {
            'User-Agent': 'Noctra/1.0.4'
          }).timeout(const Duration(seconds: 4));
          if (lRes.statusCode == 200) {
            final lData = jsonDecode(lRes.body) as List?;
            if (lData != null) {
              for (final it in lData.take(5)) {
                final t = (it['trackName'] ?? '').toString(),
                    a = (it['artistName'] ?? '').toString();
                if (t.isNotEmpty && a.isNotEmpty) {
                  addSong(Song(
                      id: 'lrc_${it['id']}',
                      title: t,
                      artist: a,
                      album: '${it['albumName'] ?? 'Lyrics'} • Lyric Match',
                      artworkUrl: null,
                      streamUrl: null,
                      duration: Duration(
                          seconds: (it['duration'] as num?)?.toInt() ?? 210),
                      genre: 'Matched Lyrics',
                      featureVector: _deriveFeatureVector(t, artist: a)));
                }
              }
            }
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    return mergedResults.isNotEmpty ? mergedResults : fetchTrendingTracks();
  }

  /// Parse all YouTube Music search result formats:
  /// - musicResponsiveListItemRenderer (songs, videos)
  /// - musicTwoRowItemRenderer (artists, albums, playlists)
  /// - musicShelfRenderer (shelf sections with songs)
  static void _parseYtMusicSearchResults(
      Map<String, dynamic> sData, void Function(Song) addSong) {
    try {
      final sections = sData['contents']?['tabbedSearchResultsRenderer']
              ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
          ?['contents'] as List?;
      if (sections == null) return;

      for (final sec in sections) {
        final secMap = sec as Map;
        // Try itemSectionRenderer → contents
        final itemSections =
            secMap['itemSectionRenderer']?['contents'] as List?;
        // Try musicShelfRenderer → contents
        final shelfItems = secMap['musicShelfRenderer']?['contents'] as List?;
        final allItems = [
          ...?itemSections,
          ...?shelfItems,
        ];

        for (final it in allItems) {
          final itMap = it as Map;

          // Format 1: musicResponsiveListItemRenderer (songs, videos)
          final r = itMap['musicResponsiveListItemRenderer'] as Map?;
          if (r != null) {
            final flex = r['flexColumns'] as List?;
            final t = (flex != null && flex.isNotEmpty)
                ? (flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']
                            ?['runs']?[0]?['text'] ??
                        '')
                    .toString()
                : '';
            final a = (flex != null && flex.length > 1)
                ? (flex[1]['musicResponsiveListItemFlexColumnRenderer']?['text']
                            ?['runs']?[0]?['text'] ??
                        'YouTube Music')
                    .toString()
                : 'YouTube Music';
            String? vid = r['playlistItemData']?['videoId']?.toString() ??
                r['navigationEndpoint']?['watchEndpoint']?['videoId']
                    ?.toString();
            // Extract thumbnail
            String? thumb;
            try {
              final thumbnails = r['thumbnail']?['musicThumbnailRenderer']
                  ?['thumbnail']?['thumbnails'] as List?;
              if (thumbnails != null && thumbnails.isNotEmpty) {
                thumb = thumbnails.last['url']?.toString();
              }
            } catch (_) {}
            if (vid != null && vid.length == 11 && t.isNotEmpty) {
              addSong(Song(
                  id: vid,
                  title: t,
                  artist: a,
                  album: 'Global Catalog',
                  artworkUrl:
                      thumb ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                  streamUrl: null,
                  duration: const Duration(seconds: 210),
                  genre: 'Global Audio',
                  featureVector: _deriveFeatureVector(t, artist: a)));
            }
            continue;
          }

          // Format 2: musicTwoRowItemRenderer (artists, albums, playlists)
          final twoRow = itMap['musicTwoRowItemRenderer'] as Map?;
          if (twoRow != null) {
            final titleRuns = twoRow['title']?['runs'] as List?;
            final t = titleRuns?.isNotEmpty == true
                ? (titleRuns![0]['text'] ?? '').toString()
                : '';
            final subRuns = twoRow['subtitle']?['runs'] as List?;
            final subText = subRuns?.isNotEmpty == true
                ? subRuns!.map((r) => r['text'] ?? '').join().toString()
                : '';
            String? thumb;
            try {
              final thumbnails = twoRow['thumbnailRenderer']
                      ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
                  as List?;
              if (thumbnails != null && thumbnails.isNotEmpty) {
                thumb = thumbnails.last['url']?.toString();
              }
            } catch (_) {}
            // Skip artist/album/playlist cards — browse IDs are not playable.
            // Only actual track videos (with watchEndpoint) should become Songs.
            if (t.isNotEmpty && subText.toLowerCase().contains('artist')) {
              // Artist card — skip, not a playable track.
              continue;
            } else if (t.isNotEmpty) {
              // Check if this has a watchEndpoint (actual playable video)
              String? watchId;
              try {
                watchId = twoRow['navigationEndpoint']?['watchEndpoint']
                    ?['videoId']?.toString();
              } catch (_) {}
              if (watchId != null && watchId.length == 11) {
                addSong(Song(
                    id: watchId,
                    title: t,
                    artist: subText.isNotEmpty ? subText : 'YouTube Music',
                    album: 'Global Catalog',
                    artworkUrl: thumb ?? 'https://i.ytimg.com/vi/$watchId/hqdefault.jpg',
                    streamUrl: null,
                    duration: const Duration(seconds: 210),
                    genre: 'Global Audio',
                    featureVector: _deriveFeatureVector(t, artist: subText)));
              }
              // Albums, playlists, browse IDs → skip (not playable).
            }
            continue;
          }
        }
      }
    } catch (_) {}
  }

  static Future<List<Song>> fetchSimilarRadioQueue(Song currentSong, {Set<String> excludeIds = const {}}) async {
    if (!kIsWeb && currentSong.id.length == 11) {
      try {
        final List<dynamic>? list =
            await const MethodChannel('com.nomadguy.noctra/native_resolver')
                .invokeListMethod('fetchRadio', {'videoId': currentSong.id});
        if (list != null && list.isNotEmpty) {
          final blocked = {currentSong.id, ...excludeIds};
          final seen = <String>{};
          final results = <Song>[];
          for (final m in list) {
            // Validate each item independently — one malformed item must not abort the loop
            if (m is! Map) continue;
            final rawId = m['id'];
            if (rawId is! String || rawId.trim().isEmpty) continue;
            final vid = rawId.trim();
            // YouTube video IDs are exactly 11 characters
            if (vid.length != 11) continue;
            if (blocked.contains(vid) || !seen.add(vid)) continue;
            // Extract duration from native response if available
            final rawDur = m['duration'];
            final durSecs = rawDur is num ? rawDur.toInt()
                : int.tryParse(rawDur?.toString() ?? '') ?? 0;
            results.add(Song(
                id: vid,
                title: (m['title'] ?? 'Similar Track').toString(),
                artist: (m['artist'] ?? currentSong.artist).toString(),
                album: (m['album']?.toString().isNotEmpty == true)
                    ? m['album'].toString() : 'Auto Radio',
                artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                streamUrl: null,
                duration: durSecs > 0 ? Duration(seconds: durSecs)
                    : const Duration(seconds: 210),
                genre: currentSong.genre,
                featureVector: _deriveFeatureVector(
                    m['title']?.toString() ?? '',
                    artist: m['artist']?.toString() ?? currentSong.artist,
                    genre: currentSong.genre ?? '')));
          }
          // Only return native results if filtering produced actual songs
          if (results.isNotEmpty) return results;
        }
      } catch (_) {}
    }
    return searchTracks('${currentSong.title} ${currentSong.artist}');
  }

  static Future<ArtistDiscography> fetchArtistCatalog(String artistName) async {
    final clean = artistName.split(RegExp(r'[,&/]')).first.trim();
    final top = await searchTracks(clean);
    final albums = [
      {
        'title': '$clean: Master Essentials',
        'year': '2024',
        'art': top.isNotEmpty
            ? top.first.artworkUrl
            : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
        'tracks': top.take(8).toList()
      },
      {
        'title': 'Complete Discography Deluxe',
        'year': '2023',
        'art': top.length > 8
            ? top[8].artworkUrl
            : (top.length > 1
                ? top[1].artworkUrl
                : 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500'),
        'tracks': top.skip(8).take(8).toList()
      },
    ];
    final singles = [
      {
        'title': top.isNotEmpty ? top.first.title : 'Greatest Hit',
        'year': '2024',
        'art': top.isNotEmpty ? top.first.artworkUrl : null
      },
      {
        'title': top.length > 2 ? top[2].title : 'Radio Single',
        'year': '2023',
        'art': top.length > 2 ? top[2].artworkUrl : null
      },
    ];
    final dynamicSimilarNames =
        await ArtistMetadataService.fetchDynamicSimilarArtists(clean);
    final similar = <Map<String, dynamic>>[];
    for (final name in dynamicSimilarNames.take(4)) {
      final info = await ArtistMetadataService.fetchArtistInfo(name);
      similar.add({
        'name': name,
        'art': info.imageUrl ??
            (top.isNotEmpty
                ? top.first.artworkUrl
                : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500'),
      });
    }
    return ArtistDiscography(
        topTracks: top,
        albums: albums,
        singles: singles,
        similarArtists: similar);
  }

  static Future<List<Song>> fetchTrendingFeed() async => fetchTrendingTracks();
  static Future<List<Song>> fetchSpotifyCharts({String? chartKey}) async {
    final Map<String, String> chartQueries = {
      'top_hits': "Today's Top Hits Pop 2024",
      'global_50': 'Spotify Global Top 50 Chart',
      'viral_50': 'Viral Hits TikTok Trending',
      'pop_rising': 'Pop Rising Fresh Hits 2024',
      'rap_caviar': 'RapCaviar Hip Hop Top Hits',
      'bollywood': 'Bollywood Butter Arijit Singh',
      'chill_hits': 'Chill Hits Lo-Fi Acoustic Vibes',
    };
    final q = chartQueries[chartKey ?? 'top_hits'] ?? "Today's Top Hits";
    final res = await searchTracks(q);
    return res.isNotEmpty ? res : fetchTrendingTracks();
  }

  static Future<List<Song>> fetchTrendingTracks() async {
    try {
      final res = await http
          .get(Uri.parse(
              'https://itunes.apple.com/us/rss/topsongs/limit=25/json'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final entries = jsonDecode(res.body)['feed']?['entry'] as List?;
        if (entries != null && entries.isNotEmpty) {
          return entries
              .map((e) => Song(
                  id:
                      'itunes_${e['id']?['attributes']?['im:id'] ?? e['title']?['label']}',
                  title: e['im:name']?['label'] ?? 'Top Song',
                  artist: e['im:artist']?['label'] ?? 'Top Artist',
                  album: e['im:collection']?['im:name']?['label'] ?? '',
                  artworkUrl: (e['im:image'] as List?)
                      ?.last?['label']
                      ?.replaceAll('170x170', '600x600'),
                  streamUrl: null,
                  duration: const Duration(seconds: 210),
                  genre: e['category']?['attributes']?['label'] ?? 'Top Chart',
                  featureVector: _deriveFeatureVector(
                      e['im:name']?['label'] ?? '',
                      artist: e['im:artist']?['label'] ?? '',
                      album: e['im:collection']?['im:name']?['label'] ?? '',
                      genre: e['category']?['attributes']?['label'] ?? '')))
              .toList();
        }
      }
    } catch (_) {}
    return searchTracks('Billboard Hot 100 Today');
  }

  static Future<List<Song>> fetchVibeFeed(String vibeKey) async {
    final Map<String, String> vibeSearches = {
      'noir_night': 'The Weeknd Dark Synthwave',
      'deep_focus': 'Lofi Chill Beats Study',
      'high_energy': 'Electronic Workout Cyberpunk',
      'ambient_chill': 'Ambient Chillout Atmospheric',
      'retro_synth': 'Outrun Synthwave Retrowave 80s',
      'late_night': 'Night Drive Phonk Synthwave'
    };
    final q = vibeSearches[vibeKey] ?? 'Synthwave Noir';
    return searchTracks(q);
  }

  static Future<String?> resolveStreamUrl(Song song) async =>
      CompositeStreamResolver.resolve(song);

  static Future<Song?> downloadTrack(Song song) async {
    if (kIsWeb) return song.copyWith(isDownloaded: true);
    try {
      final musicDir = await const DownloadLocationResolver()
          .resolve(_selectedDownloadLocationKey());
      if (!musicDir.existsSync()) {
        musicDir.createSync(recursive: true);
      }
      if (!musicDir.existsSync()) musicDir.createSync(recursive: true);
      final rawName = '${song.artist}_${song.title}'
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final qualityService = StreamQualityService();
      final ext =
          qualityService.preferredCodec.name; // mp3, aac, flac, opus, vorbis
      final fileName = '${rawName.isNotEmpty ? rawName : song.id}.$ext';
      final file = File('${musicDir.path}/$fileName');
      final tempFile = File('${musicDir.path}/$fileName.tmp');
      final resolvedUrl = await resolveStreamUrl(song);
      if (resolvedUrl == null || resolvedUrl.isEmpty) return null;
      final parsedUri = Uri.tryParse(resolvedUrl);
      if (parsedUri == null ||
          (parsedUri.scheme != 'https' && parsedUri.scheme != 'file')) {
        NoctraLogger.w(
            'downloadTrack: Insecure or invalid URI scheme for ${song.title}');
        return null;
      }
      final req = http.Request('GET', parsedUri)
        ..headers.addAll({'User-Agent': 'Mozilla/5.0'});
      final client = http.Client();
      try {
        final resp = await client.send(req);
        final total = resp.contentLength ?? 0;
        int received = 0;
        final sink = tempFile.openWrite();
        try {
          await resp.stream.forEach((chunk) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) {
              downloadProgressController
                  .add({song.id: (received / total).clamp(0.0, 0.99)});
            } else {
              downloadProgressController
                  .add({song.id: (received / 4000000.0).clamp(0.05, 0.95)});
            }
          });
          await sink.flush();
          await sink.close();
          if (total > 0 && received < (total * 0.95)) {
            throw FormatException(
                'Incomplete download: received $received of $total bytes');
          }
          if (received < 10000) {
            throw const FormatException(
                'Downloaded audio file is too small or corrupt');
          }
          if (tempFile.existsSync()) {
            if (file.existsSync()) {
              try {
                file.deleteSync();
              } catch (_) {}
            }
            tempFile.renameSync(file.path);
          }
        } catch (e) {
          try {
            await sink.close();
          } catch (_) {}
          if (tempFile.existsSync()) {
            try {
              tempFile.deleteSync();
            } catch (_) {}
          }
          if (file.existsSync()) {
            try {
              file.deleteSync();
            } catch (_) {}
          }
          rethrow;
        }
        downloadProgressController.add({song.id: 1.0});
        return song.copyWith(isDownloaded: true, localFilePath: file.path);
      } finally {
        client.close();
      }
    } catch (e) {
      NoctraLogger.e('Track download failed for "${song.title}"', e);
      return null;
    }
  }

  static List<double> _deriveFeatureVector(String title,
      {String artist = '', String album = '', String genre = ''}) {
    return TasteVectorEngine.extractTextEmbedding(
        '$title $artist $album $genre');
  }

  static String _selectedDownloadLocationKey() {
    try {
      return NoctraLocalDatabase().getCachedDownloadLocation();
    } catch (_) {
      return DownloadLocation.appDocs;
    }
  }

  static Future<double?> fetchSponsorBlockIntroSkip(String videoId) async {
    try {
      final uri = Uri.parse(
          'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["music_offtopic"]');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List?;
        if (data != null && data.isNotEmpty) {
          final seg = data[0]['segment'] as List?;
          if (seg != null && seg.length >= 2) {
            final start = (seg[0] as num).toDouble(),
                end = (seg[1] as num).toDouble();
            if (start < 15.0 && end > 0) return end;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
