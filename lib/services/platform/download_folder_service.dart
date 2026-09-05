import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/noctra_capabilities.dart';

/// Outcome of a custom download-folder pick, so the UI only maps results to
/// messages without touching platform APIs.
enum DownloadFolderPick {
  picked,
  cancelled,
  permissionPermanentlyDenied,
  permissionDenied,
  notWritable,
  pickerFailed,
}

/// Result carrying the chosen absolute path (custom: prefix applied by caller).
class DownloadFolderPickResult {
  final DownloadFolderPick outcome;
  final String? path;
  final String? error;

  const DownloadFolderPickResult(this.outcome, {this.path, this.error});
}

/// Platform boundary for choosing a custom download folder.
///
/// Owns the Android storage-permission dance, the native folder picker and the
/// write probe. Widgets call [pick] and render the outcome; they never import
/// `permission_handler`, `file_picker` or `dart:io` themselves.
class DownloadFolderService {
  DownloadFolderService._();

  static const String customPrefix = 'custom:';

  static Future<DownloadFolderPickResult> pick() async {
    if (NoctraCapabilities.isAndroid) {
      final outcome = await _ensureAndroidPermission();
      if (outcome != null) return outcome;
    }

    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select download folder for Noctra',
      );
      if (result == null || result.isEmpty) {
        return const DownloadFolderPickResult(DownloadFolderPick.cancelled);
      }
      final dir = Directory(result);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (e) {
          return DownloadFolderPickResult(
              DownloadFolderPick.notWritable,
              error: 'Cannot create folder: $e');
        }
      }
      final testFile = File('$result/.noctra_write_test');
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        return DownloadFolderPickResult(
            DownloadFolderPick.notWritable,
            error: 'Cannot write to folder: $e');
      }
      return DownloadFolderPickResult(DownloadFolderPick.picked,
          path: '$customPrefix$result');
    } catch (e) {
      return DownloadFolderPickResult(DownloadFolderPick.pickerFailed,
          error: '$e');
    }
  }

  /// Opens the OS settings for the storage permission (Android).
  static Future<void> openSettings() => openAppSettings();

  static Future<DownloadFolderPickResult?> _ensureAndroidPermission() async {
    try {
      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        return const DownloadFolderPickResult(
            DownloadFolderPick.permissionPermanentlyDenied);
      }
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return null;
      final fallback = await Permission.storage.request();
      if (fallback.isGranted) return null;
      return const DownloadFolderPickResult(DownloadFolderPick.permissionDenied);
    } catch (_) {
      return const DownloadFolderPickResult(DownloadFolderPick.permissionDenied);
    }
  }
}
