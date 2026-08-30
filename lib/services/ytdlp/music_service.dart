import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/permission_helper.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../resolvers/stream_resolver.dart';

class MusicService {
  static const String baseUrl = 'http://127.0.0.1:8088';

  static Future<bool> isSidecarActive() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(milliseconds: 300));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<List<Song>> search(String query, {String? source}) async => searchTracks(query);

  static Future<List<String>> fetchSearchSuggestions(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    try {
      final uri = Uri.parse('https://suggestqueries-clients6.youtube.com/complete/search?client=youtube&ds=yt&q=${Uri.encodeComponent(clean)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final body = res.body;
        final start = body.indexOf('(');
        final end = body.lastIndexOf(')');
        if (start != -1 && end != -1) {
          final jsonStr = body.substring(start + 1, end);
          final data = jsonDecode(jsonStr);
          final raw = data[1] as List?;
          if (raw != null) {
            return raw.map((item) => (item[0] ?? '').toString()).where((s) => s.isNotEmpty).take(8).toList();
          }
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Song>> searchTracks(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final uri = Uri.parse('https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&includeMetaTags=1&p=1&n=25&q=${Uri.encodeComponent(clean)}');
      final res = await http.get(uri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.map((item) {
            final title = (item['title'] ?? item['song'] ?? 'Unknown').toString().replaceAll('&quot;', '"').replaceAll('&amp;', '&').replaceAll('&#039;', "'");
            final artist = (item['more_info']?['artistMap']?['primary_artists']?[0]?['name'] ?? item['more_info']?['music'] ?? item['primary_artists'] ?? 'Unknown').toString().replaceAll('&quot;', '"').replaceAll('&amp;', '&');
            final img = (item['image'] ?? '').toString().replaceAll('150x150', '500x500');
            final dur = int.tryParse(item['more_info']?['duration']?.toString() ?? '210') ?? 210;
            return Song(
              id: 'saavn_${item['id']}',
              title: title,
              artist: artist,
              album: (item['album'] ?? '').toString().replaceAll('&quot;', '"').replaceAll('&amp;', '&'),
              artworkUrl: img,
              streamUrl: null,
              duration: Duration(seconds: dur),
              genre: (item['language'] ?? 'Music').toString(),
              featureVector: _deriveFeatureVector(title),
            );
          }).toList();
        }
      }
    } catch (_) {}

    try {
      final uri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=song&limit=25');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.map((item) => Song(
            id: 'itunes_${item['trackId']}',
            title: item['trackName'] ?? 'Unknown Track',
            artist: item['artistName'] ?? 'Unknown Artist',
            album: item['collectionName'] ?? '',
            artworkUrl: (item['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb'),
            streamUrl: null,
            duration: Duration(milliseconds: item['trackTimeMillis'] ?? 210000),
            genre: item['primaryGenreName'] ?? 'Music',
            featureVector: _deriveFeatureVector(item['trackName'] ?? ''),
          )).toList();
        }
      }
    } catch (_) {}

    return _getHardcodedCuratedTracks().where((s) => s.title.toLowerCase().contains(clean.toLowerCase()) || s.artist.toLowerCase().contains(clean.toLowerCase())).toList();
  }

  static Future<List<Song>> fetchSimilarRadioQueue(Song currentSong) async {
    try {
      final query = '${currentSong.title} ${currentSong.artist}';
      final sUri = Uri.parse('https://music.youtube.com/youtubei/v1/search');
      final sBody = jsonEncode({
        'query': query,
        'context': {'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20240820.01.00', 'hl': 'en', 'gl': 'US'}}
      });
      final sRes = await http.post(sUri, body: sBody, headers: {'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 3));
      if (sRes.statusCode == 200) {
        final sData = jsonDecode(sRes.body);
        final contents = sData['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
        if (contents != null && contents is List) {
          final songs = <Song>[];
          for (final section in contents) {
            final items = section['musicShelfRenderer']?['contents'] ?? section['musicCardShelfRenderer']?['contents'];
            if (items is List) {
              for (final item in items.take(12)) {
                final vid = item['musicResponsiveListItemRenderer']?['playlistItemData']?['videoId'];
                final title = item['musicResponsiveListItemRenderer']?['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'] ?? 'Similar Track';
                final artist = item['musicResponsiveListItemRenderer']?['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'] ?? currentSong.artist;
                if (vid != null) {
                  songs.add(Song(
                    id: vid.toString(),
                    title: title.toString(),
                    artist: artist.toString(),
                    album: 'YouTube Music Radio',
                    artworkUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                    streamUrl: null,
                    duration: const Duration(seconds: 210),
                    genre: currentSong.genre,
                    featureVector: _deriveFeatureVector(title.toString()),
                  ));
                }
              }
            }
          }
          if (songs.isNotEmpty) return songs;
        }
      }
    } catch (_) {}
    return _getHardcodedCuratedTracks();
  }

  static Future<double?> fetchSponsorBlockIntroSkip(String videoId) async {
    try {
      if (videoId.length != 11) return null;
      final uri = Uri.parse('https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["music_offtopic"]');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List?;
        if (data != null && data.isNotEmpty) {
          final seg = data[0]['segment'] as List?;
          if (seg != null && seg.length >= 2) {
            final start = (seg[0] as num).toDouble();
            final end = (seg[1] as num).toDouble();
            if (start <= 3.0 && end > 3.0) return end;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Song>> fetchTrendingFeed() async => fetchTrendingTracks();
  static Future<List<Song>> fetchSpotifyCharts({String? chartKey}) async => fetchTrendingTracks();

  static Future<List<Song>> fetchTrendingTracks() async {
    try {
      final uri = Uri.parse('https://itunes.apple.com/us/rss/topsongs/limit=25/json');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final entries = data['feed']?['entry'] as List?;
        if (entries != null) {
          return entries.map((e) => Song(
            id: 'itunes_${e['id']?['attributes']?['im:id'] ?? e['title']?['label']}',
            title: e['im:name']?['label'] ?? 'Top Song',
            artist: e['im:artist']?['label'] ?? 'Top Artist',
            album: e['im:collection']?['im:name']?['label'] ?? '',
            artworkUrl: (e['im:image'] as List?)?.last?['label']?.replaceAll('170x170', '600x600'),
            streamUrl: null,
            duration: const Duration(seconds: 210),
            genre: e['category']?['attributes']?['label'] ?? 'Top Chart',
            featureVector: _deriveFeatureVector(e['im:name']?['label'] ?? ''),
          )).toList();
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
    final Map<String, String> vibeSearches = {
      'noir_night': 'The Weeknd Dark Synthwave',
      'deep_focus': 'Lofi Chill Beats Study',
      'high_energy': 'Electronic Workout Cyberpunk',
      'ambient_chill': 'Ambient Chillout Atmospheric',
      'retro_synth': 'Outrun Synthwave Retrowave 80s',
      'late_night': 'Night Drive Phonk Synthwave',
    };
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
      try {
        baseDir = await getExternalStorageDirectory();
      } catch (_) {}
      baseDir ??= await getApplicationDocumentsDirectory();

      final dir = Directory('${baseDir.path}/Noctra_Music');
      if (!await dir.exists()) await dir.create(recursive: true);

      final streamUrl = await resolveStreamUrl(song);
      if (streamUrl == null || streamUrl.isEmpty) return null;

      final safeName = '${song.artist} - ${song.title}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${dir.path}/$safeName.mp3';
      final file = File(filePath);

      final res = await http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
        final downloadedSong = song.copyWith(localFilePath: filePath, isDownloaded: true);
        MusicRepository().addDownloadedSong(downloadedSong);
        return downloadedSong;
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
