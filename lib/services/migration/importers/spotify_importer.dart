import 'dart:convert';
import 'dart:io';
import '../../../data/models/migration_models.dart';
import '../library_importers.dart';

/// Spotify JSON export importer.
class SpotifyExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'Spotify';

  @override
  List<String> get supportedExtensions => ['.json'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.contains('playlist') ||
        name.contains('library') ||
        name.contains('songs') ||
        name.contains('liked') ||
        name.contains('streaming_history') ||
        name.contains('endsong');
  }

  @override
  String getInstructions() => '''
Download your Spotify data:
1. Go to privacy.spotify.com/account/data
2. Request "Account data" or "Extended streaming history"
3. Download the ZIP when ready
4. Select the JSON files (playlist, songs, or streaming history)
''';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final data = jsonDecode(content);
    final tracks = <NormalizedTrack>[];
    final playlists = <ImportedPlaylist>[];

    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          final track = _parseTrack(item);
          if (track != null) tracks.add(track);
        }
      }
    } else if (data is Map) {
      if (data.containsKey('tracks')) {
        final name = data['name']?.toString() ?? 'Imported Playlist';
        final desc = data['description']?.toString();
        final playlistTracks = <NormalizedTrack>[];
        final trackItems = data['tracks'] as List? ?? [];
        for (final item in trackItems) {
          if (item is Map) {
            final trackData = item['track'] as Map? ?? item;
            final track = _parseTrack(trackData);
            if (track != null) playlistTracks.add(track);
          }
        }
        if (playlistTracks.isNotEmpty) {
          playlists.add(ImportedPlaylist(
            name: name,
            description: desc,
            source: 'spotify',
            tracks: playlistTracks,
          ));
          tracks.addAll(playlistTracks);
        }
      }
    }
    return MigrationResult(
        tracks: tracks, playlists: playlists, source: 'spotify');
  }

  NormalizedTrack? _parseTrack(Map item) {
    final name = (item['track'] as Map?)?['name']?.toString() ??
        item['name']?.toString();
    final artists = (item['track'] as Map?)?['artists'] as List? ??
        item['artists'] as List? ??
        [];
    final artist = artists.isNotEmpty
        ? artists.map((a) => a['name']?.toString() ?? '').join(', ')
        : '';
    if (name == null || name.isEmpty || artist.isEmpty) return null;

    final album = (item['track'] as Map?)?['album']?['name']?.toString() ??
        item['album']?['name']?.toString();
    final durationMs = (item['track'] as Map?)?['duration_ms'] as num? ??
        item['duration_ms'] as num?;
    final isrc = (item['track'] as Map?)?['external_ids']?['isrc']?.toString();
    final id =
        (item['track'] as Map?)?['id']?.toString() ?? item['id']?.toString();
    final addedAt = item['added_at']?.toString();

    return NormalizedTrack(
      title: name,
      artist: artist,
      album: album,
      duration: durationMs != null
          ? Duration(milliseconds: durationMs.toInt())
          : null,
      isrc: isrc,
      source: 'spotify',
      sourceId: id,
      releaseDate: addedAt,
      originalMetadata: Map<String, dynamic>.from(item),
    );
  }
}
