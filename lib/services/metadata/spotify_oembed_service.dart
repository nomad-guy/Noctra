import 'dart:convert';
import 'package:http/http.dart' as http;

class SpotifyOEmbedData {
  final String title;
  final String authorName;
  final String? thumbnailUrl;
  final String type;
  final String rawUrl;

  const SpotifyOEmbedData({
    required this.title,
    required this.authorName,
    this.thumbnailUrl,
    required this.type,
    required this.rawUrl,
  });

  factory SpotifyOEmbedData.fromJson(Map<String, dynamic> json, String url) {
    final title = json['title'] as String? ?? 'Spotify Track';
    final author = json['author_name'] as String? ?? 'Unknown Artist';
    final thumbnail = json['thumbnail_url'] as String?;
    final type = json['type'] as String? ?? 'rich';

    return SpotifyOEmbedData(
      title: title,
      authorName: author,
      thumbnailUrl: thumbnail,
      type: type,
      rawUrl: url,
    );
  }
}

class SpotifyOEmbedService {
  static const String _oembedEndpoint = 'https://open.spotify.com/oembed';

  /// Checks if a given query string is a Spotify URL
  static bool isSpotifyUrl(String input) {
    final trimmed = input.trim().toLowerCase();
    return trimmed.contains('open.spotify.com/') || trimmed.contains('spotify.link/');
  }

  /// Fetches track, album, or playlist metadata via Spotify zero-key oEmbed endpoint
  static Future<SpotifyOEmbedData?> fetchMetadata(String spotifyUrl) async {
    try {
      final cleanUrl = spotifyUrl.trim();
      final uri = Uri.parse('$_oembedEndpoint?url=${Uri.encodeComponent(cleanUrl)}');

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return SpotifyOEmbedData.fromJson(data, cleanUrl);
        }
      }
    } catch (_) {}
    return null;
  }
}
