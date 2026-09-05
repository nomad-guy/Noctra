import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/noctra_logger.dart';
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
        featureVector: (map['featureVector'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            List.filled(32, 0.5),
      );
}

class NoctraManifestStore {
  final Map<String, SongManifest> manifests = {};
  final Map<String, int> artistWeights = {};
  final Map<String, int> genreWeights = {};
  final Map<String, int> languageWeights = {};

  // Reset used by NoctraLocalDatabase.debugResetForTest() and tests.
  void debugResetForTest() {
    manifests.clear();
    artistWeights.clear();
    genreWeights.clear();
    languageWeights.clear();
  }

  void loadFromRawMap(Map<String, dynamic> rawMap) {
    manifests.clear();
    artistWeights.clear();
    genreWeights.clear();
    languageWeights.clear();

    rawMap.forEach((k, v) {
      if (v is Map) {
        try {
          final m = SongManifest.fromMap(Map<String, dynamic>.from(v));
          if (m.songId.isNotEmpty) {
            manifests[k] = m;
          }
        } catch (e) {
          NoctraLogger.w('Skipping corrupt manifest record $k', e);
        }
      }
    });
    _rebuildWeights();
  }

  void _rebuildWeights() {
    artistWeights.clear();
    genreWeights.clear();
    languageWeights.clear();
    for (final m in manifests.values) {
      artistWeights[m.artist] = (artistWeights[m.artist] ?? 0) + m.playCount;
      genreWeights[m.genre] = (genreWeights[m.genre] ?? 0) + m.playCount;
      languageWeights[m.language] =
          (languageWeights[m.language] ?? 0) + m.playCount;
    }
  }

  static final RegExp _hindiTitleRegex = RegExp(
      r'\b(tum|dil|pyaar|ishq|tere|hum|zindagi|saath|mera|meri)\b',
      caseSensitive: false);
  static final RegExp _hindiArtistRegex = RegExp(
      r'\b(arijit|pritam|shreya|atif|sonu|alka|kumar sanu|kk)\b',
      caseSensitive: false);
  static final RegExp _punjabiTitleRegex = RegExp(
      r'\b(jatt|pind|gabru|punjab|yaar|tere bina)\b',
      caseSensitive: false);
  static final RegExp _punjabiArtistRegex = RegExp(
      r'\b(sidhu|diljit|karan aujla|ap dhillon|shubh|amrit maan)\b',
      caseSensitive: false);

  void recordManifest(Song song,
      {String action = 'play',
      int listenedSeconds = 0,
      double completionRate = 1.0}) {
    final existing = manifests[song.id];
    final plays = (existing?.playCount ?? 0) + (action == 'skip' ? 0 : 1);
    final skips = (existing?.skipCount ?? 0) + (action == 'skip' ? 1 : 0);
    final totalSec = (existing?.totalListenSeconds ?? 0) + listenedSeconds;

    String inferredLang = 'English';
    final lGenre = (song.genre ?? '').toLowerCase();
    if (lGenre.contains('hindi') || lGenre.contains('bollywood')) {
      inferredLang = 'Hindi';
    } else if (lGenre.contains('punjabi')) {
      inferredLang = 'Punjabi';
    } else if (lGenre.contains('spanish') || lGenre.contains('latin')) {
      inferredLang = 'Spanish';
    } else if (lGenre.contains('korean') || lGenre.contains('k-pop')) {
      inferredLang = 'Korean';
    } else if (lGenre.contains('japanese') || lGenre.contains('j-pop')) {
      inferredLang = 'Japanese';
    } else if (_hindiTitleRegex.hasMatch(song.title) ||
        _hindiArtistRegex.hasMatch(song.artist)) {
      inferredLang = 'Hindi';
    } else if (_punjabiTitleRegex.hasMatch(song.title) ||
        _punjabiArtistRegex.hasMatch(song.artist)) {
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
    _rebuildWeights();
  }

  Future<void> persist({SharedPreferences? prefs}) async {
    try {
      if (manifests.length > 500) {
        final sortedKeys = manifests.keys.toList()
          ..sort((a, b) => manifests[a]!
              .lastPlayedTimestamp
              .compareTo(manifests[b]!.lastPlayedTimestamp));
        for (final k in sortedKeys.take(manifests.length - 500)) {
          manifests.remove(k);
        }
        _rebuildWeights();
      }
      final p = prefs ?? await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      manifests.forEach((k, v) => map[k] = v.toMap());
      await p.setString('noctra_kg_manifests', jsonEncode(map));
    } catch (e) {
      NoctraLogger.e('Failed to persist manifests store', e);
    }
  }
}
