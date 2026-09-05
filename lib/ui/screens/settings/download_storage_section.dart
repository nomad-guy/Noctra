import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../data/models/download_location.dart';
import '../../../providers/app_providers.dart';
import '../../../services/platform/download_folder_service.dart';
import '../../../shared/widgets/glass_card.dart';

class DownloadStorageSection extends ConsumerWidget {
  final bool isDark;

  const DownloadStorageSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.noctraTokens;
    final downloadLoc = ref.watch(downloadLocationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOCAL STORAGE FOR DOWNLOADS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose where downloaded songs are stored.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              if (downloadLoc.startsWith('custom:'))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_open_rounded,
                          size: 16, color: tokens.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          downloadLoc.substring(7),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tokens.primaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: downloadLoc.startsWith('custom:')
                    ? DownloadLocation.custom
                    : downloadLoc,
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black,
                ),
                items: DownloadLocation.all
                    .map((loc) => DropdownMenuItem<String>(
                          value: loc.key,
                          child: Text(loc.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  if (val == DownloadLocation.custom) {
                    _pickCustomFolder(context, ref);
                  } else {
                    ref.read(musicRepositoryProvider).saveDownloadLocation(val);
                    ref.read(downloadLocationProvider.notifier).state = val;
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                downloadLoc.startsWith('custom:')
                    ? 'Custom folder selected. Songs will be saved here.'
                    : DownloadLocation.byKey(downloadLoc).description,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustomFolder(BuildContext context, WidgetRef ref) async {
    final sm = ScaffoldMessenger.of(context);
    final result = await DownloadFolderService.pick();
    if (!context.mounted) return;

    switch (result.outcome) {
      case DownloadFolderPick.cancelled:
        return;
      case DownloadFolderPick.permissionPermanentlyDenied:
        sm.showSnackBar(SnackBar(
          content: const Text(
              'Storage permission required. Please enable it in Settings.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: DownloadFolderService.openSettings,
          ),
        ));
        return;
      case DownloadFolderPick.permissionDenied:
        sm.showSnackBar(SnackBar(
          content: const Text(
              'Storage permission is needed to save songs to a custom folder.'),
          action: SnackBarAction(
            label: 'Grant Access',
            onPressed: DownloadFolderService.openSettings,
          ),
        ));
        return;
      case DownloadFolderPick.notWritable:
        sm.showSnackBar(SnackBar(
          content: Text(result.error ??
              'Cannot write to this folder. Choose a different location.'),
        ));
        return;
      case DownloadFolderPick.pickerFailed:
        sm.showSnackBar(SnackBar(
          content: Text('Folder picker error: ${result.error ?? ''}'),
        ));
        return;
      case DownloadFolderPick.picked:
        final customKey = result.path!;
        final displayPath =
            customKey.substring(DownloadFolderService.customPrefix.length);
        ref.read(musicRepositoryProvider).saveDownloadLocation(customKey);
        ref.read(downloadLocationProvider.notifier).state = customKey;
        sm.showSnackBar(SnackBar(
          content: Text('Download folder set to: $displayPath'),
          duration: const Duration(seconds: 3),
        ));
    }
  }
}
