import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/platform/contracts/platform_storage.dart';
import 'package:noctra/core/platform/storage/platform_storage_resolver.dart';

void main() {
  group('Cross-Platform PlatformStorage Contract Tests', () {
    late Directory tempBase;
    late PlatformStorage storage;

    setUp(() async {
      tempBase = await Directory.systemTemp.createTemp('noctra_storage_test_');
      storage = PlatformStorageResolver(overrideBaseDir: tempBase);
    });

    tearDown(() async {
      if (await tempBase.exists()) {
        await tempBase.delete(recursive: true);
      }
    });

    test('AppData directory resolves and exists', () async {
      final appData = await storage.appDataDirectory;
      expect(await appData.exists(), isTrue);
      expect(appData.path, tempBase.path);
    });

    test('Cache directory creates subfolder', () async {
      final cache = await storage.cacheDirectory;
      expect(await cache.exists(), isTrue);
      expect(cache.path, contains('cache'));
    });

    test('Downloads directory creates subfolder', () async {
      final dl = await storage.downloadsDirectory;
      expect(await dl.exists(), isTrue);
      expect(dl.path, contains('downloads'));
    });

    test('Resolve download path sanitizes path safely', () async {
      final path = await storage.resolveDownloadPath('../../malicious.flac');
      expect(path, isNot(contains('../..')));
      expect(path, endsWith('malicious.flac'));
    });

    test('File existence and deletion lifecycle', () async {
      final filePath = await storage.resolveDownloadPath('test_song.flac');
      final f = File(filePath);
      await f.writeAsString('test audio data');

      expect(await storage.fileExists(filePath), isTrue);
      final deleted = await storage.deleteFile(filePath);
      expect(deleted, isTrue);
      expect(await storage.fileExists(filePath), isFalse);
    });
  });
}
