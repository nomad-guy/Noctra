import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// User-selectable storage locations for downloaded tracks.
class DownloadLocation {
  final String key;
  final String label;
  final String description;

  const DownloadLocation(
      {required this.key, required this.label, required this.description});

  static const appDocs = 'app_docs';
  static const appSupport = 'app_support';
  static const external = 'external_music';
  static const downloads = 'public_downloads';
  static const music = 'public_music';
  static const custom = 'custom_folder';

  static const all = <DownloadLocation>[
    DownloadLocation(
        key: appDocs,
        label: 'App Documents',
        description: 'Private app storage. Hidden from file managers.'),
    DownloadLocation(
        key: appSupport,
        label: 'App Support',
        description: 'Private app support files. Cleared on uninstall.'),
    DownloadLocation(
        key: external,
        label: 'External Music',
        description: 'SD card / shared storage. Visible to file managers.'),
    DownloadLocation(
        key: downloads,
        label: 'Downloads',
        description: '/storage/emulated/0/Download. Visible everywhere.'),
    DownloadLocation(
        key: music,
        label: 'Music Folder',
        description: '/storage/emulated/0/Music. Visible everywhere.'),
    DownloadLocation(
        key: custom,
        label: 'Choose Folder…',
        description: 'Browse and select any folder on your device.'),
  ];

  static DownloadLocation byKey(String? key) =>
      all.firstWhere((loc) => loc.key == key, orElse: () => all.first);
}

/// Resolves the user-chosen download location to a writable Directory.
class DownloadLocationResolver {
  const DownloadLocationResolver();

  Future<Directory> resolve(String key) async {
    // Handle custom folder path directly
    if (key.startsWith('custom:')) {
      final customPath = key.substring(7);
      return Directory(customPath);
    }
    final location = DownloadLocation.byKey(key);
    switch (location.key) {
      case DownloadLocation.custom:
        // Should never reach here — custom uses 'custom:<path>' format
        final base = await getApplicationDocumentsDirectory();
        return Directory('${base.path}/NoctraMusic');
      case DownloadLocation.appSupport:
        final base = await getApplicationSupportDirectory();
        return Directory('${base.path}/NoctraMusic');
      case DownloadLocation.external:
        final base = await getExternalStorageDirectory();
        return Directory('${base?.path ?? _fallbackBase()}/NoctraMusic');
      case DownloadLocation.downloads:
        return Directory('${_publicBase()}/Download/NoctraMusic');
      case DownloadLocation.music:
        return Directory('${_publicBase()}/Music/NoctraMusic');
      case DownloadLocation.appDocs:
      default:
        final base = await getApplicationDocumentsDirectory();
        return Directory('${base.path}/NoctraMusic');
    }
  }

  String _publicBase() {
    // Environment.PUBLIC_DOWNLOADS is provided by the Android plugin on most
    // devices, but fall back to the well-known emulated path so the picker
    // never crashes.
    try {
      const env = String.fromEnvironment('PUBLIC_DOWNLOADS');
      if (env.isNotEmpty) return env;
    } catch (_) {}
    final env =
        Platform.environment['PUBLIC_DOWNLOADS'] ?? '/storage/emulated/0';
    return env;
  }

  String _fallbackBase() {
    final env =
        Platform.environment['EXTERNAL_STORAGE'] ?? '/storage/emulated/0';
    return env;
  }
}
