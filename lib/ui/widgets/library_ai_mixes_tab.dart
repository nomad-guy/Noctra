import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/ai_folder_model.dart';
import '../../data/repositories/music_repository.dart';
import '../../providers/app_providers.dart';
import '../../services/ytdlp/music_service.dart';

class LibraryAIMixesTab extends ConsumerStatefulWidget {
  final bool isDark;
  final MusicRepository repo;
  const LibraryAIMixesTab({super.key, required this.isDark, required this.repo});
  @override
  ConsumerState<LibraryAIMixesTab> createState() => _LibraryAIMixesTabState();
}

class _LibraryAIMixesTabState extends ConsumerState<LibraryAIMixesTab> {
  bool _playingMix = false;

  Future<void> _playMix(AIPlaylist pl) async {
    if (_playingMix) return;
    setState(() => _playingMix = true);
    try {
      final tracks = pl.tracks;
      if (tracks.isNotEmpty && mounted) {
        ref.read(audioPlayerServiceProvider).playSong(tracks.first, newQueue: tracks);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _playingMix = false);
    }
  }

  Future<void> _playFolder(AIFolder folder) async {
    if (_playingMix) return;
    setState(() => _playingMix = true);
    try {
      // AIFolders use fetchVibeFeed since they don't store tracks directly
      final tracks = await MusicService.fetchVibeFeed(folder.vibeKey)
          .timeout(const Duration(seconds: 8));
      if (tracks.isNotEmpty && mounted) {
        ref.read(audioPlayerServiceProvider).playSong(tracks.first, newQueue: tracks);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _playingMix = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final repo = widget.repo;
    final mixes = repo.getAIGeneratedPlaylists();
    final folders = repo.getAICuratedFolders();
    final archetype = repo.getUserMusicalArchetype();
    final topArtists = repo.getTopArtists(limit: 5);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 160),
      children: [
        // Subtle archetype greeting
        Padding(
          padding: const EdgeInsets.only(bottom: 18, top: 4),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 6),
            Expanded(child: Text('Your sound: $archetype',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500))),
          ]),
        ),

        // AI Mixes — horizontal scroll of square cards
        if (mixes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Your Mixes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary)),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: mixes.length,
              itemBuilder: (context, i) {
                final pl = mixes[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _playMix(pl),
                    child: SizedBox(
                      width: 130,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(children: [
                            Image.network(pl.artworkUrl, width: 130, height: 108, fit: BoxFit.cover,
                              cacheWidth: 260, cacheHeight: 216,
                              errorBuilder: (c, e, st) => Container(width: 130, height: 108,
                                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5),
                                child: Icon(Icons.album_rounded, size: 36, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.24)))),
                            Positioned(bottom: 8, right: 8,
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                child: Icon(Icons.play_arrow_rounded, size: 16, color: isDark ? Colors.black : Colors.white),
                              )),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        Text(pl.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                        Text(pl.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],

        // AI Curated Folders
        if (folders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('AI Folders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? NoirColors.blackTextPrimary : NoirColors.whiteTextPrimary)),
          ),
          ...folders.map((folder) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _playFolder(folder),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(folder.icon, size: 20, color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(folder.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 2),
                    Text(folder.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${folder.trackCount}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.60))),
                    Text('tracks', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                  ]),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                ]),
              ),
            ),
          )),
          const SizedBox(height: 24),
        ],

        // Top Artists — slim chip row
        if (topArtists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('In Your Rotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70))),
          ),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: topArtists.map((artist) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_rounded, size: 12, color: isDark ? Colors.white54 : Colors.black54),
                const SizedBox(width: 5),
                Text(artist, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white.withValues(alpha: 0.80) : Colors.black87)),
              ]),
            )).toList(),
          ),
        ],

        // Empty state
        if (mixes.isEmpty && folders.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(children: [
              Icon(Icons.auto_awesome_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.24)),
              const SizedBox(height: 12),
              Text('Keep listening', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black54)),
              const SizedBox(height: 6),
              Text('Your AI mixes and folders will appear\nas you build your listening history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
            ]),
          ),
      ],
    );
  }
}
