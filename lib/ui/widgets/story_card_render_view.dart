import 'package:flutter/material.dart';
import '../../data/models/song_model.dart';

class StoryCardTheme {
  final String name;
  final List<Color> colors;

  const StoryCardTheme({required this.name, required this.colors});
}

const List<StoryCardTheme> kStoryThemes = [
  StoryCardTheme(
    name: 'Obsidian',
    colors: [Color(0xFF161616), Color(0xFF090909)],
  ),
  StoryCardTheme(
    name: 'Liquid Violet',
    colors: [Color(0xFF2E0854), Color(0xFF0F021E)],
  ),
  StoryCardTheme(
    name: 'Cyber Cyan',
    colors: [Color(0xFF00384D), Color(0xFF02131C)],
  ),
  StoryCardTheme(
    name: 'Sunset Ember',
    colors: [Color(0xFF4A150A), Color(0xFF140502)],
  ),
];

class StoryCardRenderView extends StatelessWidget {
  final GlobalKey boundaryKey;
  final Song song;
  final String? lyricsSnippet;
  final StoryCardTheme theme;

  const StoryCardRenderView({
    super.key,
    required this.boundaryKey,
    required this.song,
    required this.theme,
    this.lyricsSnippet,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: 280,
        height: 380,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.colors,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Noctra Branding Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'NOCTRA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),

            // Artwork Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                song.artworkUrl ?? '',
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                cacheWidth: 300,
                cacheHeight: 300,
                errorBuilder: (_, __, ___) => Container(
                  width: 150,
                  height: 150,
                  color: Colors.white12,
                  child: const Icon(Icons.music_note_rounded,
                      size: 48, color: Colors.white54),
                ),
              ),
            ),

            // Song Details & Snippet
            Column(
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (lyricsSnippet != null && lyricsSnippet!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '"$lyricsSnippet"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),

            // Bottom Soundwave indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(12, (index) {
                final h = (index % 4 + 1) * 3.5 + 4;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
