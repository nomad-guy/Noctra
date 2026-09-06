import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../contracts/platform_storage.dart';
import '../noctra_capabilities.dart';

/// Concrete implementation of [PlatformStorage] using cross-platform path providers.
///
/// Ensures logical paths map to OS-compliant locations across Windows, Linux, Android, and iOS.
class PlatformStorageResolver implements PlatformStorage {
  final Directory? _overrideBaseDir;

  const PlatformStorageResolver({Directory? overrideBaseDir})
      : _overrideBaseDir = overrideBaseDir;

  @override
  Future<Directory> get appDataDirectory async {
    if (_overrideBaseDir != null) return _overrideBaseDir;
    return await getApplicationSupportDirectory();
  }

  @override
  Future<Directory> get cacheDirectory async {
    if (_overrideBaseDir != null) {
      final d = Directory(p.join(_overrideBaseDir.path, 'cache'));
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
    return await getTemporaryDirectory();
  }

  @override
  Future<Directory> get downloadsDirectory async {
    if (_overrideBaseDir != null) {
      final d = Directory(p.join(_overrideBaseDir.path, 'downloads'));
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }

    try {
      if (NoctraCapabilities.isDesktop) {
        final dls = await getDownloadsDirectory();
        if (dls != null) {
          final noctraFolder = Directory(p.join(dls.path, 'Noctra'));
          if (!await noctraFolder.exists()) await noctraFolder.create(recursive: true);
          return noctraFolder;
        }
      }
      final docs = await getApplicationDocumentsDirectory();
      final noctraMusic = Directory(p.join(docs.path, 'NoctraMusic'));
      if (!await noctraMusic.exists()) await noctraMusic.create(recursive: true);
      return noctraMusic;
    } catch (_) {
      return await getApplicationSupportDirectory();
    }
  }

  @override
  Future<String> resolveDownloadPath(String relativeFileName) async {
    final dlDir = await downloadsDirectory;
    final sanitized = p.basename(relativeFileName);
    return p.join(dlDir.path, sanitized);
  }

  @override
  Future<bool> deleteFile(String absolutePath) async {
    try {
      final f = File(absolutePath);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> fileExists(String absolutePath) async {
    try {
      return await File(absolutePath).exists();
    } catch (_) {
      return false;
    }
  }
}
