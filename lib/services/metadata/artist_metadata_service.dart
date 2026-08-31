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
  static const int _cacheTtlMs = 7 * 24 * 60 * 60 * 1000; // 7-day TTL

  static Future<ArtistMetadata> fetchArtistInfo(String artistName) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      return ArtistMetadata(name: 'Artist', cachedTimestamp: DateTime.now().millisecondsSinceEpoch);
    }

    final cacheKey = cleanName.toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (now - cached.cachedTimestamp < _cacheTtlMs) {
        return cached;
      }
    }

    // Step 1: Try direct REST page summary
    try {
      final uri = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanName)}');
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'NoctraMusicApp/1.0 (contact@noctra.app)'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final String? extract = data['extract'];
        final String? desc = data['description'];
        final String? thumb = data['thumbnail']?['source'] ?? data['originalimage']?['source'];

        if (thumb != null && thumb.isNotEmpty) {
          final metadata = ArtistMetadata(
            name: data['title'] ?? cleanName,
            imageUrl: thumb,
            bio: extract,
            shortDescription: desc,
            cachedTimestamp: now,
          );
          _cache[cacheKey] = metadata;
          return metadata;
        }
      }
    } catch (e) {
      NoctraLogger.w('Wikipedia direct summary failed for $cleanName', e);
    }

    // Step 2: Fallback to Wikipedia Search Query API with music disambiguation
    try {
      final queryUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent("$cleanName musician")}&gsrlimit=1&prop=pageimages|extracts&piprop=thumbnail&pithumbsize=500&exintro=1&explaintext=1&format=json&origin=*',
      );
      final res = await http.get(queryUrl, headers: {'User-Agent': 'NoctraMusicApp/1.0 (contact@noctra.app)'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final page = pages.values.first as Map<String, dynamic>;
          final String? extract = page['extract'];
          final String? thumb = page['thumbnail']?['source'];
          final String title = page['title'] ?? cleanName;

          final metadata = ArtistMetadata(
            name: title,
            imageUrl: thumb,
            bio: extract,
            shortDescription: 'Artist Profile',
            cachedTimestamp: now,
          );
          _cache[cacheKey] = metadata;
          return metadata;
        }
      }
    } catch (e) {
      NoctraLogger.w('Wikipedia search fallback failed for $cleanName', e);
    }

    // Step 3: Default fallback
    final fallback = ArtistMetadata(name: cleanName, cachedTimestamp: now);
    _cache[cacheKey] = fallback;
    return fallback;
  }
}
