import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/catalog_topic.dart';
import '../../data/sources/noctra_local_database.dart';

class CatalogDiscoveryService {
  static const fallbackTopics = <CatalogTopic>[
    CatalogTopic(
        title: 'Global Charts',
        category: 'Offline catalog',
        query: 'Global top songs'),
    CatalogTopic(
        title: 'Fresh Pop',
        category: 'Offline catalog',
        query: 'Fresh pop music'),
    CatalogTopic(
        title: 'Hip-Hop Now',
        category: 'Offline catalog',
        query: 'Hip hop new releases'),
    CatalogTopic(
        title: 'Electronic Now',
        category: 'Offline catalog',
        query: 'Electronic music'),
    CatalogTopic(
        title: 'Chill & Focus',
        category: 'Offline catalog',
        query: 'Chill focus music'),
    CatalogTopic(
        title: 'Desi Essentials',
        category: 'Offline catalog',
        query: 'Desi Punjabi Hindi music'),
  ];
  static List<CatalogTopic>? _lastGood;
  static DateTime? _lastFetchedAt;

  static Future<List<CatalogTopic>> fetchTopics(
      {bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastGood != null &&
        _lastFetchedAt != null &&
        now.difference(_lastFetchedAt!) < const Duration(minutes: 20)) {
      return _lastGood!;
    }

    final cached = await NoctraLocalDatabase().loadCatalogTopics();
    if (!forceRefresh && cached.isNotEmpty) {
      _lastGood = cached;
    }

    final sources = await Future.wait([
      _fetchYouTubeMusicTopics(),
      _fetchAppleGenres(),
    ]);
    final topics = sources.expand((topics) => topics).toList();
    final deduped = <String, CatalogTopic>{};
    for (final topic in topics) {
      final title = topic.title.trim();
      if (title.length < 3 || title.length > 42) continue;
      deduped.putIfAbsent(title.toLowerCase(), () => topic);
      if (deduped.length >= 16) break;
    }
    if (deduped.isNotEmpty) {
      _lastGood = deduped.values.toList(growable: false);
      await NoctraLocalDatabase().saveCatalogTopics(_lastGood!);
    } else if (_lastGood == null || _lastGood!.isEmpty) {
      _lastGood = fallbackTopics;
    }
    _lastFetchedAt = now;
    return _lastGood!;
  }

  static Future<List<CatalogTopic>> _fetchYouTubeMusicTopics() async {
    try {
      final response = await http
          .post(
            Uri.parse('https://music.youtube.com/youtubei/v1/browse'),
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0'
            },
            body: jsonEncode({
              'browseId': 'FEmusic_moods_and_genres',
              'context': {
                'client': {
                  'clientName': 'WEB_REMIX',
                  'clientVersion': '1.20240820.01.00',
                  'hl': 'en',
                  'gl': 'US'
                }
              },
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body);
      final topics = <CatalogTopic>[];
      _walk(data, (renderer) {
        final button = renderer['musicNavigationButtonRenderer'];
        if (button is Map) {
          final title = _text(button['buttonRenderer']?['text']);
          if (title != null) {
            topics.add(CatalogTopic(
                title: title, category: 'YouTube Music', query: title));
          }
        }
      });
      return topics;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CatalogTopic>> _fetchAppleGenres() async {
    try {
      final response = await http
          .get(Uri.parse(
              'https://itunes.apple.com/us/rss/topsongs/limit=100/json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return const [];
      final entries =
          (jsonDecode(response.body)['feed']?['entry'] as List?) ?? const [];
      final genres = <String>{};
      for (final entry in entries) {
        final genre =
            entry['category']?['attributes']?['label']?.toString().trim();
        if (genre != null && genre.length > 2) genres.add(genre);
      }
      return genres
          .map((genre) => CatalogTopic(
              title: '$genre Picks',
              category: 'Apple Music Charts',
              query: '$genre top songs'))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String? _text(dynamic node) {
    final runs = node is Map ? node['runs'] as List? : null;
    final value = runs?.firstOrNull?['text']?.toString().trim();
    return value?.isNotEmpty == true ? value : null;
  }

  static void _walk(dynamic node, void Function(Map<String, dynamic>) onMap) {
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      onMap(map);
      for (final value in map.values) {
        _walk(value, onMap);
      }
    } else if (node is List) {
      for (final value in node) {
        _walk(value, onMap);
      }
    }
  }
}
