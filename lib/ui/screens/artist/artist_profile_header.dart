import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/metadata/artist_metadata_service.dart';
import '../../widgets/ai_radio_sheet.dart';
import '../../../shared/widgets/glass_card.dart';

class ArtistProfileHeader extends ConsumerWidget {
  final String artistName;
  final String? avatarUrl;
  final ArtistMetadata? artistMetadata;
  final List<Song> tracks;
  final bool isDark;

  const ArtistProfileHeader({
    super.key,
    required this.artistName,
    required this.avatarUrl,
    required this.artistMetadata,
    required this.tracks,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlayer = ref.watch(audioPlayerServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  avatarUrl ?? '',
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  cacheHeight: 200,
                  errorBuilder: (c, e, st) => Container(
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.person, color: Colors.white54),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              artistName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              artistMetadata?.shortDescription ??
                  '${tracks.length} Master Releases • 320 kbps High-Fidelity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            if (artistMetadata?.bio != null &&
                artistMetadata!.bio!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  artistMetadata!.bio!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text(
                    'Play All',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  onPressed: tracks.isEmpty
                      ? null
                      : () => audioPlayer.playSong(tracks.first,
                          newQueue: tracks),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text(
                    'AI Radio',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  onPressed: tracks.isEmpty
                      ? null
                      : () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (c) =>
                                AIRadioSheet(seedSong: tracks.first),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
