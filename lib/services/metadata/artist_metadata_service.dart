import 'dart:convert';
import 'package:http/http.dart' as http;
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
  static const int _cacheTtlMs = 7 * 24 * 60 * 60 * 1000;

  static Future<ArtistMetadata> fetchArtistInfo(String artistName) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) return ArtistMetadata(name: 'Artist', cachedTimestamp: DateTime.now().millisecondsSinceEpoch);

    final cacheKey = cleanName.toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cache.containsKey(cacheKey) && (now - _cache[cacheKey]!.cachedTimestamp < _cacheTtlMs)) {
      return _cache[cacheKey]!;
    }

    try {
      final uri = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanName)}');
      final res = await http.get(uri, headers: {'User-Agent': 'NoctraMusicApp/1.0 (contact@noctra.app)'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final String? thumb = data['thumbnail']?['source'] ?? data['originalimage']?['source'];
        if (thumb != null && thumb.isNotEmpty) {
          final metadata = ArtistMetadata(name: data['title'] ?? cleanName, imageUrl: thumb, bio: data['extract'], shortDescription: data['description'], cachedTimestamp: now);
          _cache[cacheKey] = metadata; return metadata;
        }
      }
    } catch (_) {}

    try {
      final queryUrl = Uri.parse('https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent("$cleanName musician")}&gsrlimit=1&prop=pageimages|extracts&piprop=thumbnail&pithumbsize=500&exintro=1&explaintext=1&format=json&origin=*');
      final res = await http.get(queryUrl, headers: {'User-Agent': 'NoctraMusicApp/1.0 (contact@noctra.app)'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final page = pages.values.first as Map<String, dynamic>;
          final metadata = ArtistMetadata(name: page['title'] ?? cleanName, imageUrl: page['thumbnail']?['source'], bio: page['extract'], shortDescription: 'Artist Profile', cachedTimestamp: now);
          _cache[cacheKey] = metadata; return metadata;
        }
      }
    } catch (_) {}

    final fallback = ArtistMetadata(name: cleanName, cachedTimestamp: now);
    _cache[cacheKey] = fallback;
    return fallback;
  }

  /// Dynamically discovers soft-coded related & collaborating artists via real-time music graphs
  static Future<List<String>> fetchDynamicSimilarArtists(String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return [];
    final key = clean.toLowerCase();
    if (_similarCache.containsKey(key)) return _similarCache[key]!;

    final discovered = <String>{};

    try {
      final url = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(clean)}&entity=song&limit=25');
      final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];
        final splitRegex = RegExp(r'[,&/]| feat\.? | ft\.? | with ', caseSensitive: false);

        for (final item in results) {
          final raw = item['artistName'] as String? ?? '';
          final parts = raw.split(splitRegex);
          for (final p in parts) {
            final name = p.trim();
            if (name.isNotEmpty && name.toLowerCase() != key && name.length > 2 && !name.toLowerCase().contains('karaoke') && !name.toLowerCase().contains('tribute')) {
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
    _similarCache[key] = list;
    return list;
  }

  static const Map<String, List<String>> _seedMap = {
    'Arijit Singh': ['Atif Aslam', 'Mohit Chauhan', 'Jubin Nautiyal', 'KK'],
    'The Weeknd': ['Post Malone', 'Bruno Mars', 'Lana Del Rey', 'Daft Punk'],
    'Sidhu Moose Wala': ['Amrit Maan', 'Shubh', 'Amrinder Gill', 'B Praak'],
    'Diljit Dosanjh': ['Gippy Grewal', 'Guru Randhawa', 'Jassie Gill'],
    'Taylor Swift': ['Olivia Rodrigo', 'Ariana Grande', 'Selena Gomez', 'Ed Sheeran'],
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
