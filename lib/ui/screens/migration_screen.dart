import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/noir_theme.dart';
import '../../data/models/migration_models.dart';
import '../../providers/app_providers.dart';
import '../../services/migration/library_importers.dart';
import '../../services/migration/track_matcher.dart';
import '../widgets/glass_card.dart';

class MigrationScreen extends ConsumerStatefulWidget {
  const MigrationScreen({super.key});
  @override
  ConsumerState<MigrationScreen> createState() => _MigrationScreenState();
}

enum MigrationStep { choose, loading, preview, complete }

class _MigrationScreenState extends ConsumerState<MigrationScreen> {
  MigrationStep _step = MigrationStep.choose;
  MigrationReport? _report;
  List<MatchedTrack> _matchedTracks = [];
  String _status = '';

  final List<Map<String, dynamic>> _sources = [
    {'name': 'Spotify', 'icon': Icons.music_note, 'color': const Color(0xFF1DB954)},
    {'name': 'Apple Music', 'icon': Icons.apple, 'color': const Color(0xFFFA2D48)},
    {'name': 'YouTube Music', 'icon': Icons.play_arrow_rounded, 'color': const Color(0xFFFF0000)},
    {'name': 'JioSaavn', 'icon': Icons.waves_rounded, 'color': const Color(0xFF2BC5F3)},
    {'name': 'Other (CSV, M3U, JSON)', 'icon': Icons.file_open_rounded, 'color': Colors.white54},
  ];

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF6070707) : const Color(0xF6FAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle
            Center(child: Container(
              width: 44, height: 4.5,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _step == MigrationStep.choose ? 'Import Music Library' :
                    _step == MigrationStep.loading ? 'Analyzing...' :
                    _step == MigrationStep.preview ? 'Migration Preview' : 'Import Complete',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_step) {
      case MigrationStep.choose: return _buildChooseStep(isDark);
      case MigrationStep.loading: return _buildLoadingStep(isDark);
      case MigrationStep.preview: return _buildPreviewStep(isDark);
      case MigrationStep.complete: return _buildCompleteStep(isDark);
    }
  }

  Widget _buildChooseStep(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Text(
          'Bring your playlists and listening history from other music services without connecting your accounts.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 20),
        ..._sources.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _selectSource(s['name'] as String),
            child: GlassCard(
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: (s['color'] as Color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(s['name'] as String,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black))),
                  Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
                ],
              ),
            ),
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLoadingStep(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white : Colors.black),
          const SizedBox(height: 16),
          Text(_status, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(bool isDark) {
    if (_report == null) return const SizedBox.shrink();
    final r = _report!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        GlassCard(
          radius: 14,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.source} Library', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 12),
              _statRow('Total tracks', '${r.totalTracks}', isDark),
              _statRow('Exact matches', '${r.exactMatches}', isDark, color: Colors.greenAccent),
              _statRow('High matches', '${r.highMatches}', isDark, color: Colors.cyanAccent),
              _statRow('Possible matches', '${r.mediumMatches}', isDark, color: Colors.amber),
              _statRow('Weak matches', '${r.lowMatches}', isDark, color: Colors.orangeAccent),
              _statRow('Not found', '${r.unmatched}', isDark, color: Colors.redAccent),
              const Divider(height: 20),
              _statRow('Playlists imported', '${r.playlistsImported}', isDark),
              _statRow('Fully matched', '${r.playlistsFullyMatched}', isDark, color: Colors.greenAccent),
              const SizedBox(height: 8),
              Text('Match rate: ${(r.matchRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Show uncertain matches for review
        if (_matchedTracks.where((m) => m.isUncertain).isNotEmpty) ...[
          Text('Possible Matches (Review)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          ..._matchedTracks.where((m) => m.isUncertain).take(10).map((m) =>
            GlassCard(radius: 10, padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.imported.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black)),
                    Text(m.imported.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                )),
                if (m.matchedSong != null)
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(m.matchedSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
                      Text('${(m.score * 100).toInt()}%', style: TextStyle(fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  )),
              ]),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(child: _actionButton('Cancel', isDark, onTap: () => setState(() => _step = MigrationStep.choose))),
            const SizedBox(width: 12),
            Expanded(child: _actionButton('Import Library', isDark, primary: true, onTap: _commitImport)),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCompleteStep(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 56, color: Colors.greenAccent),
          const SizedBox(height: 16),
          Text('Library Imported', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          Text('${_matchedTracks.where((m) => m.isMatched).length} tracks added to your library',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(height: 24),
          _actionButton('Done', isDark, primary: true, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, bool isDark, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: color ?? (isDark ? Colors.white : Colors.black))),
        ],
      ),
    );
  }

  Widget _actionButton(String label, bool isDark, {bool primary = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: primary ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary ? Colors.transparent : (isDark ? Colors.white24 : Colors.black12)),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: primary ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87)))),
      ),
    );
  }

  void _selectSource(String sourceName) async {
    // Find matching importer
    final importer = getAllImporters().firstWhere(
      (i) => i.sourceName == sourceName || (sourceName.contains('Other') && i.sourceName.contains('CSV')),
      orElse: () => GenericCSVImporter(),
    );

    // Show instructions
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Import from ${importer.sourceName}'),
          content: SingleChildScrollView(child: Text(importer.getInstructions())),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(onPressed: () { Navigator.of(ctx).pop(); _pickFile(importer); }, child: const Text('Select File')),
          ],
        ),
      );
    }
  }

  void _pickFile(LibraryImporter importer) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: importer.supportedExtensions.map((e) => e.replaceFirst('.', '')).toList(),
    );
    if (files.isEmpty) return;

    setState(() {
      _step = MigrationStep.loading;
      _status = 'Parsing ${files.first.name}...';
    });

    try {
      final file = File(files.first.path!);
      final report = await MigrationManager.processImport(importer, file);
      _report = report;
      _matchedTracks = report.matchedTracks;
      setState(() => _step = MigrationStep.preview);
    } catch (e) {
      setState(() {
        _step = MigrationStep.choose;
        _status = 'Error: $e';
      });
    }
  }

  void _commitImport() {
    MigrationManager.commitImport(_matchedTracks, addToFavorites: true);
    setState(() => _step = MigrationStep.complete);
  }
}
