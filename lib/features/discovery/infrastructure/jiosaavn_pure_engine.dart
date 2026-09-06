import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/crypto/des_cipher.dart';

/// Pure-Dart cross-platform JioSaavn resolution engine.
/// Runs natively on Android, Windows, Linux, macOS, iOS, and Web with zero native bridging.
class JioSaavnPureEngine {
  static const String _desKey = '38346591';

  /// Decrypts a JioSaavn encrypted media url into a direct 320kbps CDN stream url.
  static String? decryptMediaUrl(String? encryptedMediaUrl) {
    if (encryptedMediaUrl == null || encryptedMediaUrl.trim().isEmpty) {
      return null;
    }
    try {
      var rawUrl = DesCipher.decryptBase64String(encryptedMediaUrl, _desKey);
      if (rawUrl == null || rawUrl.isEmpty) return null;
      rawUrl = rawUrl.trim();

      if (rawUrl.startsWith('http://') &&
          !rawUrl.contains('127.0.0.1') &&
          !rawUrl.contains('localhost')) {
        rawUrl = 'https://${rawUrl.substring(7)}';
      }

      return rawUrl
          .replaceAll('_96.mp4', '_320.mp4')
          .replaceAll('_96.m4a', '_320.m4a')
          .replaceAll('_160.mp4', '_320.mp4')
          .replaceAll('_160.m4a', '_320.m4a');
    } catch (e) {
      debugPrint('[JioSaavnPureEngine] decryptMediaUrl failed: $e');
      return null;
    }
  }

