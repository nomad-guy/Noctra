import 'song_model.dart';

/// Normalized representation of a track imported from any source.
class NormalizedTrack {
  final String title;
  final String artist;
  final String? album;
  final String? albumArtist;
  final Duration? duration;
  final String? releaseDate;
  final String? isrc;
  final bool explicit;
  final String source; // 'spotify', 'apple_music', 'youtube_music', etc.
  final String? sourceId;
  final String? playlist;
  final int? trackNumber;
  final Map<String, dynamic> originalMetadata;
  NormalizedTrack({
    required this.title,
    required this.artist,
    this.album,
    this.albumArtist,
    this.duration,
    this.releaseDate,
    this.isrc,
    this.explicit = false,
    required this.source,
    this.sourceId,
    this.playlist,
    this.trackNumber,
    this.originalMetadata = const {},
  });

  NormalizedTrack copyWith({String? title, String? artist, String? album, String? source}) {
    return NormalizedTrack(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist,
      duration: duration,
      releaseDate: releaseDate,
      isrc: isrc,
      explicit: explicit,
      source: source ?? this.source,
      sourceId: sourceId,
      playlist: playlist,
      trackNumber: trackNumber,
      originalMetadata: originalMetadata,
    );
  }
}

/// Match confidence levels for imported tracks.
enum MatchConfidence { exact, high, medium, low, none }

/// A track after matching against the app's catalog.
class MatchedTrack {
  final NormalizedTrack imported;
  final Song? matchedSong; // null if unmatched
  final MatchConfidence confidence;
  final double score; // 0.0 - 1.0
  final String matchMethod; // 'isrc', 'title_artist', 'fuzzy', etc.
  final bool userResolved; // true if user manually resolved
  MatchedTrack({
    required this.imported,
    this.matchedSong,
    required this.confidence,
    required this.score,
    required this.matchMethod,
    this.userResolved = false,
  });

  MatchedTrack copyWith({Song? matchedSong, MatchConfidence? confidence, double? score, String? matchMethod, bool? userResolved}) {
    return MatchedTrack(
      imported: imported,
      matchedSong: matchedSong ?? this.matchedSong,
      confidence: confidence ?? this.confidence,
      score: score ?? this.score,
      matchMethod: matchMethod ?? this.matchMethod,
      userResolved: userResolved ?? this.userResolved,
    );
  }

  bool get isMatched => matchedSong != null;
  bool get isUncertain => confidence == MatchConfidence.medium || confidence == MatchConfidence.low;
}

/// An imported playlist with its tracks.
class ImportedPlaylist {
  final String name;
  final String? description;
  final String source;
  final List<NormalizedTrack> tracks;
  final String? artworkUrl;
  ImportedPlaylist({
    required this.name,
    this.description,
    required this.source,
    required this.tracks,
    this.artworkUrl,
  });
}

/// Source ID mapping for a canonical track.
class SourceMapping {
  final String canonicalId; // app's internal song id
  final Map<String, String> sourceIds; // 'spotify' -> 'abc123', 'youtube' -> 'xyz789'
  SourceMapping({required this.canonicalId, this.sourceIds = const {}});

  SourceMapping copyWith({String? canonicalId, Map<String, String>? sourceIds}) {
    return SourceMapping(
      canonicalId: canonicalId ?? this.canonicalId,
      sourceIds: sourceIds ?? this.sourceIds,
    );
  }
}

/// Summary report of a migration.
class MigrationReport {
  final String source;
  final int totalTracks;
  final int exactMatches;
  final int highMatches;
  final int mediumMatches;
  final int lowMatches;
  final int unmatched;
  final int playlistsImported;
  final int playlistsFullyMatched;
  final List<ImportedPlaylist> playlists;
  final List<MatchedTrack> matchedTracks;
  final DateTime timestamp;
  MigrationReport({
    required this.source,
    required this.totalTracks,
    this.exactMatches = 0,
    this.highMatches = 0,
    this.mediumMatches = 0,
    this.lowMatches = 0,
    this.unmatched = 0,
    this.playlistsImported = 0,
    this.playlistsFullyMatched = 0,
    this.playlists = const [],
    this.matchedTracks = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  int get matched => exactMatches + highMatches + mediumMatches + lowMatches;
  double get matchRate => totalTracks > 0 ? matched / totalTracks : 0.0;

  MigrationReport copyWith({int? totalTracks, int? exactMatches, int? highMatches, int? mediumMatches, int? lowMatches, int? unmatched, List<MatchedTrack>? matchedTracks}) {
    return MigrationReport(
      source: source,
      totalTracks: totalTracks ?? this.totalTracks,
      exactMatches: exactMatches ?? this.exactMatches,
      highMatches: highMatches ?? this.highMatches,
      mediumMatches: mediumMatches ?? this.mediumMatches,
      lowMatches: lowMatches ?? this.lowMatches,
      unmatched: unmatched ?? this.unmatched,
      playlistsImported: playlistsImported,
      playlistsFullyMatched: playlistsFullyMatched,
      playlists: playlists,
      matchedTracks: matchedTracks ?? this.matchedTracks,
      timestamp: timestamp,
    );
  }
}

/// Listening history event imported from an external source.
class ImportedListeningEvent {
  final String trackTitle;
  final String artist;
  final DateTime timestamp;
  final int? durationPlayedMs;
  final double? completionRate;
  final String source;
  ImportedListeningEvent({
    required this.trackTitle,
    required this.artist,
    required this.timestamp,
    this.durationPlayedMs,
    this.completionRate,
    required this.source,
  });
}
