import 'dart:convert';
import 'package:http/http.dart' as http;

class MusicBrainzService {
  static const String _userAgent = 'NoctraMusicApp/1.0.0 ( contact@noctra.local )';
  static const int _maxCacheSize = 200;
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Searches MusicBrainz for recording metadata without any API key.
  static Future<Map<String, dynamic>?> searchRecording(String title, String artist) async {
    final cacheKey = '$title::$artist'.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      return cached.isEmpty ? null : Map<String, dynamic>.from(cached);
    }

    try {
      final query = 'recording:"$title" AND artist:"$artist"';
      final uri = Uri.parse(
        'https://musicbrainz.org/ws/2/recording/?query=${Uri.encodeComponent(query)}&fmt=json&limit=3',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final recordings = data['recordings'] as List?;
        if (recordings != null && recordings.isNotEmpty) {
          final rec = recordings.first;
          final releases = rec['releases'] as List?;
          String? releaseMbid;
          String? albumTitle;
          String? releaseDate;

          if (releases != null && releases.isNotEmpty) {
            final rel = releases.first;
            releaseMbid = rel['id'];
            albumTitle = rel['title'];
            releaseDate = rel['date'];
          }

          final tags = (rec['tags'] as List?)?.map((t) => t['name'] as String).toList() ?? [];

          final result = {
            'mbid': rec['id'],
            'title': rec['title'],
            'artist': artist,
            'album': albumTitle,
            'releaseMbid': releaseMbid,
            'releaseDate': releaseDate,
            'tags': List<String>.unmodifiable(tags),
          };

          if (_cache.length >= _maxCacheSize) {
            _cache.remove(_cache.keys.first);
          }
          _cache[cacheKey] = Map<String, dynamic>.unmodifiable(result);
          return Map<String, dynamic>.from(result);
        }
      }
    } catch (_) {}

    // Cache negative result (miss) to prevent hammering the API repeatedly
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = const {};
    return null;
  }

  /// Fetches front album cover art URL from Cover Art Archive by MBID without any API key.
  static Future<String?> fetchCoverArt(String releaseMbid) async {
    try {
      final uri = Uri.parse('https://coverartarchive.org/release/$releaseMbid');
      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final images = data['images'] as List?;
        if (images != null && images.isNotEmpty) {
          final front = images.firstWhere(
            (img) => img is Map && img['front'] == true,
            orElse: () => images.first,
          );
          if (front is Map) return front['image'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
