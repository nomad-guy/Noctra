import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/noir_theme.dart';
import '../../core/utils/localization/localization_keys.dart';
import '../../core/utils/localization/localization_scope.dart';
import '../../services/p2p/p2p_sync_service.dart';
import '../../shared/widgets/glass_card.dart';


class JamQueueTab extends ConsumerWidget {
  final bool isDark;
  final P2PSyncService syncService;

  const JamQueueTab({
    super.key,
    required this.isDark,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = syncService.collaborativeQueue;

    return Column(
      children: [
        // Queue Header Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.tr(L10nKeys.sharedQueue).toUpperCase()} (${queue.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                context.tr(L10nKeys.liveSyncedPeers),
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38),
              ),
            ],
          ),
        ),

        // Queue List
        Expanded(
          child: queue.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded,
                            size: 36,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          syncService.hostControlsOnly && !syncService.isHost
                              ? context.tr(L10nKeys.hostRestrictedQueue)
                              : context.tr(L10nKeys.collaborativeQueueEmpty),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: queue.length,
                  itemBuilder: (context, i) {
                    final song = queue[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: GlassCard(
                        radius: 12,
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                song.artworkUrl ?? '',
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, st) => Container(
                                  width: 42,
                                  height: 42,
                                  color: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : const Color(0xFFE5E5E5),
                                  child: Icon(Icons.music_note_rounded,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black),
                                  ),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? NoirColors.blackTextSecondary
                                            : NoirColors.whiteTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (!(syncService.hostControlsOnly &&
                                !syncService.isHost))
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54),
                                onPressed: () {
                                  syncService
                                      .removeFromCollaborativeQueue(song.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
