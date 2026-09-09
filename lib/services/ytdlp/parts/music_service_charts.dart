part of '../music_service.dart';

extension MusicServiceCharts on MusicService {
  static bool _isDuplicateTitle(String a, String b) {
    String clean(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ')
        .replaceAll(
            RegExp(r'\b(official|video|audio|lyric|lyrics|remix|lofi|slowed|reverb|hd|4k|feat|ft)\b',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final ca = clean(a);
    final cb = clean(b);
    if (ca.isEmpty || cb.isEmpty) return false;
    if (ca == cb) return true;
    final wa = ca.split(' ').where((w) => w.isNotEmpty).toSet();
    final wb = cb.split(' ').where((w) => w.isNotEmpty).toSet();
    if (wa.length >= 2 && wb.length >= 2) {
      final overlap = wa.intersection(wb).length;
      final union = wa.union(wb).length;
      if (union > 0 && (overlap / union) >= 0.6) return true;
    }
    return false;
  }

  static Future<List<Song>> fetchSimilarRadioQueue(Song currentSong,
      {Set<String> excludeIds = const {}}) async {
    if (currentSong.id.length == 11) {
      try {
        final List<dynamic>? list =
            await NativeResolverClient.fetchRadio(currentSong.id);
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
            final trackTitle = (m['title'] ?? 'Similar Track').toString();
            if (_isDuplicateTitle(trackTitle, currentSong.title)) continue;
            final rawDur = m['duration'];
            final durSecs = rawDur is num
                ? rawDur.toInt()
                : int.tryParse(rawDur?.toString() ?? '') ?? 0;
            results.add(Song(
                id: vid,
                title: trackTitle,
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
                    trackTitle,
                    artist: m['artist']?.toString() ?? currentSong.artist,
                    genre: currentSong.genre ?? '')));
          }
          if (results.isNotEmpty) return results;
        }
      } catch (_) {}
    }
    final rawSearch =
        await MusicService.searchTracks('${currentSong.artist} radio');
    return rawSearch
        .where((s) =>
            s.id != currentSong.id &&
            !_isDuplicateTitle(s.title, currentSong.title))
        .toList();
  }

  static const Map<String, String> _languageToCountry = {
    'hindi': 'in',
    'punjabi': 'in',
    'tamil': 'in',
    'telugu': 'in',
    'urdu': 'in',
    'kannada': 'in',
    'malayalam': 'in',
    'marathi': 'in',
    'bengali': 'in',
    'odia': 'in',
    'gujarati': 'in',
    'spanish': 'es',
    'korean': 'kr',
    'japanese': 'jp',
    'french': 'fr',
    'german': 'de',
    'italian': 'it',
    'portuguese': 'br',
    'english': 'us',
  };

  static const Set<String> _regionalIndianLanguages = {
    'hindi',
    'punjabi',
    'tamil',
    'telugu',
    'kannada',
    'malayalam',
    'marathi',
    'bengali',
    'odia',
    'gujarati',
    'urdu',
  };

  static Future<List<Song>> fetchTrendingFeed({
    List<String>? languages,
    List<String>? genres,
    int refreshNonce = 0,
  }) async {
    final validLangs = (languages ?? const <String>[])
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final validGenres = (genres ?? const <String>[])
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    String? selectedLang;
    if (validLangs.isNotEmpty) {
      selectedLang = validLangs[refreshNonce % validLangs.length];
    }
    String? selectedGenre;
    if (validGenres.isNotEmpty) {
      selectedGenre = validGenres[refreshNonce % validGenres.length];
    }

    if (selectedLang != null) {
      final low = selectedLang.toLowerCase();
      if (_regionalIndianLanguages.contains(low)) {
        final query = refreshNonce % 2 == 0
            ? '$selectedLang Top Hits Trending'
            : '$selectedLang Latest Chartbusters';
        final regionalRes = await MusicService.searchTracks(query);
        if (regionalRes.isNotEmpty) return regionalRes;
      } else if (low == 'korean') {
        final res = await MusicService.searchTracks('K-Pop Top Hits Trending');
        if (res.isNotEmpty) return res;
      } else if (low == 'japanese') {
        final res = await MusicService.searchTracks('J-Pop Top Hits Trending');
        if (res.isNotEmpty) return res;
      } else if (low == 'spanish') {
        final res = await MusicService.searchTracks('Latin Top Hits Trending');
        if (res.isNotEmpty) return res;
      }
    }

    final country = selectedLang != null
        ? (_languageToCountry[selectedLang.toLowerCase()] ?? 'us')
        : 'us';
    final itunesTracks = await fetchTrendingTracks(countryCode: country);
    if (itunesTracks.isNotEmpty) return itunesTracks;

    final fallbackQuery = selectedGenre != null
        ? '$selectedGenre Trending Hits'
        : 'Billboard Hot 100 Today';
    return MusicService.searchTracks(fallbackQuery);
  }

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

  static Future<List<Song>> fetchTrendingTracks(
      {String countryCode = 'us'}) async {
    try {
      final res = await http
          .get(Uri.parse(
              'https://itunes.apple.com/$countryCode/rss/topsongs/limit=25/json'))
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

  static Future<List<Song>> fetchVibeFeed(String vibeKey,
      {List<String>? languages}) async {
    final Map<String, String> vibeSearches = {
      'noir_night': 'The Weeknd Dark Synthwave',
      'deep_focus': 'Lofi Chill Beats Study',
      'high_energy': 'Electronic Workout Cyberpunk',
      'ambient_chill': 'Ambient Chillout Atmospheric',
      'retro_synth': 'Outrun Synthwave Retrowave 80s',
      'late_night': 'Night Drive Phonk Synthwave'
    };
    var q = vibeSearches[vibeKey] ?? 'Synthwave Noir';
    if (languages != null && languages.isNotEmpty) {
      final lang = languages.first.trim();
      if (lang.isNotEmpty && lang.toLowerCase() != 'english') {
        q = '$lang $q';
      }
    }
    return MusicService.searchTracks(q);
  }
}
