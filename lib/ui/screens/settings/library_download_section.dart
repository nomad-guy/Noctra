import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';

import '../../../providers/app_providers.dart';
import '../../../services/library/library_bulk_download_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/theme/noir_theme.dart';

/// Settings > Local Storage: "Download full library" control with live
/// progress. Downloads every library track that isn't already on disk.
class LibraryDownloadSection extends ConsumerStatefulWidget {
  final bool isDark;

  const LibraryDownloadSection({super.key, required this.isDark});

  @override
  ConsumerState<LibraryDownloadSection> createState() =>
      _LibraryDownloadSectionState();
}

class _LibraryDownloadSectionState
    extends ConsumerState<LibraryDownloadSection> {
  static final LibraryBulkDownloadService _bulk =
      LibraryBulkDownloadService.instance;

  void _startDownload() {
    final repo = ref.read(musicRepositoryProvider);
    final pending = repo.localLibrary
        .where((s) => !repo.isDownloaded(s.id))
        .toList(growable: false);
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your library is already fully downloaded')),
      );
      return;
    }
    final started = _bulk.start(pending);
    if (started) {
      _showProgressDialog();
    }
  }

  void _showProgressDialog() {
    final t = context.noctraTokens;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Auto-close the dialog once the run finishes (completed, failed-out
        // or stopped). Previously the dialog lingered until manually popped
        // even when the service had finished all tracks.
        var autoClosed = false;
        void closeIfFinished() {
          if (autoClosed || _bulk.isRunning) return;
          autoClosed = true;
          // Popping during build is illegal — defer to after the frame.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          });
        }

        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor:
                widget.isDark ? const Color(0xFF161616) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Downloading Library',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: t.primaryText,
              ),
            ),
            content: AnimatedBuilder(
              animation: _bulk,
              builder: (context, _) {
                final t = context.noctraTokens;
                closeIfFinished();
                final pct =
                    _bulk.total == 0 ? 0.0 : _bulk.completed / _bulk.total;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: widget.isDark
                            ? Colors.white12
                            : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          t.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_bulk.completed + _bulk.failed} / ${_bulk.total}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.primaryText,
                      ),
                    ),
                    if (_bulk.currentTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _bulk.currentTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color:
                              t.secondaryText,
                        ),
                      ),
                    ],
                    if (_bulk.failed > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_bulk.failed} failed (will keep your library clean)',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFFFFB74D),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _bulk.cancel();
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  'Stop',
                  style: TextStyle(
                    color: t.primaryText,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.noctraTokens;
    final repo = ref.watch(musicRepositoryProvider);
    final total = repo.localLibrary.length;
    final downloaded =
        repo.localLibrary.where((s) => repo.isDownloaded(s.id)).length;
    final remaining = total - downloaded;
    final allDownloaded = total > 0 && remaining == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OFFLINE LIBRARY',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: t.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.download_for_offline_rounded,
                      size: 18,
                      color: t.secondaryText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Full Library',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          allDownloaded
                              ? 'All $total songs saved offline'
                              : '$downloaded of $total songs saved offline'
                                  '${remaining > 0 ? ' • $remaining remaining' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: t.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(
                        color: (t.primaryText)
                            .withValues(alpha: .25)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    allDownloaded
                        ? Icons.check_circle_outline_rounded
                        : Icons.download_rounded,
                    size: 16,
                    color: t.primaryText,
                  ),
                  label: Text(
                    allDownloaded
                        ? 'Everything downloaded'
                        : 'Download all $remaining remaining songs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.primaryText,
                    ),
                  ),
                  onPressed:
                      (_bulk.isRunning || allDownloaded || total == 0)
                          ? null
                          : _startDownload,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
