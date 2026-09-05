import 'package:flutter/material.dart';
import '../../data/models/song_model.dart';
import '../../shared/widgets/glass_card.dart';

typedef AiPlaySong = void Function(Song song, List<Song> queue);

class AiStudioSections extends StatelessWidget {
  final bool isDark;
  final String activeChip;
  final List<Map<String, dynamic>> results;
  final String archetype;
  final List<Map<String, dynamic>> dominantAxes;
  final ValueChanged<String> onChip;
  final AiPlaySong onPlay;

  const AiStudioSections({
    super.key,
    required this.isDark,
    required this.activeChip,
    required this.results,
    required this.archetype,
    required this.dominantAxes,
    required this.onChip,
    required this.onPlay,
  });

  static const chips = [
    ('Late Night', 'noir_night', Icons.nightlight_round),
    ('High Energy', 'high_energy', Icons.bolt_rounded),
    ('Chill', 'ambient_chill', Icons.spa_rounded),
    ('Bollywood', 'bollywood', Icons.music_note_rounded),
    ('Deep Focus', 'deep_focus', Icons.psychology_rounded),
    ('Synthwave', 'retro_synth', Icons.graphic_eq_rounded),
  ];

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: chips.map((chip) {
                final active = activeChip == chip.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChip(chip.$2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(chip.$3,
                            size: 13,
                            color: active
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white70 : Colors.black87)),
                        const SizedBox(width: 5),
                        Text(chip.$1,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black87))),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          ...results.map((item) => _ResultRow(
                isDark: isDark,
                song: item['song'] as Song,
                explanation: item['explanation'] as String? ?? '',
                queue: results.map((entry) => entry['song'] as Song).toList(),
                onPlay: onPlay,
              )),
          _ArchetypeCard(
            isDark: isDark,
            archetype: archetype,
            dominantAxes: dominantAxes,
          ),
          const SizedBox(height: 160),
        ],
      );
}

class _ResultRow extends StatelessWidget {
  final bool isDark;
  final Song song;
  final String explanation;
  final List<Song> queue;
  final AiPlaySong onPlay;
  const _ResultRow(
      {required this.isDark,
      required this.song,
      required this.explanation,
      required this.queue,
      required this.onPlay});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: GlassCard(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => onPlay(song, queue),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(song.artworkUrl ?? '',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: isDark
                          ? const Color(0xFF222222)
                          : const Color(0xFFDDDDDD),
                      child: const Icon(Icons.music_note_rounded, size: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 2),
                  Text(explanation.isNotEmpty ? explanation : song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54)),
                ])),
            Icon(Icons.play_arrow_rounded,
                size: 22, color: isDark ? Colors.white38 : Colors.black38),
          ]),
        ),
      );
}

class _ArchetypeCard extends StatefulWidget {
  final bool isDark;
  final String archetype;
  final List<Map<String, dynamic>> dominantAxes;
  const _ArchetypeCard(
      {required this.isDark,
      required this.archetype,
      required this.dominantAxes});
  @override
  State<_ArchetypeCard> createState() => _ArchetypeCardState();
}

class _ArchetypeCardState extends State<_ArchetypeCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: GestureDetector(
          onTap: () => setState(() => expanded = !expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.person_rounded,
                    size: 14,
                    color: widget.isDark ? Colors.white54 : Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Your sound: ${widget.archetype}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white70
                                : Colors.black87))),
                Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18),
              ]),
              if (expanded) ...[
                const SizedBox(height: 10),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.dominantAxes
                        .map((axis) => Chip(label: Text('${axis['name']}')))
                        .toList()),
              ],
            ]),
          ),
        ),
      );
}
