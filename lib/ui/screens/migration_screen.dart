import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/noir_theme.dart';
import '../../providers/app_providers.dart';
import '../../data/models/migration_models.dart';
import '../../services/migration/library_importers.dart';
import '../../services/migration/migration_manager.dart';
import '../../services/migration/track_matcher.dart';
import 'migration/migration_choose_view.dart';
import 'migration/migration_preview_view.dart';
import 'migration/migration_status_views.dart';

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

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode.isDark;
    final tokens = context.noctraTokens;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: themeMode.isLiquidGlass
            ? tokens.surface.withValues(alpha: .90)
            : (isDark ? const Color(0xF6070707) : const Color(0xF6FAFAFA)),
        gradient: themeMode.isLiquidGlass
            ? LinearGradient(colors: [
                tokens.surfaceVariant.withValues(alpha: .92),
                tokens.canvas.withValues(alpha: .88)
              ])
            : null,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: tokens.subtleBorder),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _step == MigrationStep.choose
                        ? 'Import Music Library'
                        : _step == MigrationStep.loading
                            ? 'Analyzing...'
                            : _step == MigrationStep.preview
                                ? 'Migration Preview'
                                : 'Import Complete',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
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
      case MigrationStep.choose:
        return MigrationChooseView(
          isDark: isDark,
          onSelectSource: _selectSource,
        );
      case MigrationStep.loading:
        return MigrationLoadingView(
          isDark: isDark,
          status: _status,
        );
      case MigrationStep.preview:
        return _report == null
            ? const SizedBox.shrink()
            : MigrationPreviewView(
                report: _report!,
                matchedTracks: _matchedTracks,
                isDark: isDark,
                onCancel: () => setState(() => _step = MigrationStep.choose),
                onCommit: _commitImport,
              );
      case MigrationStep.complete:
        return MigrationCompleteView(
          isDark: isDark,
          matchedCount: _matchedTracks.where((m) => m.isMatched).length,
          onDone: () => Navigator.of(context).pop(),
        );
    }
  }

  void _selectSource(String sourceName) async {
    final importer = getAllImporters().firstWhere(
      (i) =>
          i.sourceName == sourceName ||
          (sourceName.contains('Other') && i.sourceName.contains('CSV')),
      orElse: () => GenericCSVImporter(),
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import library export'),
          content: Text(
            'Select a compatible ${importer.supportedExtensions.join(', ')} export file. Your music metadata stays on this device while it is matched.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickFile(importer);
              },
              child: const Text('Select File'),
            ),
          ],
        ),
      );
    }
  }

  void _pickFile(LibraryImporter importer) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: importer.supportedExtensions
          .map((e) => e.replaceFirst('.', ''))
          .toList(),
    );
    if (!mounted || files.isEmpty) return;

    setState(() {
      _step = MigrationStep.loading;
      _status = 'Parsing ${files.first.name}...';
    });

    try {
      final report =
          await MigrationManager.processImportPath(importer, files.first.path!);
      if (!mounted) return;
      _report = report;
      _matchedTracks = report.matchedTracks;
      setState(() => _step = MigrationStep.preview);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = MigrationStep.choose;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _commitImport() async {
    try {
      await MigrationManager.commitImport(_matchedTracks, addToFavorites: true);
      if (mounted) {
        setState(() => _step = MigrationStep.complete);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Import error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import library: $e')),
        );
      }
    }
  }
}
