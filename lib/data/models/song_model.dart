import 'dart:convert';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final String? localFilePath;
  final String? streamUrl;
  final Duration duration;
  final String? genre;
  final String? mood;
  final bool isDownloaded;
  final bool isFavorite;
  final List<double> featureVector;
  final int replayCount;
  final int skipCount;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'Single',
    this.artworkUrl,
    this.localFilePath,
    this.streamUrl,
    required this.duration,
    this.genre,
    this.mood,
    this.isDownloaded = false,
    this.isFavorite = false,
    List<double>? featureVector,
    this.replayCount = 0,
    this.skipCount = 0,
  }) : featureVector = featureVector ?? List.filled(32, 0.5);

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    bool clearArtworkUrl = false,
    String? localFilePath,
    bool clearLocalFilePath = false,
    String? streamUrl,
    bool clearStreamUrl = false,
    Duration? duration,
    String? genre,
    bool clearGenre = false,
    String? mood,
    bool clearMood = false,
    bool? isDownloaded,
    bool? isFavorite,
    List<double>? featureVector,
    int? replayCount,
    int? skipCount,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: clearArtworkUrl ? null : (artworkUrl ?? this.artworkUrl),
      localFilePath: clearLocalFilePath ? null : (localFilePath ?? this.localFilePath),
      streamUrl: clearStreamUrl ? null : (streamUrl ?? this.streamUrl),
      duration: duration ?? this.duration,
      genre: clearGenre ? null : (genre ?? this.genre),
      mood: clearMood ? null : (mood ?? this.mood),
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isFavorite: isFavorite ?? this.isFavorite,
      featureVector: featureVector != null ? List<double>.from(featureVector) : List<double>.from(this.featureVector),
      replayCount: replayCount ?? this.replayCount,
      skipCount: skipCount ?? this.skipCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'artworkUrl': artworkUrl,
        'localFilePath': localFilePath,
        'streamUrl': streamUrl,
        'durationMs': duration.inMilliseconds,
        'genre': genre,
        'mood': mood,
        'isDownloaded': isDownloaded ? 1 : 0,
        'isFavorite': isFavorite ? 1 : 0,
        'featureVector': jsonEncode(featureVector),
        'replayCount': replayCount,
        'skipCount': skipCount,
      };

  Map<String, dynamic> toJson() => toMap();

  factory Song.fromMap(Map<String, dynamic> map) {
    // Feature vector: validate dimensions, finiteness, range [0.0, 1.0]
    List<double> vec = List.filled(32, 0.5);
    if (map['featureVector'] != null) {
      try {
        List<dynamic> raw;
        if (map['featureVector'] is List) {
          raw = map['featureVector'] as List;
        } else {
          final decoded = jsonDecode(map['featureVector']);
          raw = decoded is List ? decoded : <dynamic>[];
        }
        if (raw.isNotEmpty && raw.every((e) => e is num)) {
          final parsed = raw.map<double>((e) => (e as num).toDouble()).toList();
          // All values must be finite and within [0.0, 1.0]
          if (parsed.every((v) => v.isFinite && v >= 0.0 && v <= 1.0)) {
            vec = parsed;
            while (vec.length < 32) { vec.add(0.5); }
            if (vec.length > 32) { vec = vec.sublist(0, 32); }
          }
          // else: out-of-range or NaN/Infinity — keep default 0.5 vector
        }
      } catch (_) {}
    }

    // Duration: durationMs is always milliseconds, no magnitude heuristic.
    // The legacy 'duration' field is treated as SECONDS (never milliseconds).
    int parsedDurationMs = 0;
    final msVal = map['durationMs'];
    if (msVal != null) {
      final num? p = msVal is num ? msVal : num.tryParse(msVal.toString());
      if (p != null && p > 0) parsedDurationMs = p.toInt();
    } else {
      final secVal = map['duration'];
      if (secVal != null) {
        final num? p = secVal is num ? secVal : num.tryParse(secVal.toString());
        if (p != null && p > 0) parsedDurationMs = (p * 1000).toInt();
      }
    }

    return Song(
      id: _parseRequiredStr(map['id'], 'id'),
      title: _parseOptStr(map['title']) ?? 'Unknown Track',
      artist: _parseOptStr(map['artist']) ?? 'Unknown Artist',
      album: _parseOptStr(map['album']) ?? 'Single',
      artworkUrl: map['artworkUrl']?.toString(),
      localFilePath: map['localFilePath']?.toString(),
      streamUrl: map['streamUrl']?.toString(),
      duration: Duration(milliseconds: parsedDurationMs),
      genre: map['genre']?.toString(),
      mood: map['mood']?.toString(),
      isDownloaded: map['isDownloaded'] == 1 || map['isDownloaded'] == true,
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
      featureVector: vec,
      replayCount: _parseInt(map['replayCount']),
      skipCount: _parseInt(map['skipCount']),
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) => Song.fromMap(json);

  // Type-safe parsing helpers for external data
  /// Parse a required string field. Rejects non-String values and empty strings.
  static String _parseRequiredStr(dynamic v, String field) {
    if (v is! String || v.trim().isEmpty) {
      // Required identity field is missing or wrong type — return empty
      // to signal invalidity to the caller.
      return '';
    }
    return v.trim();
  }

  /// Parse an optional string field. Converts non-String values via toString().
  static String? _parseOptStr(dynamic v) =>
      v?.toString().trim().isEmpty == true ? null : v?.toString().trim();

  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}
