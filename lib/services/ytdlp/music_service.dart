import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/permission_helper.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/taste_vector_engine.dart';
import '../resolvers/stream_resolver.dart';
import '../metadata/spotify_oembed_service.dart';

class ArtistDiscography {
  final List<Song> topTracks;
  final List<Map<String, dynamic>> albums, singles, similarArtists;
  ArtistDiscography({required this.topTracks, required this.albums, required this.singles, required this.similarArtists});
}

class MusicService {
  static final downloadProgressController = StreamController<Map<String, double>>.broadcast();
  static Stream<Map<String, double>> get downloadProgressStream => downloadProgressController.stream;

  static Future<List<Song>> search(String query, {String source = 'all'}) => searchTracks(query, source: source);

  static Future<List<Song>> searchTracks(String query, {String source = 'all'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return fetchTrendingTracks();

    if (SpotifyOEmbedService.isSpotifyUrl(clean)) {
      final spotifyMeta = await SpotifyOEmbedService.fetchMetadata(clean);
      if (spotifyMeta != null) {
        final matches = await searchTracks('${spotifyMeta.title} ${spotifyMeta.authorName}');
        if (matches.isNotEmpty) {
          final first = matches.first;
          final sSong = Song(id: first.id, title: spotifyMeta.title, artist: spotifyMeta.authorName, album: 'Spotify Global', artworkUrl: spotifyMeta.thumbnailUrl ?? first.artworkUrl, streamUrl: first.streamUrl, duration: first.duration, genre: first.genre, featureVector: first.featureVector);
          return [sSong, ...matches.skip(1)];
        }
      }
    }

    final List<Song> mergedResults = [];
    final Set<String> seenKeys = {};

    void addSong(Song s) {
      final key = '${s.title.toLowerCase().trim()}_${s.artist.toLowerCase().trim()}';
      if (!seenKeys.contains(key) && s.title.isNotEmpty) {
        seenKeys.add(key);
        mergedResults.add(s);
      }
    }

    final futures = <Future>[];

    if (!kIsWeb) {
      futures.add(() async {
        try {
          final List<dynamic>? nativeSongs = await const MethodChannel('com.noctra.app/native_resolver').invokeListMethod('searchJioSaavn', {'query': clean, 'limit': 20}).timeout(const Duration(seconds: 4));
          if (nativeSongs != null) {
            for (final m in nativeSongs) {
              final map = m as Map;
              addSong(Song(id: (map['id'] ?? 'jio_${clean.hashCode}').toString(), title: (map['title'] ?? 'Unknown Track').toString(), artist: (map['artist'] ?? 'Unknown Artist').toString(), album: (map['album'] ?? '320k Master').toString(), artworkUrl: map['thumbnail'] as String?, streamUrl: (map['stream_url'] as String?)?.isNotEmpty == true ? map['stream_url'] as String? : null, duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 210), genre: (map['source'] ?? '320k High-Fidelity').toString(), featureVector: _deriveFeatureVector(map['title']?.toString() ?? '')));
            }
          }
        } catch (_) {}
      }());

      futures.add(() async {
        try {
          final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
          final sBody = jsonEncode({'query': clean, 'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}});
          final sRes = await http.post(sUri, body: sBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
          if (sRes.statusCode == 200) {
            final sections = jsonDecode(sRes.body)['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;
            if (sections != null) {
              for (final sec in sections) {
                final items = (sec as Map)['itemSectionRenderer']?['contents'] as List? ?? (sec)['musicShelfRenderer']?['contents'] as List?;
                if (items == null) continue;
                for (final it in items) {
                  final r = (it as Map)['musicResponsiveListItemRenderer'] as Map?;
                  if (r == null) continue;
                  final flex = r['flexColumns'] as List?;
                  final t = (flex != null && flex.isNotEmpty) ? (flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'] ?? '').toString() : '';
                  final a = (flex != null && flex.length > 1) ? (flex[1]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'] ?? 'YouTube Music').toString() : 'YouTube Music';
                  String? vid = r['playlistItemData']?['videoId']?.toString() ?? r['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
                  if (vid != null && vid.length == 11 && t.isNotEmpty) {
                    addSong(Song(id: vid, title: t, artist: a, album: 'Global Catalog', artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg', streamUrl: null, duration: const Duration(seconds: 210), genre: 'Global Audio', featureVector: _deriveFeatureVector(t)));
                  }
                }
              }
            }
          }
        } catch (_) {}
      }());
    }

    futures.add(() async {
      try {
        final res = await http.get(Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=song&limit=25')).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final results = jsonDecode(res.body)['results'] as List?;
          if (results != null) {
            for (final item in results) {
              addSong(Song(id: 'itunes_${item['trackId']}', title: item['trackName'] ?? 'Unknown Track', artist: item['artistName'] ?? 'Unknown Artist', album: item['collectionName'] ?? 'Master Album', artworkUrl: (item['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb'), streamUrl: null, duration: Duration(milliseconds: item['trackTimeMillis'] ?? 210000), genre: item['primaryGenreName'] ?? 'Global', featureVector: _deriveFeatureVector(item['trackName'] ?? '')));
            }
          }
        }
      } catch (_) {}
    }());

    if (clean.split(' ').length >= 2 || clean.length > 10) {
      futures.add(() async {
        try {
          final lUri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(clean)}');
          final lRes = await http.get(lUri, headers: {'User-Agent': 'Noctra/1.0.4'}).timeout(const Duration(seconds: 4));
          if (lRes.statusCode == 200) {
            final lData = jsonDecode(lRes.body) as List?;
            if (lData != null) {
              for (final it in lData.take(5)) {
                final t = (it['trackName'] ?? '').toString(), a = (it['artistName'] ?? '').toString();
                if (t.isNotEmpty && a.isNotEmpty) {
                  addSong(Song(id: 'lrc_${it['id']}', title: t, artist: a, album: '${it['albumName'] ?? 'Lyrics'} • Lyric Match', artworkUrl: null, streamUrl: null, duration: Duration(seconds: (it['duration'] as num?)?.toInt() ?? 210), genre: 'Matched Lyrics', featureVector: _deriveFeatureVector(t)));
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

  static Future<List<Song>> fetchSimilarRadioQueue(Song currentSong) async {
    if (!kIsWeb && currentSong.id.length == 11) {
      try {
        final List<dynamic>? list = await const MethodChannel('com.noctra.app/native_resolver').invokeListMethod('fetchRadio', {'videoId': currentSong.id});
        if (list != null && list.isNotEmpty) {
          return list.map((m) {
            final map = m as Map;
            final vid = map['id'].toString();
            return Song(id: vid, title: (map['title'] ?? 'Similar Track').toString(), artist: (map['artist'] ?? currentSong.artist).toString(), album: 'Auto Radio', artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg', streamUrl: null, duration: const Duration(seconds: 210), genre: currentSong.genre, featureVector: _deriveFeatureVector(map['title']?.toString() ?? ''));
          }).toList();
        }
      } catch (_) {}
    }
    return searchTracks('${currentSong.title} ${currentSong.artist}');
  }

  static Future<ArtistDiscography> fetchArtistCatalog(String artistName) async {
    final clean = artistName.split(RegExp(r'[,&/]')).first.trim();
    final top = await searchTracks(clean);
    final albums = [
      {'title': '$clean: Master Essentials', 'year': '2024', 'art': top.isNotEmpty ? top.first.artworkUrl : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500', 'tracks': top.take(8).toList()},
      {'title': 'Complete Discography Deluxe', 'year': '2023', 'art': top.length > 1 ? top[1].artworkUrl : 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500', 'tracks': top.skip(4).take(8).toList()},
    ];
    final singles = [
      {'title': top.isNotEmpty ? top.first.title : 'Greatest Hit', 'year': '2024', 'art': top.isNotEmpty ? top.first.artworkUrl : null},
      {'title': top.length > 2 ? top[2].title : 'Radio Single', 'year': '2023', 'art': top.length > 2 ? top[2].artworkUrl : null},
    ];
    final similar = [
      {'name': 'The Weeknd', 'art': 'https://c.saavncdn.com/712/Starboy-English-2016-500x500.jpg'},
      {'name': 'Nusrat Fateh Ali Khan', 'art': 'https://c.saavncdn.com/978/Afreen-Afreen-Hindi-2016-500x500.jpg'},
      {'name': 'Hassan & Roshaan', 'art': 'https://c.saavncdn.com/264/Sukoon-Urdu-2022-500x500.jpg'},
    ];
    return ArtistDiscography(topTracks: top, albums: albums, singles: singles, similarArtists: similar);
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
      final res = await http.get(Uri.parse('https://itunes.apple.com/us/rss/topsongs/limit=25/json')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final entries = jsonDecode(res.body)['feed']?['entry'] as List?;
        if (entries != null && entries.isNotEmpty) {
          return entries.map((e) => Song(id: 'itunes_${e['id']?['attributes']?['im:id'] ?? e['title']?['label']}', title: e['im:name']?['label'] ?? 'Top Song', artist: e['im:artist']?['label'] ?? 'Top Artist', album: e['im:collection']?['im:name']?['label'] ?? '', artworkUrl: (e['im:image'] as List?)?.last?['label']?.replaceAll('170x170', '600x600'), streamUrl: null, duration: const Duration(seconds: 210), genre: e['category']?['attributes']?['label'] ?? 'Top Chart', featureVector: _deriveFeatureVector(e['im:name']?['label'] ?? ''))).toList();
        }
      }
    } catch (_) {}
    return searchTracks('Billboard Hot 100 Today');
  }

  static Future<List<Song>> fetchVibeFeed(String vibeKey) async {
    final Map<String, String> vibeSearches = {'noir_night': 'The Weeknd Dark Synthwave', 'deep_focus': 'Lofi Chill Beats Study', 'high_energy': 'Electronic Workout Cyberpunk', 'ambient_chill': 'Ambient Chillout Atmospheric', 'retro_synth': 'Outrun Synthwave Retrowave 80s', 'late_night': 'Night Drive Phonk Synthwave'};
    final q = vibeSearches[vibeKey] ?? 'Synthwave Noir';
    return searchTracks(q);
  }

  static Future<String?> resolveStreamUrl(Song song) async => CompositeStreamResolver.resolve(song);

  static Future<Song?> downloadTrack(Song song) async {
    if (kIsWeb) return song.copyWith(isDownloaded: true);
    try {
      await PermissionHelper.requestStoragePermissions();
      Directory? baseDir;
      try { baseDir = await getApplicationDocumentsDirectory(); } catch (_) { baseDir = await getTemporaryDirectory(); }
      final musicDir = Directory('${baseDir.path}/NoctraMusic');
      if (!musicDir.existsSync()) musicDir.createSync(recursive: true);
      final rawName = '${song.artist}_${song.title}'.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = '${rawName.isNotEmpty ? rawName : song.id}.mp3';
      final file = File('${musicDir.path}/$fileName');
      final resolvedUrl = await resolveStreamUrl(song);
      if (resolvedUrl == null) return null;
      final req = http.Request('GET', Uri.parse(resolvedUrl))..headers.addAll({'User-Agent': 'Mozilla/5.0'});
      final resp = await http.Client().send(req);
      final total = resp.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();
      await resp.stream.forEach((chunk) {
        sink.add(chunk); received += chunk.length;
        if (total > 0) downloadProgressController.add({song.id: (received / total).clamp(0.0, 1.0)});
      });
      await sink.flush(); await sink.close();
      downloadProgressController.add({song.id: 1.0});
      return song.copyWith(isDownloaded: true, localFilePath: file.path);
    } catch (_) {
      return null;
    }
  }

  static List<double> _deriveFeatureVector(String title) {
    return TasteVectorEngine.extractSongEmbedding(Song(id: '', title: title, artist: '', album: '', artworkUrl: '', streamUrl: '', duration: Duration.zero));
  }

  static Future<double?> fetchSponsorBlockIntroSkip(String videoId) async {
    try {
      final uri = Uri.parse('https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["music_offtopic"]');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List?;
        if (data != null && data.isNotEmpty) {
          final seg = data[0]['segment'] as List?;
          if (seg != null && seg.length >= 2) {
            final start = (seg[0] as num).toDouble(), end = (seg[1] as num).toDouble();
            if (start < 15.0 && end > 0) return end;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
