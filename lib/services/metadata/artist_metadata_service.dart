import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/bounded_concurrency.dart';
import '../../core/utils/noctra_logger.dart';
import 'artist_wikipedia_service.dart';

class ArtistMetadata {
  final String name;
  final String? imageUrl;
  final String? bio;
  final String? shortDescription;
  final int cachedTimestamp;

  const ArtistMetadata({
    required this.name,
    this.imageUrl,
    this.bio,
    this.shortDescription,
    required this.cachedTimestamp,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'imageUrl': imageUrl,
        'bio': bio,
        'shortDescription': shortDescription,
        'cachedTimestamp': cachedTimestamp,
      };
}

class ArtistMetadataService {
  static final Map<String, ArtistMetadata> _cache = {};
  static final Map<String, List<String>> _similarCache = {};
  static final Map<String, Future<ArtistMetadata>> _inFlight = {};
  static const int _cacheTtlMs = 7 * 24 * 60 * 60 * 1000;
  static const int _maxCacheEntries = 350;

  /// Bounded concurrency: artist lookups fan out across
  /// Deezer/JioSaavn/iTunes/Wikipedia and several cards mount at once;
  /// queued cards share the same in-flight future.
  static final BoundedConcurrency _lookupLimiter = BoundedConcurrency(3);

  /// Evict expired entries from the metadata cache.
  static void _evictExpired({int? now}) {
    final ts = now ?? DateTime.now().millisecondsSinceEpoch;
    _cache.removeWhere((_, v) => (ts - v.cachedTimestamp) >= _cacheTtlMs);
  }

  static Future<ArtistMetadata> fetchArtistInfo(String artistName) {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      return Future.value(ArtistMetadata(
          name: 'Artist',
          cachedTimestamp: DateTime.now().millisecondsSinceEpoch));
    }

    final cacheKey = cleanName.toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    _evictExpired(now: now);
    if (_cache.containsKey(cacheKey)) {
      return Future.value(_cache[cacheKey]!);
    }
    return _inFlight.putIfAbsent(
        cacheKey, () => _lookupLimiter.run(() => _fetchArtistInfoUncached(cleanName, cacheKey)));
  }

