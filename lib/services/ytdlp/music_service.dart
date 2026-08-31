import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/permission_helper.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
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

  static Future<List<Song>> search(String query, {String source = 'ytmusic'}) => searchTracks(query, source: source);
  static Future<List<Song>> searchTracks(String query, {String source = 'ytmusic'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return _getHardcodedCuratedTracks();

    if (SpotifyOEmbedService.isSpotifyUrl(clean)) {
      final spotifyMeta = await SpotifyOEmbedService.fetchMetadata(clean);
      if (spotifyMeta != null) {
        final matches = await searchTracks('${spotifyMeta.title} ${spotifyMeta.authorName}');
        if (matches.isNotEmpty) {
          final first = matches.first;
          final sSong = Song(
            id: first.id,
            title: spotifyMeta.title,
            artist: spotifyMeta.authorName,
            album: 'Spotify Imported',
            artworkUrl: spotifyMeta.thumbnailUrl ?? first.artworkUrl,
            streamUrl: first.streamUrl,
            duration: first.duration,
            genre: first.genre,
            featureVector: first.featureVector,
          );
          return [sSong, ...matches.skip(1)];
        }
      }
    }

    if (source == 'ytmusic' && !kIsWeb) {
      try {
        final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
        final sBody = jsonEncode({'query': clean, 'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}});
        final sRes = await http.post(sUri, body: sBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
        if (sRes.statusCode == 200) {
          final sections = jsonDecode(sRes.body)['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;
          if (sections != null) {
            final ytSongs = <Song>[];
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
                if (vid == null && flex != null && flex.isNotEmpty) {
                  try {
                    final runs = flex[0]['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                    if (runs != null && runs.isNotEmpty) vid = (runs[0] as Map)['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
                  } catch (_) {}
                }
                if (vid != null && vid.length == 11 && t.isNotEmpty) {
                  ytSongs.add(Song(id: vid, title: t, artist: a, album: 'YouTube Music', artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg', streamUrl: null, duration: const Duration(seconds: 210), genre: 'YouTube Music', featureVector: _deriveFeatureVector(t)));
                }
              }
            }
            if (ytSongs.isNotEmpty) return ytSongs;
          }
        }
      } catch (_) {}
    }

    if (!kIsWeb) {
      try {
        const channel = MethodChannel('com.noctra.app/native_resolver');
        final List<dynamic>? nativeSongs = await channel.invokeListMethod('searchJioSaavn', {'query': clean, 'limit': 20}).timeout(const Duration(seconds: 3));
        if (nativeSongs != null && nativeSongs.isNotEmpty) {
          return nativeSongs.map((m) {
            final map = m as Map;
            return Song(id: (map['id'] ?? 'jio_${clean.hashCode}').toString(), title: (map['title'] ?? 'Unknown Track').toString(), artist: (map['artist'] ?? 'Unknown Artist').toString(), album: (map['album'] ?? 'CD Master').toString(), artworkUrl: map['thumbnail'] as String?, streamUrl: (map['stream_url'] as String?)?.isNotEmpty == true ? map['stream_url'] as String? : null, duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 210), genre: (map['source'] ?? 'JioSaavn 320k').toString(), featureVector: _deriveFeatureVector(map['title']?.toString() ?? ''));
          }).toList();
        }
      } catch (_) {}
    }

    try {
      final res = await http.get(Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=song&limit=25')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final results = jsonDecode(res.body)['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.map((item) => Song(id: 'itunes_${item['trackId']}', title: item['trackName'] ?? 'Unknown Track', artist: item['artistName'] ?? 'Unknown Artist', album: item['collectionName'] ?? '', artworkUrl: (item['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb'), streamUrl: null, duration: Duration(milliseconds: item['trackTimeMillis'] ?? 210000), genre: item['primaryGenreName'] ?? 'Music', featureVector: _deriveFeatureVector(item['trackName'] ?? ''))).toList();
        }
      }
    } catch (_) {}

    return _getHardcodedCuratedTracks().where((s) => s.title.toLowerCase().contains(clean.toLowerCase()) || s.artist.toLowerCase().contains(clean.toLowerCase())).toList();
  }

  static Future<List<Song>> fetchSimilarRadioQueue(Song currentSong) async {
    if (!kIsWeb && currentSong.id.length == 11) {
      try {
        final List<dynamic>? list = await const MethodChannel('com.noctra.app/native_resolver').invokeListMethod('fetchRadio', {'videoId': currentSong.id});
        if (list != null && list.isNotEmpty) {
          return list.map((m) {
            final map = m as Map;
            final vid = map['id'].toString();
            final title = (map['title'] ?? 'Similar Track').toString();
            final artist = (map['artist'] ?? currentSong.artist).toString();
            return Song(id: vid, title: title, artist: artist, album: 'YouTube Music Radio', artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg', streamUrl: null, duration: const Duration(seconds: 210), genre: currentSong.genre, featureVector: _deriveFeatureVector(title));
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
      {'name': 'Daft Punk', 'art': 'https://c.saavncdn.com/264/Hurry-Up-We-re-Dreaming-English-2011-500x500.jpg'},
      {'name': 'Kavinsky', 'art': 'https://c.saavncdn.com/580/Outrun-English-2013-500x500.jpg'},
    ];
    return ArtistDiscography(topTracks: top, albums: albums, singles: singles, similarArtists: similar);
  }

  static Future<double?> fetchSponsorBlockIntroSkip(String videoId) async {
    try {
      if (videoId.length != 11) return null;
      final res = await http.get(Uri.parse('https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["music_offtopic"]')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List?;
        if (data != null && data.isNotEmpty) {
          final seg = data[0]['segment'] as List?;
          if (seg != null && seg.length >= 2 && (seg[0] as num).toDouble() <= 3.0 && (seg[1] as num).toDouble() > 3.0) return (seg[1] as num).toDouble();
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Song>> fetchTrendingFeed() async => fetchTrendingTracks();
  static Future<List<Song>> fetchSpotifyCharts({String? chartKey}) async => fetchTrendingTracks();

  static Future<List<Song>> fetchTrendingTracks() async {
    try {
      final res = await http.get(Uri.parse('https://itunes.apple.com/us/rss/topsongs/limit=25/json')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final entries = jsonDecode(res.body)['feed']?['entry'] as List?;
        if (entries != null) {
          return entries.map((e) => Song(id: 'itunes_${e['id']?['attributes']?['im:id'] ?? e['title']?['label']}', title: e['im:name']?['label'] ?? 'Top Song', artist: e['im:artist']?['label'] ?? 'Top Artist', album: e['im:collection']?['im:name']?['label'] ?? '', artworkUrl: (e['im:image'] as List?)?.last?['label']?.replaceAll('170x170', '600x600'), streamUrl: null, duration: const Duration(seconds: 210), genre: e['category']?['attributes']?['label'] ?? 'Top Chart', featureVector: _deriveFeatureVector(e['im:name']?['label'] ?? ''))).toList();
        }
      }
    } catch (_) {}
    return _getHardcodedCuratedTracks();
  }

  static List<Song> _getHardcodedCuratedTracks() {
    return [
      Song(id: 'jio_cur_1', title: 'Starboy', artist: 'The Weeknd, Daft Punk', album: 'Starboy', artworkUrl: 'https://c.saavncdn.com/712/Starboy-English-2016-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/712/82aa1dcabcbddfa969e6bcf1231f6d3f_320.mp4', duration: const Duration(seconds: 230), genre: 'Synthwave', featureVector: [0.90, 0.2, 0.9, 0.4, 0.8, 0.1, 0.9, 0.3, 0.4, 0.95, 0.88, 0.2, 0.1, 0.3, 0.5, 0.9]),
      Song(id: 'jio_cur_2', title: 'Blinding Lights', artist: 'The Weeknd', album: 'After Hours', artworkUrl: 'https://c.saavncdn.com/978/After-Hours-English-2020-20200319234012-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/978/db1a7c5c0caad1ea3f524bc0ae16cb6e_320.mp4', duration: const Duration(seconds: 200), genre: 'Synthwave', featureVector: [0.95, 0.1, 0.95, 0.3, 0.9, 0.1, 0.95, 0.4, 0.5, 0.98, 0.90, 0.2, 0.1, 0.4, 0.6, 0.95]),
      Song(id: 'jio_cur_3', title: 'Midnight City', artist: 'M83', album: 'Hurry Up, We\'re Dreaming', artworkUrl: 'https://c.saavncdn.com/264/Hurry-Up-We-re-Dreaming-English-2011-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/264/0ce2a912bb0ef5d6ea72477c7f466b03_320.mp4', duration: const Duration(seconds: 243), genre: 'Indie Electro', featureVector: [0.85, 0.5, 0.8, 0.6, 0.85, 0.2, 0.75, 0.6, 0.4, 0.88, 0.80, 0.4, 0.2, 0.5, 0.7, 0.85]),
      Song(id: 'jio_cur_4', title: 'Nightcall', artist: 'Kavinsky', album: 'OutRun', artworkUrl: 'https://c.saavncdn.com/580/Outrun-English-2013-500x500.jpg', streamUrl: 'https://aac.saavncdn.com/580/28f645ea986b6a67f08ae2361661605f_320.mp4', duration: const Duration(seconds: 259), genre: 'Outrun Synth', featureVector: [0.99, 0.1, 0.7, 0.8, 0.95, 0.1, 0.6, 0.3, 0.2, 0.99, 0.95, 0.1, 0.1, 0.2, 0.4, 0.99]),
    ];
  }

  static Future<List<Song>> fetchVibeFeed(String vibeKey) async {
    final Map<String, String> vibeSearches = {'noir_night': 'The Weeknd Dark Synthwave', 'deep_focus': 'Lofi Chill Beats Study', 'high_energy': 'Electronic Workout Cyberpunk', 'ambient_chill': 'Ambient Chillout Atmospheric', 'retro_synth': 'Outrun Synthwave Retrowave 80s', 'late_night': 'Night Drive Phonk Synthwave'};
    final q = vibeSearches[vibeKey] ?? 'Synthwave Noir';
    final results = await searchTracks(q);
    return results.isNotEmpty ? results : _getHardcodedCuratedTracks();
  }

  static Future<String?> resolveStreamUrl(Song song) async => CompositeStreamResolver.resolve(song);

  static Future<Song?> downloadTrack(Song song) async {
    if (kIsWeb) return song.copyWith(isDownloaded: true);
    try {
      await PermissionHelper.requestStoragePermissions();
      Directory? baseDir;
      try { baseDir = await getExternalStorageDirectory(); } catch (_) {}
      baseDir ??= await getApplicationDocumentsDirectory();

      final dir = Directory('${baseDir.path}/Noctra_Music');
      if (!await dir.exists()) await dir.create(recursive: true);

      final streamUrl = (song.streamUrl != null && song.streamUrl!.isNotEmpty) ? song.streamUrl : await resolveStreamUrl(song);
      if (streamUrl == null || streamUrl.isEmpty) return null;

      final ext = (streamUrl.contains('.mp4') || streamUrl.contains('.m4a')) ? 'm4a' : 'mp3';
      final cleanId = song.id.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final cleanName = '${song.artist}_${song.title}'.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final safeName = '${cleanId}_${cleanName.substring(0, cleanName.length.clamp(0, 40))}';
      final filePath = '${dir.path}/$safeName.$ext';

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await client.send(request).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final total = response.contentLength ?? 0;
        int received = 0;
        final file = File(filePath);
        final sink = file.openWrite();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) downloadProgressController.add({song.id: (received / total).clamp(0.0, 1.0)});
        }).asFuture();

        await sink.close();
        downloadProgressController.add({song.id: 1.0});

        if (await file.exists() && await file.length() > 10240) {
          final downloadedSong = song.copyWith(localFilePath: filePath, isDownloaded: true, streamUrl: filePath);
          MusicRepository().addDownloadedSong(downloadedSong);
          return downloadedSong;
        }
      }
    } catch (_) {}
    return null;
  }

  static List<double> _deriveFeatureVector(String text) {
    final l = text.toLowerCase();
    final v = List<double>.filled(16, 0.45);
    if (l.contains('dark') || l.contains('night')) { v[0] = 0.95; v[10] = 0.92; }
    if (l.contains('energy') || l.contains('rock')) { v[2] = 0.95; v[14] = 0.90; }
    if (l.contains('chill') || l.contains('lofi')) { v[3] = 0.95; v[1] = 0.90; }
    if (l.contains('synth') || l.contains('cyber')) { v[6] = 0.95; v[9] = 0.98; }
    return v;
  }
}
