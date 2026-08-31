import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (kIsWeb) return true;
    try {
      final statuses = await [
        Permission.audio,
        Permission.storage,
        Permission.microphone,
        Permission.notification,
      ].request();
      return statuses.values.any((s) => s.isGranted);
    } catch (_) {
      return false;
    }
  }
}
