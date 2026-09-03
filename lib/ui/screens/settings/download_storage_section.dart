import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/noir_theme.dart';
import '../../../data/models/download_location.dart';
import '../../../data/sources/noctra_local_database.dart';
import '../../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

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
                    NoctraLocalDatabase().saveDownloadLocation(val);
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

    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        if (context.mounted) {
          sm.showSnackBar(SnackBar(
            content: const Text(
                'Storage permission required. Please enable it in Settings.'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
          ));
        }
        return;
      }

      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        final fallback = await Permission.storage.request();
        if (!fallback.isGranted) {
          if (context.mounted) {
            sm.showSnackBar(SnackBar(
              content: const Text(
                  'Storage permission is needed to save songs to a custom folder.'),
              action: SnackBarAction(
                label: 'Grant Access',
                onPressed: () => openAppSettings(),
              ),
            ));
          }
          return;
        }
      }
    }

    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select download folder for Noctra',
      );

      if (result != null && result.isNotEmpty) {
        final dir = Directory(result);
        if (!dir.existsSync()) {
          try {
            dir.createSync(recursive: true);
          } catch (e) {
            if (context.mounted) {
              sm.showSnackBar(SnackBar(
                content: Text('Cannot create folder: $e'),
              ));
            }
            return;
          }
        }

        final testFile = File('$result/.noctra_write_test');
        try {
          await testFile.writeAsString('test');
          await testFile.delete();
        } catch (e) {
          if (context.mounted) {
            sm.showSnackBar(SnackBar(
              content: const Text(
                  'Cannot write to this folder. Choose a different location.'),
            ));
          }
          return;
        }

        final customKey = 'custom:$result';
        NoctraLocalDatabase().saveDownloadLocation(customKey);
        ref.read(downloadLocationProvider.notifier).state = customKey;

        if (context.mounted) {
          sm.showSnackBar(SnackBar(
            content: Text('Download folder set to: $result'),
            duration: const Duration(seconds: 3),
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        sm.showSnackBar(SnackBar(
          content: Text('Folder picker error: $e'),
        ));
      }
    }
  }
}
