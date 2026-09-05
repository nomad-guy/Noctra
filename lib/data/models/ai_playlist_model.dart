import 'package:flutter/material.dart';
import 'song_model.dart';

class AIPlaylist {
  final String id, title, subtitle, artworkUrl, vibeKey;
  final List<Song> tracks;
  const AIPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
    required this.vibeKey,
    this.tracks = const [],
  });
}

class VibeChip {
  final String keyName, label;
  final IconData iconData;
  const VibeChip({
    required this.keyName,
    required this.label,
    required this.iconData,
  });
}