  /// Sanitizes text by stripping common tags, noise, and non-alphanumeric punctuation.
  static String sanitizeText(String input) {
    var s = input
        .replaceAll(RegExp(r'\s*-\s*topic', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[]official.*?[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[]audio[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[]lyrics[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[]video[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[]slowed.*?[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\[]speed.*?[\)\]]', caseSensitive: false), '');

    // Keep letters, numbers, whitespace
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Searches songs on JioSaavn public endpoints.
  static Future<List<Map<String, dynamic>>> searchSongs(
    String query, {
    int limit = 20,
    http.Client? client,
  }) async {
    final results = <Map<String, dynamic>>[];
    final cleanQ = sanitizeText(query);
    final queriesToTry = (cleanQ.isNotEmpty && cleanQ != query)
        ? [cleanQ, query]
        : [query];

    final httpClient = client ?? http.Client();
    final closeClient = client == null;

    try {
      for (final q in queriesToTry) {
        try {
          final uri = Uri.parse(
            'https://www.jiosaavn.com/api.php?__call=search.getResults'
            '&q=${Uri.encodeComponent(q)}&_format=json&_marker=0&api_version=4&ctx=android&n=$limit',
          );
          final res = await httpClient.get(uri, headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          }).timeout(const Duration(seconds: 5));

          if (res.statusCode != 200) continue;
          final dynamic data = jsonDecode(res.body);
          if (data is! Map) continue;
          final items = data['results'] as List<dynamic>?;
          if (items == null) continue;

          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final parsed = parseSongItem(item);
              if (parsed != null && !results.any((r) => r['id'] == parsed['id'])) {
                results.add(parsed);
              }
            }
          }
          if (results.isNotEmpty) break;
        } catch (_) {}
      }
    } finally {
      if (closeClient) httpClient.close();
    }
    return results;
  }

  /// Parses a raw JSON item from JioSaavn API response into standard map format.
  static Map<String, dynamic>? parseSongItem(Map<String, dynamic> item) {
    final rawTitle = (item['title'] ?? item['song'] ?? '').toString();
    if (rawTitle.isEmpty) return null;

    final cleanTitle = rawTitle
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&');

    final moreInfo = item['more_info'] as Map<String, dynamic>?;
    final encryptedUrl = (moreInfo?['encrypted_media_url'] ?? '').toString();
    final streamUrl = decryptMediaUrl(encryptedUrl);

    final rawArtist = (item['subtitle'] ?? '').toString();
    String cleanArtist;
    if (rawArtist.isNotEmpty) {
      cleanArtist = rawArtist
          .replaceAll('&quot;', '"')
          .replaceAll('&#039;', "'")
          .replaceAll('&amp;', '&');
    } else {
      final artistMap = moreInfo?['artistMap'] as Map<String, dynamic>?;
      final primary = artistMap?['primary_artists'] as List<dynamic>?;
      if (primary != null && primary.isNotEmpty && primary.first is Map) {
        cleanArtist = (primary.first['name'] ?? 'Popular Artist').toString();
      } else {
        cleanArtist = 'Popular Artist';
      }
    }

    final rawImg = (item['image'] ?? '').toString();
    var highResImg = rawImg
        .replaceAll('150x150', '500x500')
        .replaceAll('50x50', '500x500');
    if (highResImg.startsWith('http://')) {
      highResImg = 'https://${highResImg.substring(7)}';
    }

    final durationSec = int.tryParse(moreInfo?['duration']?.toString() ?? '180') ?? 180;

    return {
      'id': 'saavn_${item['id'] ?? cleanTitle.hashCode.toString()}',
      'title': cleanTitle,
      'artist': cleanArtist,
      'album': moreInfo?['album']?.toString() ?? 'CD Master Edition',
      'thumbnail': highResImg,
      'stream_url': streamUrl ?? '',
      'duration': durationSec,
      'source': 'JioSaavn 320kbps CD Lossless',
    };
  }

  /// Compares candidate track metadata against target metadata.
  static bool isMatch(
    String targetTitle,
    String targetArtist,
    String candidateTitle,
    String candidateArtist,
  ) {
    final tLower = targetTitle.toLowerCase();
    final cLower = candidateTitle.toLowerCase();

    const modifierTags = [
      'remix', 'live', 'acoustic', 'instrumental', 'karaoke', 'slowed', 'sped up', 'cover',
    ];
    final targetMods = modifierTags.where((m) => tLower.contains(m)).toList();
    final candMods = modifierTags.where((m) => cLower.contains(m)).toList();

    if (targetMods.isNotEmpty) {
      if (!candMods.any((m) => targetMods.contains(m))) return false;
    } else {
      if (candMods.isNotEmpty) return false;
    }

    final primaryTarget = sanitizeText(targetArtist.split(RegExp(r'[,&/]')).first).toLowerCase().trim();
    final candCombined = '${sanitizeText(candidateArtist).toLowerCase()} $cLower';
    if (primaryTarget.isNotEmpty && !candCombined.contains(primaryTarget)) {
      final aTokens = primaryTarget.split(' ').where((t) => t.length > 2).toList();
      if (aTokens.isNotEmpty && !aTokens.any((t) => candCombined.contains(t))) {
        return false;
      }
    }

    var tTokens = sanitizeText(targetTitle).toLowerCase().split(' ').where((t) => t.length > 1).toList();
    if (tTokens.isEmpty) {
      tTokens = sanitizeText(targetTitle).toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
    }
    var cTokens = sanitizeText(candidateTitle).toLowerCase().split(' ').where((t) => t.length > 1).toList();
    if (cTokens.isEmpty) {
      cTokens = sanitizeText(candidateTitle).toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
    }
    if (tTokens.isEmpty || cTokens.isEmpty) return false;
    if (tTokens.join(' ') == cTokens.join(' ')) return true;

    final matchCount = tTokens.where((tok) => cTokens.any((c) => c == tok || c.contains(tok))).length;
    return (matchCount / tTokens.length) >= 0.75;
  }

  /// Resolves the 320kbps track stream URL for [title] and [artist].
  static Future<String?> resolveTrackStream(
    String title,
    String artist, {
    Duration? timeBudget,
    http.Client? client,
  }) async {
    final cleanT = sanitizeText(title);
    final cleanA = sanitizeText(artist.split(RegExp(r'[,&/]')).first);

    final permutations = <String>{};
    if (cleanT.isNotEmpty && cleanA.isNotEmpty) permutations.add('$cleanT $cleanA');
    if (cleanT.isNotEmpty) permutations.add(cleanT);
    if (title.isNotEmpty && artist.isNotEmpty) permutations.add('$title $artist');
    if (title.isNotEmpty) permutations.add(title);

    for (final p in permutations) {
      final songs = await searchSongs(p, limit: 6, client: client);
      for (final s in songs) {
        final sTitle = s['title'] as String? ?? '';
        final sArtist = s['artist'] as String? ?? '';
        final sUrl = s['stream_url'] as String?;
        if (sUrl != null && sUrl.isNotEmpty && isMatch(title, artist, sTitle, sArtist)) {
          return sUrl;
        }
      }
    }
    return null;
  }
}
