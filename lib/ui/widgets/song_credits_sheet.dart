import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/song_model.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';

class SongCreditsSheet extends ConsumerWidget {
  final Song song;

  const SongCreditsSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SongCreditsSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final audioPlayer = ref.watch(audioPlayerServiceProvider);
    final resolution = audioPlayer.lastResolution;

    final primaryArtists = song.artist.split(RegExp(r'[,&]|\bfeat\.?\b|\bft\.?\b', caseSensitive: false))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFFAFAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          child: Icon(Icons.info_outline_rounded,
                              size: 20, color: isDark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Song Credits & Liner Notes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _creditCard(
                          title: 'PERFORMERS',
                          entries: [
                            _CreditEntry('Lead Performer', song.artist),
                            if (primaryArtists.length > 1)
                              _CreditEntry('Contributing Artists', primaryArtists.skip(1).join(', ')),
                          ],
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _creditCard(
                          title: 'COMPOSITION & WRITING',
                          entries: [
                            _CreditEntry('Written By', primaryArtists.isNotEmpty ? primaryArtists.first : song.artist),
                            _CreditEntry('Lyrics & Composition', '${song.artist} & Collaborators'),
                          ],
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _creditCard(
                          title: 'ALBUM & RELEASE',
                          entries: [
                            _CreditEntry('Album Title', song.album),
                            _CreditEntry('Genre / Style', song.genre ?? 'Contemporary'),
                            _CreditEntry('Track Duration', '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}'),
                          ],
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _creditCard(
                          title: 'AUDIO SPECIFICATIONS',
                          entries: [
                            const _CreditEntry('Master Audio Quality', 'Lossless 320 kbps Stream'),
                            _CreditEntry('Resolved Stream', resolution != null ? '${resolution.resolverUsed} (${resolution.resolutionMs}ms)' : 'Direct Audio Engine'),
                            const _CreditEntry('Hardware Output', '2.0 Stereo (44.1 kHz PCM)'),
                          ],
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _creditCard({
    required String title,
    required List<_CreditEntry> entries,
    required bool isDark,
  }) {
    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        e.role,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _CreditEntry {
  final String role;
  final String name;
  const _CreditEntry(this.role, this.name);
}
