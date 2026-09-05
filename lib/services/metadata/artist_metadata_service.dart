import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/bounded_concurrency.dart';
import '../../core/utils/noctra_logger.dart';

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

      // 1. Tier 1: Deezer Official Music Graph (Zero false disambiguations, 500x500 HD photos)
      try {
        final uri = Uri.parse(
            'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(cleanName)}&limit=1');
        final res = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['data'] as List?;
          if (list != null && list.isNotEmpty) {
            final a = list.first as Map<String, dynamic>;
            final pic =
                a['picture_big'] ?? a['picture_medium'] ?? a['picture_xl'];
            if (pic != null &&
                pic.toString().isNotEmpty &&
                !pic.toString().contains('artist-default')) {
              resolvedImageUrl = pic.toString();
            }
          }
        }
      } catch (e) {
        NoctraLogger.d('Deezer artist photo lookup fallback: $e');
      }

      // 2. Tier 2: JioSaavn Autocomplete Music Directory (For Desi, Punjabi, Bollywood artists)
      if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
        try {
          final saavnUri = Uri.parse(
              'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&cc=in&includeMetaTags=1&query=${Uri.encodeComponent(cleanName)}');
          final res = await http.get(saavnUri, headers: {
            'User-Agent': 'Mozilla/5.0'
          }).timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final artists = data['artists']?['data'] as List?;
            if (artists != null && artists.isNotEmpty) {
              for (final item in artists) {
                final rawImg = item['image']?.toString() ?? '';
                if (rawImg.isNotEmpty && !rawImg.contains('artist-default')) {
                  resolvedImageUrl = rawImg
                      .replaceAll('50x50', '500x500')
                      .replaceAll('150x150', '500x500');
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      // 3. Tier 3: Apple Music / iTunes Store
      if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
        try {
          final itunesUri = Uri.parse(
              'https://itunes.apple.com/search?term=${Uri.encodeComponent(cleanName)}&entity=song&limit=1');
          final res = await http.get(itunesUri, headers: {
            'User-Agent': 'Mozilla/5.0'
          }).timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final results = data['results'] as List?;
            if (results != null && results.isNotEmpty) {
              final raw = results.first['artworkUrl100']?.toString() ?? '';
              if (raw.isNotEmpty) {
                resolvedImageUrl = raw.replaceAll('100x100bb', '600x600bb');
              }
            }
          }
        } catch (_) {}
      }

      // 4. Tier 4: Wikipedia Biography & Musician summary
      try {
        final wikiUri = Uri.parse(
            'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanName)}');
        final res = await http.get(wikiUri, headers: {
          'User-Agent': 'NoctraMusicApp/1.0 (contact@noctra.app)'
        }).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final String? desc = data['description']?.toString().toLowerCase();
          final bool isMusicEntity = desc != null &&
              (desc.contains('singer') ||
                  desc.contains('musician') ||
                  desc.contains('band') ||
                  desc.contains('rapper') ||
                  desc.contains('composer') ||
                  desc.contains('artist') ||
                  desc.contains('producer') ||
                  desc.contains('record'));

          if (isMusicEntity || desc == null) {
            bio = data['extract'];
            shortDesc = data['description'] ?? 'Official Music Profile';
            if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
              final thumb = data['thumbnail']?['source'] ??
                  data['originalimage']?['source'];
              if (thumb != null && thumb.toString().isNotEmpty) {
                resolvedImageUrl = thumb.toString();
              }
            }
          }
        }
      } catch (_) {}

      // Fallback bio query if direct summary missed
      if (bio == null) {
        try {
          final queryUrl = Uri.parse(
              'https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent("$cleanName musician")}&gsrlimit=1&prop=extracts&exintro=1&explaintext=1&format=json&origin=*');
          final res = await http.get(queryUrl, headers: {
            'User-Agent': 'NoctraMusicApp/1.0 (contact@noctra.app)'
          }).timeout(const Duration(milliseconds: 2500));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final pages = data['query']?['pages'] as Map<String, dynamic>?;
            if (pages != null && pages.isNotEmpty) {
              final page = pages.values.first as Map<String, dynamic>;
              bio = page['extract'];
              shortDesc = 'Artist Profile';
            }
          }
        } catch (_) {}
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
