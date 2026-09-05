import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/song_model.dart';
import '../../services/platform/story_card_exporter.dart';
import 'story_card_render_view.dart';

class ShareStoryCardSheet extends ConsumerStatefulWidget {
  final Song song;
  final String? lyricsSnippet;

  const ShareStoryCardSheet({
    super.key,
    required this.song,
    this.lyricsSnippet,
  });

  @override
  ConsumerState<ShareStoryCardSheet> createState() =>
      _ShareStoryCardSheetState();
}

class _ShareStoryCardSheetState extends ConsumerState<ShareStoryCardSheet> {
  final GlobalKey _boundaryKey = GlobalKey();
  int _selectedThemeIndex = 0;
  bool _isExporting = false;

  Future<void> _handleShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      await StoryCardExporter.shareStoryImage(
        bytes: pngBytes,
        title: widget.song.title,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeTheme = kStoryThemes[_selectedThemeIndex];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    'SHARE STORY CARD',
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
              const SizedBox(height: 12),

              // Card Preview Render Object
              Center(
                child: StoryCardRenderView(
                  boundaryKey: _boundaryKey,
                  song: widget.song,
                  theme: activeTheme,
                  lyricsSnippet: widget.lyricsSnippet,
                ),
              ),
              const SizedBox(height: 20),

              // Theme Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(kStoryThemes.length, (idx) {
                  final isSelected = _selectedThemeIndex == idx;
                  final theme = kStoryThemes[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(theme.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedThemeIndex = idx);
                        }
                      },
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Share Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.share_rounded, size: 18),
                  label: Text(
                    _isExporting ? 'Exporting...' : 'Share to Stories / Chats',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: _isExporting ? null : _handleShare,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
