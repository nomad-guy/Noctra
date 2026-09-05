import 'package:flutter/material.dart';

class AIFolder {
  final String id;
  final String name;
  final String description;
  final String vibeKey;
  final IconData icon;
  final int trackCount;
  final bool isGenerated;

  const AIFolder({
    required this.id,
    required this.name,
    required this.description,
    required this.vibeKey,
    required this.icon,
    required this.trackCount,
    this.isGenerated = true,
  });
}

enum MixSourceType { longTerm, session, genre, artist, discovery, prompt }

class AIMix {
  final String id;
  final String title;
  final String subtitle;
  final String artworkUrl;
  final String vibeKey;
  final MixSourceType sourceType;

  const AIMix({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
    required this.vibeKey,
    required this.sourceType,
  });
}
