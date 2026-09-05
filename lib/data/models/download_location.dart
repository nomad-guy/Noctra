/// User-selectable storage locations for downloaded tracks.
///
/// Pure model: no `dart:io`, no platform paths. Resolving a key to a real
/// directory happens in the platform layer (`DownloadLocationResolver` in
/// services/platform), never here.
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
        description: 'Public Downloads folder. Visible everywhere.'),
    DownloadLocation(
        key: music,
        label: 'Music Folder',
        description: 'Public Music folder. Visible everywhere.'),
    DownloadLocation(
        key: custom,
        label: 'Choose Folder…',
        description: 'Browse and select any folder on your device.'),
  ];

  static DownloadLocation byKey(String? key) =>
      all.firstWhere((loc) => loc.key == key, orElse: () => all.first);
}
