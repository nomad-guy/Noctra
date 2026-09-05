import 'dart:async';
import '../../../core/utils/noctra_logger.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../resolvers/track_matching_guard.dart';
import '../../ytdlp/music_service.dart';

/// Assistant search and resolution pipeline that honors TrackMatchingGuard,
/// local library prioritization, and network timeouts.
class AssistantSearchPipeline {
  final MusicRepository _musicRepo;
  static const Duration _defaultSearchTimeout = Duration(seconds: 8);

  AssistantSearchPipeline({MusicRepository? musicRepo})
      : _musicRepo = musicRepo ?? MusicRepository.instance;

  /// Resolve a voice search query and optional Android extras into a playable Song.
  Future<Song?> resolveSearch(
    String rawQuery, {
    Map<String, dynamic>? extras,
    Duration timeout = _defaultSearchTimeout,
  }) async {
    final cleanQuery = rawQuery.trim();
    final focus = extras?['android.intent.extra.focus']?.toString() ?? '';
    final title = (extras?['android.intent.extra.title']?.toString() ??
            extras?['title']?.toString() ??
            '')
        .trim();
    final artist = (extras?['android.intent.extra.artist']?.toString() ??
            extras?['artist']?.toString() ??
            '')
        .trim();
    final album = (extras?['android.intent.extra.album']?.toString() ??
            extras?['album']?.toString() ??
            '')
        .trim();

    final effectiveQuery = cleanQuery.isNotEmpty
        ? cleanQuery
        : (title.isNotEmpty
            ? (artist.isNotEmpty ? '$title $artist' : title)
            : (artist.isNotEmpty
                ? artist
                : (album.isNotEmpty ? album : '')));

    if (effectiveQuery.isEmpty) {
      NoctraLogger.w('AssistantSearchPipeline: empty search query and extras');
      return null;
    }

    // 1. Check local library / downloads / favorites first (fast, offline-safe)
    final localMatch = _findInLocalCollections(
      query: effectiveQuery,
      title: title,
      artist: artist,
      focus: focus,
    );
    if (localMatch != null) {
      NoctraLogger.d('AssistantSearchPipeline: matched local track ${localMatch.id}');
      return localMatch;
    }

    // 2. Perform online cascade with timeout
    try {
      final results = await MusicService.searchTracks(effectiveQuery)
          .timeout(timeout, onTimeout: () {
        NoctraLogger.w('AssistantSearchPipeline: network search timed out for "$effectiveQuery"');
        return <Song>[];
      });

      if (results.isEmpty) return null;

      // 3. Apply TrackMatchingGuard if title/artist were explicitly requested
      if (title.isNotEmpty) {
        for (final candidate in results) {
          if (TrackMatchingGuard.isSafeMatch(
            targetTitle: title,
            targetArtist: artist,
            candidateTitle: candidate.title,
            candidateArtist: candidate.artist,
          )) {
            return candidate;
          }
        }
      }

      // Default to top ranked result
      return results.first;
    } catch (e, stack) {
      NoctraLogger.e('AssistantSearchPipeline: search error', e, stack);
      return null;
    }
  }

  Song? _findInLocalCollections({
    required String query,
    required String title,
    required String artist,
    required String focus,
  }) {
    final pool = <Song>[
      ..._musicRepo.downloads,
      ..._musicRepo.favorites,
      ..._musicRepo.recentlyPlayed,
    ];

    final qLower = query.toLowerCase();
    final tLower = title.toLowerCase();
    final aLower = artist.toLowerCase();

    // Exact title + artist match
    if (tLower.isNotEmpty && aLower.isNotEmpty) {
      for (final s in pool) {
        if (s.title.toLowerCase() == tLower &&
            s.artist.toLowerCase().contains(aLower)) {
          return s;
        }
      }
    }

    // Exact title match
    if (tLower.isNotEmpty) {
      for (final s in pool) {
        if (s.title.toLowerCase() == tLower) return s;
      }
    }

    // Fuzzy query match against title or artist
    for (final s in pool) {
      final sTitle = s.title.toLowerCase();
      final sArtist = s.artist.toLowerCase();
      if (sTitle.contains(qLower) || qLower.contains(sTitle)) {
        return s;
      }
      if (sArtist.contains(qLower) || qLower.contains(sArtist)) {
        return s;
      }
    }

    return null;
  }
}
