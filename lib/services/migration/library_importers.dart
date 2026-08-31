import 'dart:convert';
import 'dart:io';
import '../../data/models/migration_models.dart';

/// Base interface for all library importers.
abstract class LibraryImporter {
  /// Human-readable name of the source (e.g. 'Spotify', 'Apple Music').
  String get sourceName;

  /// File extensions this importer supports (e.g. ['.json', '.csv']).
  List<String> get supportedExtensions;

  /// Whether this importer can handle the given file.
  bool canImport(String filePath, {String? fileContent});

  /// Parse the file and return normalized tracks + playlists.
  Future<MigrationResult> import(File file);

  /// Instructions for the user on how to export data from this source.
  String getInstructions();
}

/// Result of an import operation.
class MigrationResult {
  final List<NormalizedTrack> tracks;
  final List<ImportedPlaylist> playlists;
  final List<ImportedListeningEvent> history;
  final String source;

  MigrationResult({
    required this.tracks,
    this.playlists = const [],
    this.history = const [],
    required this.source,
  });
}

/// Spotify JSON export importer.
class SpotifyExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'Spotify';

  @override
  List<String> get supportedExtensions => ['.json'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.contains('playlist') || name.contains('library') ||
           name.contains('songs') || name.contains('liked') ||
           name.contains('streaming_history') || name.contains('endsong');
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
      // Streaming history or liked songs array
      for (final item in data) {
        if (item is Map) {
          final track = _parseTrack(item);
          if (track != null) tracks.add(track);
        }
      }
    } else if (data is Map) {
      // Playlist format
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
            name: name, description: desc, source: 'spotify', tracks: playlistTracks,
          ));
          tracks.addAll(playlistTracks);
        }
      }
    }
    return MigrationResult(tracks: tracks, playlists: playlists, source: 'spotify');
  }

  NormalizedTrack? _parseTrack(Map item) {
    final name = (item['track'] as Map?)?['name']?.toString() ?? item['name']?.toString();
    final artists = (item['track'] as Map?)?['artists'] as List? ?? item['artists'] as List? ?? [];
    final artist = artists.isNotEmpty ? artists.map((a) => a['name']?.toString() ?? '').join(', ') : '';
    if (name == null || name.isEmpty || artist.isEmpty) return null;

    final album = (item['track'] as Map?)?['album']?['name']?.toString() ?? item['album']?['name']?.toString();
    final durationMs = (item['track'] as Map?)?['duration_ms'] as num? ?? item['duration_ms'] as num?;
    final isrc = (item['track'] as Map?)?['external_ids']?['isrc']?.toString();
    final id = (item['track'] as Map?)?['id']?.toString() ?? item['id']?.toString();
    final addedAt = item['added_at']?.toString();

    return NormalizedTrack(
      title: name, artist: artist, album: album,
      duration: durationMs != null ? Duration(milliseconds: durationMs.toInt()) : null,
      isrc: isrc, source: 'spotify', sourceId: id,
      releaseDate: addedAt,
      originalMetadata: Map<String, dynamic>.from(item),
    );
  }
}

/// Apple Music / iTunes export importer (XML or JSON).
class AppleMusicExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'Apple Music';

  @override
  List<String> get supportedExtensions => ['.json', '.xml', '.csv'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.contains('apple') || name.contains('itunes') ||
           name.contains('library') || name.contains('playlist');
  }

  @override
  String getInstructions() => '''
Export from Apple Music:
1. Use a tool like "Apple Music Playlist Export" or "TuneMyMusic"
2. Export as JSON or CSV
3. Select the exported file
''';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final tracks = <NormalizedTrack>[];
    final playlists = <ImportedPlaylist>[];

    try {
      final data = jsonDecode(content);
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final name = item['name']?.toString() ?? item['trackName']?.toString();
            final artist = item['artistName']?.toString() ?? item['artist']?.toString() ?? '';
            if (name != null && name.isNotEmpty && artist.isNotEmpty) {
              tracks.add(NormalizedTrack(
                title: name, artist: artist,
                album: item['collectionName']?.toString() ?? item['album']?.toString(),
                duration: item['duration'] != null ? Duration(milliseconds: (item['duration'] as num).toInt()) : null,
                source: 'apple_music',
                sourceId: item['id']?.toString(),
                originalMetadata: Map<String, dynamic>.from(item),
              ));
            }
          }
        }
      }
    } catch (_) {
      // Try CSV parsing
      final lines = content.split('\n');
      if (lines.isNotEmpty) {
        final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
        final nameIdx = header.indexWhere((h) => h.contains('name') || h.contains('title'));
        final artistIdx = header.indexWhere((h) => h.contains('artist'));
        if (nameIdx >= 0 && artistIdx >= 0) {
          for (int i = 1; i < lines.length; i++) {
            final cols = lines[i].split(',');
            if (cols.length > nameIdx && cols.length > artistIdx) {
              tracks.add(NormalizedTrack(
                title: cols[nameIdx].trim(), artist: cols[artistIdx].trim(),
                source: 'apple_music', originalMetadata: {},
              ));
            }
          }
        }
      }
    }
    return MigrationResult(tracks: tracks, playlists: playlists, source: 'apple_music');
  }
}

