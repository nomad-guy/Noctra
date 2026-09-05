import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/platform/noctra_capabilities.dart';
import '../../data/models/download_location.dart';

/// Resolves the user-chosen download location to a writable [Directory].
///
/// Platform boundary: this is the single place that knows how each platform
/// maps a [DownloadLocation] key to a real filesystem directory. Android
/// behavior is preserved byte-for-byte from the pre-port implementation;
/// other platforms fall back to path_provider directories so downloads still
/// have a valid (private) home. Domain code never constructs these paths.
class DownloadLocationResolver {
  const DownloadLocationResolver();

  Future<Directory> resolve(String key) async {
    // Handle custom folder path directly
    if (key.startsWith('custom:')) {
      return Directory(key.substring(7));
    }
    final location = DownloadLocation.byKey(key);
    if (NoctraCapabilities.isAndroid) {
      return _resolveAndroid(location);
    }
    return _resolveOther(location);
  }

  Future<Directory> _resolveAndroid(DownloadLocation location) async {
    switch (location.key) {
      case DownloadLocation.custom:
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

  Future<Directory> _resolveOther(DownloadLocation location) async {
    switch (location.key) {
      case DownloadLocation.downloads:
        final dl = await getDownloadsDirectory();
        if (dl != null) return Directory('${dl.path}/NoctraMusic');
        break;
      case DownloadLocation.music:
      case DownloadLocation.external:
        break;
      default:
        break;
    }
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/NoctraMusic');
  }

  String _publicBase() {
    try {
      const env = String.fromEnvironment('PUBLIC_DOWNLOADS');
      if (env.isNotEmpty) return env;
    } catch (_) {}
    return Platform.environment['PUBLIC_DOWNLOADS'] ?? '/storage/emulated/0';
  }

  String _fallbackBase() {
    return Platform.environment['EXTERNAL_STORAGE'] ?? '/storage/emulated/0';
  }
}
