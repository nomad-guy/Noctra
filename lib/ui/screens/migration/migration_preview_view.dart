import 'package:flutter/material.dart';
import '../../../data/models/migration_models.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/noir_theme.dart';

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
    final t = context.noctraTokens;
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
                  color: t.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              _statRow(t, 'Total tracks', '${r.totalTracks}'),
              _statRow(t, 'Exact matches', '${r.exactMatches}',
                  color: Colors.greenAccent),
              _statRow(t, 'High matches', '${r.highMatches}',
                  color: Colors.cyanAccent),
              _statRow(t, 'Possible matches', '${r.mediumMatches}',
                  color: Colors.amber),
              _statRow(t, 'Weak matches', '${r.lowMatches}',
                  color: Colors.orangeAccent),
              _statRow(t, 'Not found', '${r.unmatched}',
                  color: Colors.redAccent),
              const Divider(height: 20),
              _statRow(t, 'Playlists imported', '${r.playlistsImported}'),
              _statRow(t, 'Fully matched', '${r.playlistsFullyMatched}',
                  color: Colors.greenAccent),
              const SizedBox(height: 8),
              Text(
                'Match rate: ${(r.matchRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.secondaryText,
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
              color: t.secondaryText,
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
                                color: t.primaryText,
                              ),
                            ),
                            Text(
                              m.imported.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: t.secondaryText,
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
                                      t.tertiaryText,
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
                t,
                'Cancel',
                onTap: onCancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                t,
                'Import Library',
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

  static Widget _statRow(NoctraThemeTokens t, String label, String value,
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
              color: t.secondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? (t.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _actionButton(NoctraThemeTokens t, String label,
      {bool primary = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: primary
              ? (t.primaryText)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary
                ? Colors.transparent
                : t.subtleBorder,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary
                  ? (t.primaryText)
                  : (t.secondaryText),
            ),
          ),
        ),
      ),
    );
  }
}
