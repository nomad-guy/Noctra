import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/noctra_logger.dart';
import '../../data/models/download_location.dart';
import '../platform/download_location_resolver.dart';
import '../../data/models/song_model.dart';
import '../../data/repositories/taste_vector_engine.dart';
import '../../data/sources/noctra_local_database.dart';
import '../audio/stream_quality_service.dart';
import '../metadata/artist_metadata_service.dart';
import '../metadata/artist_metadata_normalizer.dart';
import '../metadata/spotify_oembed_service.dart';
import '../resolvers/stream_resolver.dart';
import 'search_result_ranker.dart';

part 'parts/music_service_search.dart';
part 'parts/music_service_yt_parser.dart';
part 'parts/music_service_charts.dart';
part 'parts/music_service_artist.dart';
part 'parts/music_service_downloader.dart';

class _SearchCacheEntry {
  final List<Song> results;
  final int expiresAt;
  _SearchCacheEntry(this.results, this.expiresAt);
}

class MusicService {
  static final downloadProgressController =
      StreamController<Map<String, double>>.broadcast();
  static Stream<Map<String, double>> get downloadProgressStream =>
      downloadProgressController.stream;

  static final Map<String, _SearchCacheEntry> _searchCache = {};
  static final Map<String, Future<List<Song>>> _searchInFlight = {};
  static final Map<String, Future<Song?>> _downloadInFlight = {};
  static const int _maxSearchCacheSize = 60;
  static const int _searchCacheTtlMs = 5 * 60 * 1000;

  static void clearSearchCache() {
    _searchCache.clear();
  }

  static Future<List<Song>> search(String query, {String source = 'all'}) =>
      searchTracks(query, source: source);

  static Future<List<Song>> searchTracks(String query,
      {String source = 'all'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return fetchTrendingTracks();

    final cacheKey = '$source:${clean.toLowerCase()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_searchCache.containsKey(cacheKey)) {
      final entry = _searchCache[cacheKey]!;
      if (now < entry.expiresAt) {
        _searchCache.remove(cacheKey);
        _searchCache[cacheKey] = entry;
        return entry.results;
      } else {
        _searchCache.remove(cacheKey);
      }
    }

    if (_searchInFlight.containsKey(cacheKey)) {
      return _searchInFlight[cacheKey]!;
    }

    final future =
        MusicServiceSearch._searchTracksUncached(clean, source: source);
    _searchInFlight[cacheKey] = future;
    try {
      final results = await future;
      if (results.isNotEmpty) {
        if (_searchCache.length >= _maxSearchCacheSize) {
          _searchCache.remove(_searchCache.keys.first);
        }
        _searchCache[cacheKey] =
            _SearchCacheEntry(results, now + _searchCacheTtlMs);
      }
      return results;
    } finally {
      _searchInFlight.remove(cacheKey);
    }
  }

  static List<double> _deriveFeatureVector(String title,
      {String artist = '', String album = '', String genre = ''}) {
    return TasteVectorEngine.extractTextEmbedding(
        '$title $artist $album $genre');
  }

  static String _selectedDownloadLocationKey() {
    try {
      return NoctraLocalDatabase().getCachedDownloadLocation();
    } catch (_) {
      return DownloadLocation.appDocs;
    }
  }

  static Future<List<Song>> fetchSimilarRadioQueue(Song currentSong,
          {Set<String> excludeIds = const {}}) =>
      MusicServiceCharts.fetchSimilarRadioQueue(currentSong,
          excludeIds: excludeIds);

  static Future<List<Song>> fetchTrendingFeed({
    List<String>? languages,
    List<String>? genres,
    int refreshNonce = 0,
  }) =>
      MusicServiceCharts.fetchTrendingFeed(
        languages: languages,
        genres: genres,
        refreshNonce: refreshNonce,
      );

  static Future<List<Song>> fetchSpotifyCharts({String? chartKey}) =>
      MusicServiceCharts.fetchSpotifyCharts(chartKey: chartKey);

  static Future<List<Song>> fetchTrendingTracks() =>
      MusicServiceCharts.fetchTrendingTracks();

  static Future<List<Song>> fetchVibeFeed(String vibeKey) =>
      MusicServiceCharts.fetchVibeFeed(vibeKey);

  static Future<ArtistDiscography> fetchArtistCatalog(String artistName) =>
      MusicServiceArtist.fetchArtistCatalog(artistName);

  static Future<Directory> getMusicDirectory() =>
      MusicServiceDownloader.getMusicDirectory();

  static Future<String?> resolveStreamUrl(Song song) =>
      MusicServiceDownloader.resolveStreamUrl(song);

  static Future<Song?> downloadTrack(Song song) =>
      MusicServiceDownloader.downloadTrack(song);

  static Future<double?> fetchSponsorBlockIntroSkip(String videoId) =>
      MusicServiceDownloader.fetchSponsorBlockIntroSkip(videoId);
}
