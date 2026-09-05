import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/glass_card.dart';
import '../app_update_service.dart';

/// Header row of the update sheet: icon, title/subtitle and close button.
class InAppUpdateHeaderRow extends StatelessWidget {
  final AppUpdateInfo info;
  final bool isDark;
  final VoidCallback onClose;

  const InAppUpdateHeaderRow({
    super.key,
    required this.info,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                  size: 20, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.hasUpdate ? 'New Version Available' : 'App is Up to Date',
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
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// Release-notes card shown when an update is available.
class InAppReleaseNotesCard extends StatelessWidget {
  final AppUpdateInfo info;
  final bool isDark;

  const InAppReleaseNotesCard({super.key, required this.info, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
    );
  }
}

/// Card confirming a verified, staged update is ready to install.
class InAppReadyToInstallCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onInstall;

  const InAppReadyToInstallCard({
    super.key,
    required this.isDark,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          radius: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.verified_rounded,
                  color: Colors.greenAccent.shade400, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update downloaded and verified. Install when you are ready.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Restart & Update'),
          onPressed: onInstall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Downloading progress (indeterminate or determinate) with MB counter.
class InAppDownloadingCard extends StatelessWidget {
  final bool isDark;
  final double progress;
  final double downloadedMb;
  final double? totalMb;

  const InAppDownloadingCard({
    super.key,
    required this.isDark,
    required this.progress,
    required this.downloadedMb,
    this.totalMb,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress : null,
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
              progress >= 1.0
                  ? 'Launching system installer...'
                  : 'Downloading update (${(progress * 100).toInt()}%)',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87),
            ),
            Text(
              totalMb == null
                  ? '${downloadedMb.toStringAsFixed(1)} MB'
                  : '${downloadedMb.toStringAsFixed(1)} MB / ${totalMb!.toStringAsFixed(1)} MB',
              style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// Primary update CTA: error message, in-app download button and the
/// external-browser fallback.
class InAppUpdateActionCard extends StatelessWidget {
  final bool isDark;
  final String? errorMessage;
  final VoidCallback onUpdate;
  final VoidCallback onExternal;

  const InAppUpdateActionCard({
    super.key,
    required this.isDark,
    required this.errorMessage,
    required this.onUpdate,
    required this.onExternal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.flash_on_rounded, size: 18),
          label: const Text('Update Now (Direct In-App)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          onPressed: onUpdate,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.open_in_browser_rounded, size: 14),
            label: const Text('Or download APK from browser',
                style: TextStyle(fontSize: 11.5)),
            onPressed: onExternal,
          ),
        ),
      ],
    );
  }
}

/// "Up to date" confirmation card (no update path).
class InAppUpToDateCard extends StatelessWidget {
  final AppUpdateInfo info;
  final bool isDark;

  const InAppUpToDateCard({super.key, required this.info, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
    );
  }
}

/// Opens [url] in the external browser when it is a safe https link.
Future<void> launchExternalHttps(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (uri.scheme == 'https' && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  if (context.mounted) Navigator.of(context).pop();
}
