import 'dart:convert';
import 'package:http/http.dart' as http;

/// Enhanced MusicBrainz service with ISRC lookup, artist credits,
/// and release group metadata. All zero-key, rate-limited.
class MusicBrainzService {
  static const String _userAgent = 'NoctraMusicApp/1.1.0 ( contact@noctra.local )';
  static const int _maxCacheSize = 300;
  static final Map<String, Map<String, dynamic>> _cache = {};
  static DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _rateLimit = Duration(milliseconds: 1100); // ~1 req/sec
  static Future<void> _throttleChain = Future.value();

  /// Rate-limit all MusicBrainz requests sequentially.
  static Future<void> _throttle() {
    _throttleChain = _throttleChain.then((_) async {
      final elapsed = DateTime.now().difference(_lastRequest);
      if (elapsed < _rateLimit) {
        await Future.delayed(_rateLimit - elapsed);
      }
      _lastRequest = DateTime.now();
    });
    return _throttleChain;
  }

  /// Search MusicBrainz for recording metadata (title, artist, ISRC, tags).
  static Future<Map<String, dynamic>?> searchRecording(
      String title, String artist) async {
    final cacheKey = 'recording::${title.toLowerCase()}::${artist.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      return cached.isEmpty ? null : Map<String, dynamic>.from(cached);
    }

    try {
      await _throttle();
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

          // Extract ISRCs
          final isrcs = <String>[];
          final isrcList = rec['isrcs'] as List?;
          if (isrcList != null) {
            for (final isrc in isrcList) {
              if (isrc is String) isrcs.add(isrc);
            }
          }

          // Extract artist credits
          final artistCredits = <Map<String, String>>[];
          final credits = rec['artist-credit'] as List?;
          if (credits != null) {
            for (final credit in credits) {
              if (credit is Map) {
                final name = credit['name']?.toString() ?? '';
                final joinPhrase = credit['joinphrase']?.toString() ?? '';
                if (name.isNotEmpty) {
                  artistCredits.add({'name': name, 'joinphrase': joinPhrase});
                }
              }
            }
          }

          // Extract tags
          final tags = (rec['tags'] as List?)
                  ?.map((t) => t['name'] as String)
                  .toList() ??
              [];

          // Extract relations (e.g., "first release date", "live recording")
          final relations = <String>[];
          final rels = rec['relations'] as List?;
          if (rels != null) {
            for (final rel in rels) {
              if (rel is Map) {
                final type = rel['type']?.toString();
                if (type != null) relations.add(type);
              }
            }
          }

          final result = {
            'mbid': rec['id'],
            'title': rec['title'],
            'artist': artist,
            'album': albumTitle,
            'releaseMbid': releaseMbid,
            'releaseDate': releaseDate,
            'duration': rec['length'] as num?, // milliseconds
            'isrcs': List<String>.unmodifiable(isrcs),
            'artistCredits': List<Map<String, String>>.unmodifiable(artistCredits),
            'tags': List<String>.unmodifiable(tags),
            'relations': List<String>.unmodifiable(relations),
          };

          if (_cache.length >= _maxCacheSize) {
            _cache.remove(_cache.keys.first);
          }
          _cache[cacheKey] = Map<String, dynamic>.unmodifiable(result);
          return Map<String, dynamic>.from(result);
        }
      }
    } catch (_) {}

    // Cache miss
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = const {};
    return null;
  }

  /// Lookup a recording by ISRC code.
  static Future<Map<String, dynamic>?> lookupByISRC(String isrc) async {
    final cacheKey = 'isrc::${isrc.toUpperCase()}';
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      return cached.isEmpty ? null : Map<String, dynamic>.from(cached);
    }

    try {
      await _throttle();
      final uri = Uri.parse(
        'https://musicbrainz.org/ws/2/isrc/${isrc.toUpperCase()}?fmt=json',
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

          if (releases != null && releases.isNotEmpty) {
            releaseMbid = releases.first['id'];
            albumTitle = releases.first['title'];
          }

          final result = {
            'mbid': rec['id'],
            'title': rec['title'],
            'isrc': isrc.toUpperCase(),
            'album': albumTitle,
            'releaseMbid': releaseMbid,
            'duration': rec['length'] as num?,
          };

          if (_cache.length >= _maxCacheSize) {
            _cache.remove(_cache.keys.first);
          }
          _cache[cacheKey] = Map<String, dynamic>.unmodifiable(result);
          return Map<String, dynamic>.from(result);
        }
      }
    } catch (_) {}

    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = const {};
    return null;
  }

  /// Fetch front album cover art URL from Cover Art Archive.
  static Future<String?> fetchCoverArt(String releaseMbid) async {
    try {
      await _throttle();
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

  /// Search for similar recordings by the same artist.
  static Future<List<Map<String, dynamic>>> findSimilarRecordings(
      String artist, {int limit = 10}) async {
    try {
      await _throttle();
      final query = 'artist:"$artist" AND NOT unknown:true';
      final uri = Uri.parse(
        'https://musicbrainz.org/ws/2/recording/?query=${Uri.encodeComponent(query)}&fmt=json&limit=$limit',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final recordings = data['recordings'] as List?;
        if (recordings != null) {
          return recordings.map((rec) {
            final releases = rec['releases'] as List?;
            return {
              'mbid': rec['id'],
              'title': rec['title'],
              'artist': artist,
              'album': releases?.isNotEmpty == true
                  ? releases!.first['title']
                  : null,
              'duration': rec['length'] as num?,
            };
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
