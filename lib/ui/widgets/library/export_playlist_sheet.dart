import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/song_model.dart';
import '../../../services/migration/noctra_transfer_service.dart';

/// Bottom sheet dialog for exporting a playlist or collection to JSON/CSV.
class ExportPlaylistSheet extends StatelessWidget {
  final String playlistTitle;
  final List<Song> tracks;
  final bool isDark;

  const ExportPlaylistSheet({
    super.key,
    required this.playlistTitle,
    required this.tracks,
    required this.isDark,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<Song> tracks,
    required bool isDark,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportPlaylistSheet(
        playlistTitle: title,
        tracks: tracks,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white54 : Colors.black54;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141419) : const Color(0xFFF7F7FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Transfer Playlist',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"$playlistTitle" (${tracks.length} tracks)',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),
              _exportOption(
                context,
                title: 'Noctra Manifest JSON',
                subtitle: 'Full fidelity format with artworks, tags, and IDs.',
                icon: Icons.data_object_rounded,
                onSave: () async {
                  final json = NoctraTransferService.exportPlaylistToJson(
                    playlistTitle,
                    tracks,
                  );
                  final path = await NoctraTransferService.saveManifestToFile(
                    playlistTitle,
                    json,
                    extension: 'noctra.json',
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _notify(context, 'Exported to $path');
                  }
                },
                onCopy: () async {
                  final json = NoctraTransferService.exportPlaylistToJson(
                    playlistTitle,
                    tracks,
                  );
                  await NoctraTransferService.copyToClipboard(json);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _notify(context, 'Copied JSON manifest to clipboard');
                  }
                },
              ),
              const SizedBox(height: 12),
              _exportOption(
                context,
                title: 'Universal CSV',
                subtitle: 'Compatible with Spotify, Apple Music & spreadsheet tools.',
                icon: Icons.table_chart_rounded,
                onSave: () async {
                  final csv = NoctraTransferService.exportPlaylistToCsv(
                    playlistTitle,
                    tracks,
                  );
                  final path = await NoctraTransferService.saveManifestToFile(
                    playlistTitle,
                    csv,
                    extension: 'csv',
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _notify(context, 'Exported to $path');
                  }
                },
                onCopy: () async {
                  final csv = NoctraTransferService.exportPlaylistToCsv(
                    playlistTitle,
                    tracks,
                  );
                  await NoctraTransferService.copyToClipboard(csv);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _notify(context, 'Copied CSV to clipboard');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onSave,
    required VoidCallback onCopy,
  }) {
    final cardColor =
        isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final borderColor =
        isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Save File', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Text', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _notify(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