  static Future<ArtistMetadata> _fetchArtistInfoUncached(
      String cleanName, String cacheKey) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_cache.length >= _maxCacheEntries) _cache.remove(_cache.keys.first);

      String? resolvedImageUrl;
      String? bio;
      String? shortDesc = 'Artist Profile';

      final primaryArtist = cleanName
          .split(RegExp(r'[,&/;\\]|(?:\s+(?:feat\.|ft\.|featuring|with|x)\s+)', caseSensitive: false))
          .first
          .trim();
      final effectiveName = primaryArtist.isNotEmpty ? primaryArtist : cleanName;

      // Parallel retrieval across Deezer, JioSaavn, and iTunes for ultra-fast load
      final photoResults = await Future.wait([
        () async {
          try {
            final uri = Uri.parse(
                'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(effectiveName)}&limit=1');
            final res = await http.get(uri, headers: {
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(milliseconds: 2000));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body) as Map<String, dynamic>;
              final list = data['data'] as List?;
              if (list != null && list.isNotEmpty) {
                final a = list.first as Map<String, dynamic>;
                final pic = a['picture_big'] ?? a['picture_medium'] ?? a['picture_xl'];
                if (pic != null &&
                    pic.toString().isNotEmpty &&
                    !pic.toString().contains('artist-default')) {
                  return pic.toString();
                }
              }
            }
          } catch (_) {}
          return null;
        }(),
        () async {
          try {
            final saavnUri = Uri.parse(
                'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${Uri.encodeComponent(effectiveName)}');
            final res = await http.get(saavnUri, headers: {
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(milliseconds: 2000));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body) as Map<String, dynamic>;
              final artists = data['artists']?['data'] as List?;
              if (artists != null && artists.isNotEmpty) {
                for (final item in artists) {
                  final rawImg = item['image']?.toString() ?? '';
                  if (rawImg.isNotEmpty && !rawImg.contains('artist-default')) {
                    return rawImg
                        .replaceAll('50x50', '500x500')
                        .replaceAll('150x150', '500x500');
                  }
                }
              }
            }
          } catch (_) {}
          return null;
        }(),
        () async {
          try {
            final itunesUri = Uri.parse(
                'https://itunes.apple.com/search?term=${Uri.encodeComponent(effectiveName)}&entity=song&limit=1');
            final res = await http.get(itunesUri, headers: {
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(milliseconds: 2000));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body) as Map<String, dynamic>;
              final results = data['results'] as List?;
              if (results != null && results.isNotEmpty) {
                final raw = results.first['artworkUrl100']?.toString() ?? '';
                if (raw.isNotEmpty) {
                  return raw.replaceAll('100x100bb', '600x600bb');
                }
              }
            }
          } catch (_) {}
          return null;
        }(),
      ]);

      resolvedImageUrl = photoResults[0] ?? photoResults[1] ?? photoResults[2];

      final wikiResult =
          await ArtistWikipediaService.fetchBioAndImage(effectiveName);
      if (wikiResult != null) {
        if (wikiResult.bio != null) bio = wikiResult.bio;
        if (wikiResult.shortDescription != null) {
          shortDesc = wikiResult.shortDescription;
        }
        if ((resolvedImageUrl == null || resolvedImageUrl.isEmpty) &&
            wikiResult.imageUrl != null) {
          resolvedImageUrl = wikiResult.imageUrl;
        }
      }

      final metadata = ArtistMetadata(
        name: cleanName,
        imageUrl: resolvedImageUrl,
        bio: bio,
        shortDescription: shortDesc,
        cachedTimestamp: now,
      );

      _cache[cacheKey] = metadata;
      return metadata;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// Dynamically discovers soft-coded related & collaborating artists via real-time music graphs
  static Future<List<String>> fetchDynamicSimilarArtists(
      String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return [];
    final key = clean.toLowerCase();
    if (_similarCache.containsKey(key)) return _similarCache[key]!;

    final discovered = <String>{};

    try {
      final url = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=song&limit=25');
      final res = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0'
      }).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];
        final splitRegex =
            RegExp(r'[,&/]| feat\.? | ft\.? | with ', caseSensitive: false);

        for (final item in results) {
          final raw = item['artistName'] as String? ?? '';
          final parts = raw.split(splitRegex);
          for (final p in parts) {
            final name = p.trim();
            if (name.isNotEmpty &&
                name.toLowerCase() != key &&
                name.length > 2 &&
                !name.toLowerCase().contains('karaoke') &&
                !name.toLowerCase().contains('tribute')) {
              discovered.add(name);
              if (discovered.length >= 6) break;
            }
          }
          if (discovered.length >= 6) break;
        }
      }
    } catch (e) {
      NoctraLogger.w('Dynamic similar artist resolution network fallback', e);
    }

    if (discovered.length < 4 && _seedMap.containsKey(clean)) {
      discovered.addAll(_seedMap[clean]!);
    }

    final list = discovered.take(6).toList();
    // Bound the similar-artist cache exactly like the main metadata cache:
    // an unbounded Map keyed by every artist the user browses would grow
    // without limit over a session.
    if (_similarCache.length >= _maxCacheEntries) {
      _similarCache.remove(_similarCache.keys.first);
    }
    _similarCache[key] = list;
    return list;
  }

  static const Map<String, List<String>> _seedMap = {
    'Arijit Singh': ['Atif Aslam', 'Mohit Chauhan', 'Jubin Nautiyal', 'KK'],
    'The Weeknd': ['Post Malone', 'Bruno Mars', 'Lana Del Rey', 'Daft Punk'],
    'Sidhu Moose Wala': ['Amrit Maan', 'Shubh', 'Amrinder Gill', 'B Praak'],
    'Diljit Dosanjh': ['Gippy Grewal', 'Guru Randhawa', 'Jassie Gill'],
    'Taylor Swift': [
      'Olivia Rodrigo',
      'Ariana Grande',
      'Selena Gomez',
      'Ed Sheeran'
    ],
    'Pritam': ['Vishal-Shekhar', 'Sachin-Jigar', 'Amit Trivedi'],
    'Karan Aujla': ['Ikky', 'Deep Jandu', 'Jay Trak'],
    'AP Dhillon': ['Gurinder Gill', 'Shinda Kahlon', 'Gminxr'],
    'Fly By Midnight': ['Prateek Kuhad', 'Anuv Jain', 'Lauv'],
    'Shreya Ghoshal': ['Sunidhi Chauhan', 'Neeti Mohan', 'Monali Thakur'],
    'Dua Lipa': ['Bebe Rexha', 'Rita Ora', 'Ava Max'],
    'Atif Aslam': ['Rahat Fateh Ali Khan', 'Ali Zafar', 'Mustafa Zahid'],
    'Drake': ['Travis Scott', 'Future', '21 Savage'],
    'Coldplay': ['Imagine Dragons', 'OneRepublic', 'The Chainsmokers'],
    'Billie Eilish': ['FINNEAS', 'Lorde', 'Girl in Red'],
    'Badshah': ['Raftaar', 'Yo Yo Honey Singh', 'DIVINE', 'Seedhe Maut'],
  };
}
