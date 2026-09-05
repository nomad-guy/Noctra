part of '../music_service.dart';

extension MusicServiceCharts on MusicService {
  static Future<List<Song>> fetchSimilarRadioQueue(Song currentSong,
      {Set<String> excludeIds = const {}}) async {
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
            if (m is! Map) continue;
            final rawId = m['id'];
            if (rawId is! String || rawId.trim().isEmpty) continue;
            final vid = rawId.trim();
            if (vid.length != 11) continue;
            if (blocked.contains(vid) || !seen.add(vid)) continue;
            final rawDur = m['duration'];
            final durSecs = rawDur is num
                ? rawDur.toInt()
                : int.tryParse(rawDur?.toString() ?? '') ?? 0;
            results.add(Song(
                id: vid,
                title: (m['title'] ?? 'Similar Track').toString(),
                artist: (m['artist'] ?? currentSong.artist).toString(),
                album: (m['album']?.toString().isNotEmpty == true)
                    ? m['album'].toString()
                    : 'Auto Radio',
                artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                streamUrl: null,
                duration: durSecs > 0
                    ? Duration(seconds: durSecs)
                    : const Duration(seconds: 210),
                genre: currentSong.genre,
                featureVector: MusicService._deriveFeatureVector(
                    m['title']?.toString() ?? '',
                    artist: m['artist']?.toString() ?? currentSong.artist,
                    genre: currentSong.genre ?? '')));
          }
          if (results.isNotEmpty) return results;
        }
      } catch (_) {}
    }
    return MusicService.searchTracks(
        '${currentSong.title} ${currentSong.artist}');
  }

  static Future<List<Song>> fetchTrendingFeed() async =>
      fetchTrendingTracks();

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
    final res = await MusicService.searchTracks(q);
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
                  genre:
                      e['category']?['attributes']?['label'] ?? 'Top Chart',
                  featureVector: MusicService._deriveFeatureVector(
                      e['im:name']?['label'] ?? '',
                      artist: e['im:artist']?['label'] ?? '',
                      album: e['im:collection']?['im:name']?['label'] ?? '',
                      genre:
                          e['category']?['attributes']?['label'] ?? '')))
              .toList();
        }
      }
    } catch (_) {}
    return MusicService.searchTracks('Billboard Hot 100 Today');
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
    return MusicService.searchTracks(q);
  }
}
