import 'package:flutter/material.dart';
import '../../../data/models/migration_models.dart';
import '../../../shared/widgets/glass_card.dart';

class MigrationPreviewView extends StatelessWidget {
  final MigrationReport report;
  final List<MatchedTrack> matchedTracks;
  final bool isDark;
  final VoidCallback onCancel;
  final VoidCallback onCommit;

  const MigrationPreviewView({
    super.key,
    required this.report,
    required this.matchedTracks,
    required this.isDark,
    required this.onCancel,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    final r = report;
    final uncertainMatches = matchedTracks.where((m) => m.isUncertain).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        GlassCard(
          radius: 14,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.source} Library',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              _statRow('Total tracks', '${r.totalTracks}', isDark),
              _statRow('Exact matches', '${r.exactMatches}', isDark,
                  color: Colors.greenAccent),
              _statRow('High matches', '${r.highMatches}', isDark,
                  color: Colors.cyanAccent),
              _statRow('Possible matches', '${r.mediumMatches}', isDark,
                  color: Colors.amber),
              _statRow('Weak matches', '${r.lowMatches}', isDark,
                  color: Colors.orangeAccent),
              _statRow('Not found', '${r.unmatched}', isDark,
                  color: Colors.redAccent),
              const Divider(height: 20),
              _statRow('Playlists imported', '${r.playlistsImported}', isDark),
              _statRow('Fully matched', '${r.playlistsFullyMatched}', isDark,
                  color: Colors.greenAccent),
              const SizedBox(height: 8),
              Text(
                'Match rate: ${(r.matchRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (uncertainMatches.isNotEmpty) ...[
          Text(
            'Possible Matches (Review)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...uncertainMatches.take(10).map(
                (m) => GlassCard(
                  radius: 10,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.imported.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              m.imported.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (m.matchedSong != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                m.matchedSong!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              Text(
                                '${(m.score * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _actionButton(
                'Cancel',
                isDark,
                onTap: onCancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                'Import Library',
                isDark,
                primary: true,
                onTap: onCommit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  static Widget _statRow(String label, String value, bool isDark,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? (isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _actionButton(String label, bool isDark,
      {bool primary = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: primary
              ? (isDark ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary
                ? Colors.transparent
                : (isDark ? Colors.white24 : Colors.black12),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
