import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (kIsWeb) return true;
    try {
      // Android 11+ needs MANAGE_EXTERNAL_STORAGE for custom folders
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return true;

      final statuses = await [
        Permission.audio,
        Permission.storage,
        Permission.notification,
      ].request();
      final audioGranted = statuses[Permission.audio]?.isGranted ?? false;
      final storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      return audioGranted || storageGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestBluetoothPermissions() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.bluetoothConnect.request();
        return status.isGranted;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
