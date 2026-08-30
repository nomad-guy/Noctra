import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (kIsWeb) return true;
    try {
      final audioStatus = await Permission.audio.status;
      if (!audioStatus.isGranted) {
        await Permission.audio.request();
      }

      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        await Permission.storage.request();
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
