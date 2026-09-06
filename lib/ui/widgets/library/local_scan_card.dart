import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/platform/noctra_capabilities.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../features/library/infrastructure/local_media_scanner.dart';
import '../../../shared/widgets/glass_card.dart';

class LocalScanCard extends StatefulWidget {
  final bool isDark;
  final MusicRepository repo;

  const LocalScanCard({
    super.key,
    required this.isDark,
    required this.repo,
  });

  @override
  State<LocalScanCard> createState() => _LocalScanCardState();
}

class _LocalScanCardState extends State<LocalScanCard> {
  bool _isScanning = false;

  Future<void> _startScan() async {
    HapticFeedback.mediumImpact();
    if (NoctraCapabilities.isAndroid) {
      try {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      } catch (_) {}
    }

    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Audio Folder to Scan',
      );

      if (selectedPath == null || selectedPath.isEmpty) return;

      if (!mounted) return;
      setState(() => _isScanning = true);

      final songs = await LocalMediaScanner.scanDirectory(selectedPath);

      if (songs.isNotEmpty) {
        const folderName = 'Local Audio';
        widget.repo.createFolder(folderName);
        for (final song in songs) {
          widget.repo.addSongToFolder(folderName, song);
        }
      }

      if (!mounted) return;
      setState(() => _isScanning = false);

      final msg = songs.isNotEmpty
          ? 'Imported ${songs.length} audio tracks to "Local Audio"'
          : 'No supported audio files found in selected folder';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scan folder: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 16,
      isHighlighted: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: _isScanning ? null : _startScan,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                  : const Color(0xFF007A87).withValues(alpha: 0.12),
            ),
            child: _isScanning
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF007A87),
                      ),
                    ),
                  )
                : Icon(
                    Icons.sd_storage_rounded,
                    size: 20,
                    color: widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF007A87),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isScanning ? 'Scanning Storage...' : 'Scan Local Device Storage',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  'Import FLAC, WAV, MP3, M4A directly',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: widget.isDark ? Colors.white38 : Colors.black38,
          ),
        ],
      ),
    );
  }
}
