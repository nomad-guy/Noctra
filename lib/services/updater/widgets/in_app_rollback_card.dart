import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/glass_card.dart';
import '../app_update_rollback_service.dart';
import '../app_update_service.dart';
import '../app_update_stager.dart';

/// Card allowing users to view earlier stable releases and roll back.
class InAppRollbackCard extends StatefulWidget {
  final String currentVersion;
  final bool isDark;

  const InAppRollbackCard({
    super.key,
    required this.currentVersion,
    required this.isDark,
  });

  @override
  State<InAppRollbackCard> createState() => _InAppRollbackCardState();
}

class _InAppRollbackCardState extends State<InAppRollbackCard> {
  bool _isLoading = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _downloadingTag;
  String? _statusMessage;
  List<AvailableRelease> _releases = [];
  bool _hasFetched = false;

  Future<void> _fetchReleases() async {
    setState(() => _isLoading = true);
    final list = await AppUpdateRollbackService.fetchAvailableReleases(
      currentVersion: widget.currentVersion,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasFetched = true;
        _releases = list;
      });
    }
  }

  void _confirmAndRollback(AvailableRelease release) {
    HapticFeedback.mediumImpact();
    AppUpdateRollbackService.showRollbackDialog(
      context,
      release,
      isDark: widget.isDark,
      onConfirm: () => _startRollbackDownload(release),
    );
  }

  Future<void> _startRollbackDownload(AvailableRelease release) async {
    setState(() {
      _isDownloading = true;
      _downloadingTag = release.tag;
      _progress = 0.0;
      _statusMessage = null;
    });

    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: widget.currentVersion,
      latestVersion: release.version,
      releaseNotes: release.releaseNotes,
      downloadUrl: release.downloadUrl,
      expectedSha256: release.expectedSha256,
    );

    final filePath = await AppUpdateService.downloadAndVerifyApk(
      info,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.5;
        });
      },
    );

    if (!mounted) return;

    if (filePath == null) {
      setState(() {
        _isDownloading = false;
        _downloadingTag = null;
        _statusMessage = 'Rollback verification or download failed.';
      });
      return;
    }

    final staged = await AppUpdateStager.stage(filePath);
    if (!staged) {
      setState(() {
        _isDownloading = false;
        _downloadingTag = null;
        _statusMessage = 'Package staging failed.';
      });
      return;
    }

    setState(() {
      _isDownloading = false;
      _statusMessage = 'Triggering installer for ${release.tag}...';
    });

    final ok = await AppUpdateService.notifyChannel
        .invokeMethod('installApk', {'filePath': filePath});

    if (ok != true && mounted) {
      setState(() {
        _statusMessage =
            'Installer launch blocked. The APK is saved in Downloads.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final olderReleases = _releases.where((r) => r.isOlder).toList();

    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18,
                      color: widget.isDark ? Colors.white70 : Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    'Version Rollback',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              if (!_hasFetched && !_isLoading)
                TextButton(
                  onPressed: _fetchReleases,
                  child: const Text('Check Earlier Versions',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                )
              else if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 12),
            Text('Downloading ${_downloadingTag ?? "older version"}...',
                style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor:
                    widget.isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 11.5,
                color: widget.isDark ? Colors.amberAccent : Colors.deepOrange,
              ),
            ),
          ],
          if (_hasFetched && olderReleases.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No earlier releases available to rollback to.',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
          if (olderReleases.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...olderReleases.map((rel) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rel.tag,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (rel.publishedAt.isNotEmpty)
                          Text(
                            rel.publishedAt,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: widget.isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        side: BorderSide(
                            color: widget.isDark
                                ? Colors.white24
                                : Colors.black26),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.restore_rounded, size: 14),
                      label: const Text('Rollback',
                          style: TextStyle(fontSize: 11.5)),
                      onPressed:
                          _isDownloading ? null : () => _confirmAndRollback(rel),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
