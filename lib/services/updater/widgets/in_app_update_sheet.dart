import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/localization/localization_keys.dart';
import '../../../core/utils/localization/localization_scope.dart';
import '../app_update_service.dart';
import '../app_update_stager.dart';
import 'in_app_rollback_card.dart';
import 'in_app_update_cards.dart';

class InAppUpdateModalContent extends StatefulWidget {
  final AppUpdateInfo info;
  final bool isDark;

  const InAppUpdateModalContent({
    super.key,
    required this.info,
    required this.isDark,
  });

  @override
  State<InAppUpdateModalContent> createState() =>
      _InAppUpdateModalContentState();
}

class _InAppUpdateModalContentState extends State<InAppUpdateModalContent> {
  bool _isDownloading = false;
  double _progress = 0.0;
  double _downloadedMb = 0.0;
  double? _totalMb;
  String? _errorMessage;
  String? _stagedFilePath;

  Future<void> _startInAppUpdate() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _downloadedMb = 0.0;
      _totalMb = null;
      _errorMessage = null;
    });

    final filePath = await AppUpdateService.downloadAndVerifyApk(
      widget.info,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _downloadedMb = received / (1024 * 1024);
          if (total < 0) {
            _totalMb = null;
            _progress = (_progress + 0.04).clamp(0.0, 0.95);
          } else {
            _totalMb = total / (1024 * 1024);
            _progress = (received / total).clamp(0.0, 1.0);
          }
        });
      },
    );

    if (!mounted) return;

    if (filePath == null) {
      setState(() {
        _isDownloading = false;
        _errorMessage =
            'Update verification failed or download was blocked. Tap external download below.';
      });
      return;
    }

    final staged = await AppUpdateStager.stage(filePath);
    if (!staged) {
      try {
        final f = File(filePath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Update package verification failed. The update was not installed.';
        });
      }
      return;
    }

    setState(() {
      _isDownloading = false;
      _stagedFilePath = filePath;
    });
  }

  Future<void> _installStagedUpdate() async {
    final filePath = _stagedFilePath ?? AppUpdateStager.takeStagedPath();
    if (filePath == null) return;
    final ok = await AppUpdateService.notifyChannel
        .invokeMethod('installApk', {'filePath': filePath});

    if (ok != true && mounted) {
      setState(() {
        _errorMessage =
            'Could not trigger native installer. Tap external download below.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final info = widget.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            InAppUpdateHeaderRow(
              info: info,
              isDark: isDark,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            if (info.hasUpdate) ...[
              Text(
                context.tr(L10nKeys.releaseHighlights),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 8),
              InAppReleaseNotesCard(info: info, isDark: isDark),
              const SizedBox(height: 18),
              if (_stagedFilePath != null) ...[
                InAppReadyToInstallCard(
                  isDark: isDark,
                  onInstall: _installStagedUpdate,
                ),
              ],
              if (_isDownloading) ...[
                InAppDownloadingCard(
                  isDark: isDark,
                  progress: _progress,
                  downloadedMb: _downloadedMb,
                  totalMb: _totalMb,
                ),
              ] else if (_stagedFilePath == null) ...[
                InAppUpdateActionCard(
                  isDark: isDark,
                  errorMessage: _errorMessage,
                  onUpdate: _startInAppUpdate,
                  onExternal: () =>
                      launchExternalHttps(context, info.downloadUrl),
                ),
              ],
            ] else ...[
              InAppUpToDateCard(info: info, isDark: isDark),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 14),
            InAppRollbackCard(
              currentVersion: info.currentVersion,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}
