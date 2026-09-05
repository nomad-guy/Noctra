import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/migration/importers/url_playlist_importer.dart';
import '../../../shared/widgets/glass_card.dart';

class UrlImportSheet extends ConsumerStatefulWidget {
  final bool isDark;

  const UrlImportSheet({super.key, required this.isDark});

  static void show(BuildContext context, bool isDark) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UrlImportSheet(isDark: isDark),
    );
  }

  @override
  ConsumerState<UrlImportSheet> createState() => _UrlImportSheetState();
}

class _UrlImportSheetState extends ConsumerState<UrlImportSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(musicRepositoryProvider);
      final isUrl = UrlPlaylistImporter.isPlaylistUrl(input);

      final playlist = isUrl
          ? await UrlPlaylistImporter.importFromUrl(input)
          : UrlPlaylistImporter.importFromTracklistText(input);

      if (playlist == null || playlist.tracks.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMsg =
                'Could not extract tracks. Check the link or tracklist format.';
          });
        }
        return;
      }

      // Create folder and add songs
      final folderName = playlist.name.isNotEmpty
          ? playlist.name
          : 'Imported Playlist';
      repo.createFolder(folderName);

      for (int i = 0; i < playlist.tracks.length; i++) {
        final t = playlist.tracks[i];
        final id =
            'import_${t.title.toLowerCase().hashCode}_${t.artist.toLowerCase().hashCode}_$i';
        final song = Song(
          id: id,
          title: t.title,
          artist: t.artist,
          album: folderName,
          duration: t.duration ?? const Duration(seconds: 210),
          genre: playlist.source,
        );
        repo.addSongToFolder(folderName, song);
      }

      HapticFeedback.lightImpact();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${playlist.tracks.length} tracks to folder "$folderName"',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Import failed. Please verify your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'IMPORT PLAYLIST LINK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isDark ? Colors.white60 : Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                'Paste any public Spotify or YouTube playlist URL, or paste lines of "Song - Artist" tracks to import directly into Noctra.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),

              // URL / Text Input
              GlassCard(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'https://open.spotify.com/playlist/...\nhttps://www.youtube.com/playlist?list=...\nor Song - Artist list',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white30 : Colors.black38,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ),

              // Import Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _isLoading ? 'Resolving Playlist...' : 'Import to Library',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: _isLoading ? null : _handleImport,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
