part of '../music_service.dart';

extension MusicServiceSearch on MusicService {
  static Future<List<Song>> _searchTracksUncached(String clean,
      {String source = 'all'}) async {
    if (SpotifyOEmbedService.isSpotifyUrl(clean)) {
      final spotifyMeta = await SpotifyOEmbedService.fetchMetadata(clean);
      if (spotifyMeta != null) {
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
      }
    }

    final List<Song> mergedResults = [];
    final Set<String> seenIds = {};
    final Set<String> seenKeys = {};

    void addSong(Song s) {
      if (s.title.isEmpty) return;
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
          }).timeout(const Duration(seconds: 4));
          if (sRes.statusCode == 200) {
            final sData = jsonDecode(sRes.body);
            _parseYtMusicSearchResults(sData, addSong);

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
                      featureVector: MusicService._deriveFeatureVector(t,
                          artist: a)));
                }
              }
            }
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    return mergedResults.isNotEmpty
        ? mergedResults
        : MusicService.fetchTrendingTracks();
  }
}