/// YouTube Music / Google Takeout importer.
class YouTubeMusicExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'YouTube Music';

  @override
  List<String> get supportedExtensions => ['.json'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.contains('youtube') || name.contains('takeout') ||
           name.contains('history') || name.contains('library');
  }

  @override
  String getInstructions() => '''
Export from YouTube Music via Google Takeout:
1. Go to takeout.google.com
2. Select "YouTube and YouTube Music"
3. Choose "Playlists" and/or "History"
4. Export and download the ZIP
5. Select the relevant JSON files
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
          // YouTube Music history format
          final title = item['title']?.toString() ?? item['name']?.toString();
          final artist = item['artist']?.toString() ?? item['authors']?.toString();
          if (title != null && title.isNotEmpty) {
            tracks.add(NormalizedTrack(
              title: title, artist: artist ?? 'Unknown',
              source: 'youtube_music',
              sourceId: item['id']?.toString(),
              originalMetadata: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
    } else if (data is Map && data.containsKey('content')) {
      // YouTube Takeout playlist format
      final contentItems = data['content'] as List? ?? [];
      final name = data['title']?.toString() ?? 'YouTube Playlist';
      final playlistTracks = <NormalizedTrack>[];
      for (final item in contentItems) {
        if (item is Map) {
          final title = item['title']?.toString() ?? item['video']['title']?.toString();
          final artist = item['author']?.toString() ?? item['video']['author']?.toString();
          if (title != null) {
            playlistTracks.add(NormalizedTrack(
              title: title, artist: artist ?? 'Unknown', source: 'youtube_music',
              sourceId: item['id']?.toString() ?? item['video']?['id']?.toString(),
              originalMetadata: Map<String, dynamic>.from(item),
            ));
          }
        }
      }
      if (playlistTracks.isNotEmpty) {
        playlists.add(ImportedPlaylist(name: name, source: 'youtube_music', tracks: playlistTracks));
        tracks.addAll(playlistTracks);
      }
    }
    return MigrationResult(tracks: tracks, playlists: playlists, source: 'youtube_music');
  }
}

/// JioSaavn playlist/importer.
class JioSaavnExportImporter extends LibraryImporter {
  @override
  String get sourceName => 'JioSaavn';

  @override
  List<String> get supportedExtensions => ['.json', '.csv', '.txt'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    return filePath.toLowerCase().contains('jiosaavn') ||
           filePath.toLowerCase().contains('saavn');
  }

  @override
  String getInstructions() => '''
