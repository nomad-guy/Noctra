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
  /// False when the source feature vector was missing/corrupt (wrong
  /// dimension, non-finite, out of range) — consumers should treat the
  /// default 0.5 vector as "unknown embedding", never as real data.
  final bool hasValidFeatureVector;
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
    bool? hasValidFeatureVector,
    this.replayCount = 0,
    this.skipCount = 0,
  })  : featureVector = _normalizeVector(featureVector),
        hasValidFeatureVector =
            hasValidFeatureVector ?? _vectorLooksValid(featureVector);

  /// True when [featureVector] carries genuine, usable embedding data:
  /// the song was constructed/parsed with a valid exactly-32D vector
  /// AND that vector is not the neutral all-0.5 fill. Consumers must
  /// use this instead of inferring "missing" from the vector's values
  /// (a real neutral vector is indistinguishable from the fill by
  /// value alone; only the explicit validity flag can tell them apart).
  bool get hasUsableEmbedding =>
      hasValidFeatureVector && !featureVector.every((v) => v == 0.5);

  /// Coerce an optionally-supplied vector to the canonical 32D form.
  /// Missing or malformed vectors become the neutral 0.5 fill (never
  /// silently padded/truncated real data); [hasValidFeatureVector]
  /// records whether real data was actually supplied.
  static List<double> _normalizeVector(List<double>? raw) {
    if (raw == null) return List.filled(32, 0.5);
    if (raw.length == 32 &&
        raw.every((v) => v.isFinite && v >= 0.0 && v <= 1.0)) {
      return List<double>.from(raw);
    }
    return List.filled(32, 0.5);
  }

  static bool _vectorLooksValid(List<double>? raw) =>
      raw != null &&
      raw.length == 32 &&
      raw.every((v) => v.isFinite && v >= 0.0 && v <= 1.0);

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
    bool? hasValidFeatureVector,
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
      hasValidFeatureVector: hasValidFeatureVector ?? this.hasValidFeatureVector,
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
    // Feature vector: require EXACTLY 32 finite values within [0.0, 1.0].
    // Anything else is marked invalid (hasValidFeatureVector=false) so
    // consumers never mistake a corrupt vector for real recommendation data.
    List<double> vec = List.filled(32, 0.5);
    bool hasValidVector = false;
    if (map['featureVector'] != null) {
      try {
        List<dynamic> raw;
        if (map['featureVector'] is List) {
          raw = map['featureVector'] as List;
        } else {
          final decoded = jsonDecode(map['featureVector']);
          raw = decoded is List ? decoded : <dynamic>[];
        }
        if (raw.length == 32 && raw.every((e) => e is num)) {
          final parsed = raw.map<double>((e) => (e as num).toDouble()).toList();
          // All 32 values must be finite and within [0.0, 1.0]
          if (parsed.every((v) => v.isFinite && v >= 0.0 && v <= 1.0)) {
            vec = parsed;
            hasValidVector = true;
          }
          // else: out-of-range or NaN/Infinity — invalid
        }
        // else: wrong dimension count or non-numeric — invalid
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
      duration: Duration(
          milliseconds: parsedDurationMs.clamp(0, 24 * 3600 * 1000)),
      genre: map['genre']?.toString(),
      mood: map['mood']?.toString(),
      isDownloaded: map['isDownloaded'] == 1 || map['isDownloaded'] == true,
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
      featureVector: vec,
      hasValidFeatureVector: hasValidVector,
      replayCount: _parseInt(map['replayCount']),
      skipCount: _parseInt(map['skipCount']),
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) => Song.fromMap(json);

  // Type-safe parsing helpers for external data
  /// Parse a required string field.
  /// - missing (null): returns '' so callers can synthesize an ID
  /// - numeric values (e.g. 123456): converted via toString()
  /// - non-String/non-num values (bool, Map, List): throws FormatException
  static String _parseRequiredStr(dynamic v, String field) {
    if (v == null) return ''; // missing key — caller decides
    if (v is! String || v.trim().isEmpty) {
      throw FormatException(
          'Invalid Song.$field: expected a non-empty String');
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
