import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_card.dart';

class MigrationChooseView extends StatelessWidget {
  final bool isDark;
  final ValueChanged<String> onSelectSource;

  const MigrationChooseView({
    super.key,
    required this.isDark,
    required this.onSelectSource,
  });

  static const List<Map<String, dynamic>> sources = [
    {
      'source': 'Spotify',
      'label': 'Streaming export',
      'icon': Icons.music_note,
      'color': Color(0xFF1DB954)
    },
    {
      'source': 'Apple Music',
      'label': 'Media library export',
      'icon': Icons.library_music_rounded,
      'color': Color(0xFFFA2D48)
    },
    {
      'source': 'YouTube Music',
      'label': 'Video music export',
      'icon': Icons.play_arrow_rounded,
      'color': Color(0xFFFF0000)
    },
    {
      'source': 'JioSaavn',
      'label': 'Regional catalog export',
      'icon': Icons.waves_rounded,
      'color': Color(0xFF2BC5F3)
    },
    {
      'source': 'Other (CSV, M3U, JSON)',
      'label': 'Other file export',
      'icon': Icons.file_open_rounded,
      'color': Colors.white54
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Text(
          'Bring your playlists and listening history from other music services without connecting your accounts.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        ...sources.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => onSelectSource(s['source'] as String),
              child: GlassCard(
                radius: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (s['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        color: s['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