Import from JioSaavn:
- Export playlist data if available
- Or paste a playlist URL
- Or provide a text list of tracks (Artist - Title format)
''';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final tracks = <NormalizedTrack>[];

    try {
      final data = jsonDecode(content);
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final title = item['song']?.toString() ?? item['title']?.toString();
            final artist = item['singers']?.toString() ?? item['artist']?.toString() ?? '';
            if (title != null) {
              tracks.add(NormalizedTrack(
                title: title, artist: artist, source: 'jiosaavn',
                sourceId: item['id']?.toString(),
                originalMetadata: Map<String, dynamic>.from(item),
              ));
            }
          }
        }
      }
    } catch (_) {
      // Plain text: "Artist - Title" per line
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(RegExp(r'\s*[-–—]\s*'));
        if (parts.length >= 2) {
          tracks.add(NormalizedTrack(
            title: parts.sublist(1).join(' - ').trim(),
            artist: parts.first.trim(), source: 'jiosaavn',
            originalMetadata: {'raw': trimmed},
          ));
        } else {
          tracks.add(NormalizedTrack(
            title: trimmed, artist: 'Unknown', source: 'jiosaavn',
            originalMetadata: {'raw': trimmed},
          ));
        }
      }
    }
    return MigrationResult(tracks: tracks, source: 'jiosaavn');
  }
}

/// Generic CSV importer.
class GenericCSVImporter extends LibraryImporter {
  @override
  String get sourceName => 'CSV File';

  @override
  List<String> get supportedExtensions => ['.csv'];

  @override
  bool canImport(String filePath, {String? fileContent}) => filePath.toLowerCase().endsWith('.csv');

  @override
  String getInstructions() => 'Select a CSV file with columns like: Title, Artist, Album';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return MigrationResult(tracks: [], source: 'csv');

    final header = lines.first.split(',').map((h) => h.trim().toLowerCase().replaceAll('"', '')).toList();
    final titleIdx = header.indexWhere((h) => h.contains('title') || h.contains('name') || h.contains('track'));
    final artistIdx = header.indexWhere((h) => h.contains('artist') || h.contains('performer'));
    final albumIdx = header.indexWhere((h) => h.contains('album'));

    final tracks = <NormalizedTrack>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (titleIdx >= 0 && cols.length > titleIdx) {
        tracks.add(NormalizedTrack(
          title: cols[titleIdx].trim(),
          artist: artistIdx >= 0 && cols.length > artistIdx ? cols[artistIdx].trim() : 'Unknown',
          album: albumIdx >= 0 && cols.length > albumIdx ? cols[albumIdx].trim() : null,
          source: 'csv', originalMetadata: {'raw': lines[i]},
        ));
      }
    }
    return MigrationResult(tracks: tracks, source: 'csv');
  }

  List<String> _parseCsvLine(String line) {
    // Simple CSV parser that handles quoted fields
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') { inQuotes = !inQuotes; }
      else if (c == ',' && !inQuotes) { result.add(current.toString()); current = StringBuffer(); }
      else { current.write(c); }
    }
    result.add(current.toString());
    return result;
  }
}

/// M3U/M3U8 playlist importer.
class M3UImporter extends LibraryImporter {
  @override
  String get sourceName => 'M3U Playlist';

  @override
  List<String> get supportedExtensions => ['.m3u', '.m3u8'];

  @override
  bool canImport(String filePath, {String? fileContent}) {
    final name = filePath.toLowerCase();
    return name.endsWith('.m3u') || name.endsWith('.m3u8');
  }

  @override
  String getInstructions() => 'Select an M3U or M3U8 playlist file.';

  @override
  Future<MigrationResult> import(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n').map((l) => l.trim()).toList();
    final tracks = <NormalizedTrack>[];
    String? playlistName;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#EXTM3U')) continue;
      if (line.startsWith('#PLAYLIST:')) {
        playlistName = line.substring('#PLAYLIST:'.length).trim();
        continue;
      }
      if (line.startsWith('#EXTINF:')) {
        // Parse: #EXTINF:duration,Artist - Title
        final info = line.substring('#EXTINF:'.length);
        final commaIdx = info.indexOf(',');
        if (commaIdx >= 0) {
          final artistTitle = info.substring(commaIdx + 1).trim();
          final parts = artistTitle.split(RegExp(r'\s*[-–—]\s*'));
          if (parts.length >= 2) {
            tracks.add(NormalizedTrack(
              title: parts.sublist(1).join(' - ').trim(),
              artist: parts.first.trim(), source: 'm3u',
              originalMetadata: {'extinf': line},
            ));
          } else {
            tracks.add(NormalizedTrack(
              title: artistTitle, artist: 'Unknown', source: 'm3u',
              originalMetadata: {'extinf': line},
            ));
          }
        }
        continue;
      }
      if (line.isNotEmpty && !line.startsWith('#')) {
        // File path or URL — extract filename as track name
        final name = line.split('/').last.split('\\').last;
        final cleanName = name.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ');
        if (cleanName.isNotEmpty) {
          tracks.add(NormalizedTrack(
            title: cleanName, artist: 'Unknown', source: 'm3u',
            originalMetadata: {'path': line},
          ));
        }
      }
    }

    final playlists = tracks.isNotEmpty
        ? [ImportedPlaylist(name: playlistName ?? file.path.split('/').last, source: 'm3u', tracks: tracks)]
        : <ImportedPlaylist>[];
    return MigrationResult(tracks: tracks, playlists: playlists, source: 'm3u');
  }
}

/// Get all available importers.
List<LibraryImporter> getAllImporters() => [
  SpotifyExportImporter(),
  AppleMusicExportImporter(),
  YouTubeMusicExportImporter(),
  JioSaavnExportImporter(),
  GenericCSVImporter(),
  M3UImporter(),
];

/// Auto-detect the best importer for a file.
LibraryImporter? detectImporter(String filePath, {String? content}) {
  for (final importer in getAllImporters()) {
    if (importer.canImport(filePath, fileContent: content)) return importer;
  }
  return null;
}
