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
        'featureVector': jsonEncode(featureVector),
        'replayCount': replayCount,
        'skipCount': skipCount,
      };

  Map<String, dynamic> toJson() => toMap();

  factory Song.fromMap(Map<String, dynamic> map) {
    List<double> vec = List.filled(32, 0.5);
    if (map['featureVector'] != null) {
      try {
        if (map['featureVector'] is List) {
          vec = (map['featureVector'] as List).map((e) => (e as num).toDouble()).toList();
        } else {
          final decoded = jsonDecode(map['featureVector']);
          if (decoded is List) {
            vec = decoded.map((e) => (e as num).toDouble()).toList();
          }
        }
        while (vec.length < 32) { vec.add(0.5); }
        if (vec.length > 32) { vec = vec.take(32).toList(); }
      } catch (_) {}
    }

    int parsedDurationMs = 0;
    final msVal = map['durationMs'];
    final secVal = map['duration'];
    if (msVal != null) {
      // durationMs is always milliseconds — never apply magnitude heuristic
      final num? p = msVal is num ? msVal : num.tryParse(msVal.toString());
      if (p != null && p > 0) {
        parsedDurationMs = p.toInt();
      }
    } else if (secVal != null) {
      // duration field: treat as seconds if small, milliseconds if large
      final num? p = secVal is num ? secVal : num.tryParse(secVal.toString());
      if (p != null && p > 0) {
        parsedDurationMs = p > 10000 ? p.toInt() : (p * 1000).toInt();
      }
    }

    return Song(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Unknown Track',
      artist: map['artist'] ?? 'Unknown Artist',
      album: map['album'] ?? 'Single',
      artworkUrl: map['artworkUrl'],
      localFilePath: map['localFilePath'],
      streamUrl: map['streamUrl'],
      duration: Duration(milliseconds: parsedDurationMs),
      genre: map['genre'],
      mood: map['mood'],
      isDownloaded: map['isDownloaded'] == 1 || map['isDownloaded'] == true,
      featureVector: vec,
      replayCount: map['replayCount'] ?? 0,
      skipCount: map['skipCount'] ?? 0,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) => Song.fromMap(json);
}
