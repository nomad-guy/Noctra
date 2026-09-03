import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../ui/widgets/glass_card.dart';
import '../app_update_service.dart';
import '../app_update_verifier.dart';

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

    final verified =
        await AppUpdateVerifier.isVerifiedInstallCandidate(filePath);
    if (!verified) {
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

    final ok = await AppUpdateService.notifyChannel
        .invokeMethod('installApk', {'filePath': filePath});

    if (ok != true && mounted) {
      setState(() {
        _isDownloading = false;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      child: Icon(Icons.system_update_rounded,
                          size: 20,
                          color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.hasUpdate
                              ? 'New Version Available'
                              : 'App is Up to Date',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black),
                        ),
                        Text(
                          'Installed: ${info.currentVersion} • Latest: ${info.latestVersion}',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (info.hasUpdate) ...[
              Text(
                'RELEASE HIGHLIGHTS',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 8),
              GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(14),
                child: Text(
                  info.releaseNotes.isNotEmpty
                      ? info.releaseNotes
                      : 'Performance optimizations and UI enhancements.',
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(height: 18),
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progress >= 1.0
                          ? 'Launching system installer...'
                          : 'Downloading update (${(_progress * 100).toInt()}%)',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    Text(
                      _totalMb == null
                          ? '${_downloadedMb.toStringAsFixed(1)} MB'
                          : '${_downloadedMb.toStringAsFixed(1)} MB / ${_totalMb!.toStringAsFixed(1)} MB',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else ...[
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.redAccent)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('Update Now (Direct In-App)',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    onPressed: _startInAppUpdate,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                    label: const Text('Or download APK from browser',
                        style: TextStyle(fontSize: 11.5)),
                    onPressed: () async {
                      final uri = Uri.parse(info.downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ] else ...[
              GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent.shade400, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are running the latest official build of Noctra (${info.currentVersion}).',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
