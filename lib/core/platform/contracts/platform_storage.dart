import 'dart:async';
import 'dart:io';

/// Abstract contract for platform-independent filesystem storage and paths.
abstract interface class PlatformStorage {
  /// Directory for internal private application data.
  Future<Directory> get appDataDirectory;

  /// Directory for temporary cache files.
  Future<Directory> get cacheDirectory;

  /// Directory where downloaded offline media should be stored.
  Future<Directory> get downloadsDirectory;

  /// Resolves an absolute path for a relative download filename.
  Future<String> resolveDownloadPath(String relativeFileName);

  /// Deletes a file safely if it exists.
  Future<bool> deleteFile(String absolutePath);

  /// Checks if a file exists.
  Future<bool> fileExists(String absolutePath);
}
