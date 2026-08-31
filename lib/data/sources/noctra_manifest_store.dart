import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

class SongManifest {
  final String songId;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String language;
  final int playCount;
  final int skipCount;
  final int totalListenSeconds;
  final double completionRate;
  final int lastPlayedTimestamp;
  final List<double> featureVector;

  const SongManifest({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.language,
    required this.playCount,
    required this.skipCount,
    required this.totalListenSeconds,
    required this.completionRate,
    required this.lastPlayedTimestamp,
    required this.featureVector,
  });

  Map<String, dynamic> toMap() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'language': language,
        'playCount': playCount,
        'skipCount': skipCount,
        'totalListenSeconds': totalListenSeconds,
        'completionRate': completionRate,
        'lastPlayedTimestamp': lastPlayedTimestamp,
        'featureVector': featureVector,
      };

  factory SongManifest.fromMap(Map<String, dynamic> map) => SongManifest(
        songId: map['songId'] ?? '',
        title: map['title'] ?? '',
        artist: map['artist'] ?? '',
        album: map['album'] ?? '',
        genre: map['genre'] ?? 'Music',
        language: map['language'] ?? 'English',
        playCount: (map['playCount'] as num?)?.toInt() ?? 0,
        skipCount: (map['skipCount'] as num?)?.toInt() ?? 0,
        totalListenSeconds: (map['totalListenSeconds'] as num?)?.toInt() ?? 0,
        completionRate: (map['completionRate'] as num?)?.toDouble() ?? 1.0,
        lastPlayedTimestamp: (map['lastPlayedTimestamp'] as num?)?.toInt() ?? 0,
        featureVector: (map['featureVector'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? List.filled(32, 0.5),
      );
}

class NoctraManifestStore {
  final Map<String, SongManifest> manifests = {};
  final Map<String, int> artistWeights = {};
  final Map<String, int> genreWeights = {};
  final Map<String, int> languageWeights = {};

  void loadFromRawMap(Map<String, dynamic> rawMap) {
    manifests.clear();
    artistWeights.clear();
    genreWeights.clear();
    languageWeights.clear();

    rawMap.forEach((k, v) {
      final m = SongManifest.fromMap(Map<String, dynamic>.from(v));
      manifests[k] = m;
      artistWeights[m.artist] = (artistWeights[m.artist] ?? 0) + m.playCount;
      genreWeights[m.genre] = (genreWeights[m.genre] ?? 0) + m.playCount;
      languageWeights[m.language] = (languageWeights[m.language] ?? 0) + m.playCount;
    });
  }

  void recordManifest(Song song, {String action = 'play', int listenedSeconds = 0, double completionRate = 1.0}) {
    final existing = manifests[song.id];
    final plays = (existing?.playCount ?? 0) + (action == 'skip' ? 0 : 1);
    final skips = (existing?.skipCount ?? 0) + (action == 'skip' ? 1 : 0);
    final totalSec = (existing?.totalListenSeconds ?? 0) + listenedSeconds;

    String inferredLang = 'English';
    final lTitle = song.title.toLowerCase();
    final lArtist = song.artist.toLowerCase();
    if (lTitle.contains('tum') || lTitle.contains('dil') || lArtist.contains('arijit') || lArtist.contains('pritam') || lTitle.contains('pyaar')) {
      inferredLang = 'Hindi';
    } else if (lTitle.contains('jatt') || lArtist.contains('sidhu') || lArtist.contains('diljit') || lTitle.contains('punjabi')) {
      inferredLang = 'Punjabi';
    }

    final updated = SongManifest(
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      genre: song.genre ?? 'Music',
      language: inferredLang,
      playCount: plays,
      skipCount: skips,
      totalListenSeconds: totalSec,
      completionRate: completionRate,
      lastPlayedTimestamp: DateTime.now().millisecondsSinceEpoch,
      featureVector: song.featureVector,
    );

    manifests[song.id] = updated;
    artistWeights[song.artist] = (artistWeights[song.artist] ?? 0) + 1;
    genreWeights[updated.genre] = (genreWeights[updated.genre] ?? 0) + 1;
    languageWeights[inferredLang] = (languageWeights[inferredLang] ?? 0) + 1;
  }

  void persist() async {
    try {
      if (manifests.length > 500) {
        final sortedKeys = manifests.keys.toList()
          ..sort((a, b) => manifests[a]!.lastPlayedTimestamp.compareTo(manifests[b]!.lastPlayedTimestamp));
        for (final k in sortedKeys.take(manifests.length - 500)) { manifests.remove(k); }
      }
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      manifests.forEach((k, v) => map[k] = v.toMap());
      await prefs.setString('noctra_kg_manifests', jsonEncode(map));
    } catch (_) {}
  }
}
