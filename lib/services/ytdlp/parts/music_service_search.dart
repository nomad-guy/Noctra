part of '../music_service.dart';

extension MusicServiceSearch on MusicService {
  static Future<List<Song>> _searchTracksUncached(String clean,
      {String source = 'all'}) async {
    if (SpotifyOEmbedService.isSpotifyUrl(clean)) {
      final spotifyMeta = await SpotifyOEmbedService.fetchMetadata(clean);
      if (spotifyMeta != null && spotifyMeta.title.isNotEmpty) {
        final matches = await MusicService.searchTracks(
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
        // Metadata resolved but no provider matched it: fall back to a
        // title-only query rather than the raw URL (which can only ever
        // return zero results).
        final titleOnly =
            await MusicService.searchTracks(spotifyMeta.title);
        if (titleOnly.isNotEmpty) return titleOnly;
      }
    }

    final src = source.toLowerCase().trim();
    final bool querySaavn =
        src == 'all' || src == 'saavn' || src == 'jiosaavn';
    final bool queryYt =
        src == 'all' || src == 'youtube' || src == 'ytmusic';
    final bool queryItunes =
        src == 'all' || src == 'itunes' || src == 'apple';

    // One bucket per provider, merged in fixed priority order afterwards
    // so network arrival order can never shape the visible ranking.
    final saavn = <Song>[];
    final ytSongs = <Song>[];
    final itunesSongs = <Song>[];
    final lrcSongs = <Song>[];

    void collect(List<Song> bucket, Song s) {
      if (s.title.isNotEmpty) bucket.add(s);
    }

    final futures = <Future>[];

    if (querySaavn) {
      futures.add(() async {
        try {
          final pureSongs = await JioSaavnPureEngine.searchSongs(clean, limit: 20);
          if (pureSongs.isNotEmpty) {
            for (final map in pureSongs) {
              collect(saavn, Song(
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
                  featureVector: MusicService._deriveFeatureVector(
                      map['title']?.toString() ?? '',
                      artist: map['artist']?.toString() ?? '',
                      genre: map['source']?.toString() ?? '')));
            }
          } else {
            final List<dynamic> nativeSongs =
                await NativeResolverClient.searchJioSaavn(clean, limit: 20);
            for (final m in nativeSongs) {
                final map = m as Map;
                collect(saavn, Song(
                    id: (map['id'] ??
                            'jio_${(map['title']?.toString() ?? '').hashCode}_${(map['artist']?.toString() ?? '').hashCode}')
                        .toString(),
                    title: (map['title'] ?? 'Unknown Track').toString(),
                    artist: (map['artist'] ?? 'Unknown Artist').toString(),
                    album: (map['album'] ?? '320k Master').toString(),
                    artworkUrl: map['thumbnail'] as String?,
                    streamUrl: (map['stream_url'] as String?)?.isNotEmpty ==
                            true
                        ? map['stream_url'] as String?
                        : null,
                    duration: Duration(
                        seconds: (map['duration'] as num?)?.toInt() ?? 210),
                    genre: (map['source'] ?? '320k High-Fidelity').toString(),
                    featureVector: MusicService._deriveFeatureVector(
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
          }).timeout(const Duration(milliseconds: 2500));
          if (sRes.statusCode == 200) {
            final sData = jsonDecode(sRes.body);
            _parseYtMusicSearchResults(sData, (s) => collect(ytSongs, s));
          }
        } catch (_) {}
      }());
    }

    if (queryItunes) {
      futures.add(() async {
        try {
          final itunesQuery = clean.replaceAll(RegExp(r'\s+by\s+', caseSensitive: false), ' ').trim();
          final res = await http
              .get(Uri.parse(
                  'https://itunes.apple.com/search?term=${Uri.encodeComponent(itunesQuery)}&entity=song&limit=25'))
              .timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            final results = jsonDecode(res.body)['results'] as List?;
            if (results != null) {
              for (final item in results) {
                collect(itunesSongs, Song(
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
                    featureVector: MusicService._deriveFeatureVector(
                        item['trackName'] ?? '',
                        artist: item['artistName'] ?? '',
                        album: item['collectionName'] ?? '',
                        genre: item['primaryGenreName'] ?? '')));
              }
            }
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    final ranked = SearchResultRanker.mergeAndRank(
        [saavn, ytSongs, itunesSongs], clean);
    NoctraLogger.d('Search "$clean" (src=$src) ranked ${ranked.length} '
        '(saavn=${saavn.length}, yt=${ytSongs.length}, '
        'itunes=${itunesSongs.length}, lrc=${lrcSongs.length})');
    if (ranked.isNotEmpty) {
      NoctraLogger.d('  top: ${ranked.take(5).map((s) => '${s.title} | ${s.artist}').join(' || ')}');
    }
    return ranked;
  }
}
