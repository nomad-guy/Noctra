import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/noctra_logger.dart';

class ArtistMetadata {
  final String name;
  final String? imageUrl;
  final String? bio;
  final String? shortDescription;

  const ArtistMetadata({
    required this.name,
    this.imageUrl,
    this.bio,
    this.shortDescription,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'imageUrl': imageUrl,
    'bio': bio,
    'shortDescription': shortDescription,
  };
}

class ArtistMetadataService {
  static final Map<String, ArtistMetadata> _cache = {};

  static Future<ArtistMetadata> fetchArtistInfo(String artistName) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      return const ArtistMetadata(name: 'Artist');
    }

    final cacheKey = cleanName.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

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

        final metadata = ArtistMetadata(
          name: data['title'] ?? cleanName,
          imageUrl: thumb,
          bio: extract,
          shortDescription: desc,
        );

        _cache[cacheKey] = metadata;
        return metadata;
      }
    } catch (e) {
      NoctraLogger.w('Wikipedia artist info fetch failed for $cleanName', e);
    }

    // Fallback stub
    final fallback = ArtistMetadata(name: cleanName);
    _cache[cacheKey] = fallback;
    return fallback;
  }
}
