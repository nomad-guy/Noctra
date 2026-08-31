import 'dart:convert';
import 'package:flutter/material.dart';

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
    String? localFilePath,
    String? streamUrl,
    Duration? duration,
    String? genre,
    String? mood,
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
      artworkUrl: artworkUrl ?? this.artworkUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      streamUrl: streamUrl ?? this.streamUrl,
      duration: duration ?? this.duration,
      genre: genre ?? this.genre,
      mood: mood ?? this.mood,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      featureVector: featureVector ?? this.featureVector,
      replayCount: replayCount ?? this.replayCount,
      skipCount: skipCount ?? this.skipCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'featureVector': featureVector,
      'replayCount': replayCount,
      'skipCount': skipCount,
    };
  }

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
      } catch (_) {}
    }

    return Song(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Unknown Track',
      artist: map['artist'] ?? 'Unknown Artist',
      album: map['album'] ?? 'Single',
      artworkUrl: map['artworkUrl'],
      localFilePath: map['localFilePath'],
      streamUrl: map['streamUrl'],
      duration: Duration(milliseconds: map['durationMs'] ?? (map['duration'] != null ? ((map['duration'] as num).toInt() * 1000) : 180000)),
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

class VibeChipData {
  final String label;
  final IconData iconData;
  final String keyName;

  const VibeChipData({
    required this.label,
    required this.iconData,
    required this.keyName,
  });
}
