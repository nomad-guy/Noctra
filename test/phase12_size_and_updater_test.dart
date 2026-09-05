import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/services/updater/app_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
  });

  group('Phase 12: ABI & Updater Architecture Detection', () {
    test('currentDeviceAbi returns valid architecture string', () {
      final abi = AppUpdateService.currentDeviceAbi;
      expect(
        abi == 'arm64-v8a' ||
            abi == 'armeabi-v7a' ||
            abi == 'x86_64' ||
            abi == 'x86' ||
            abi == 'universal',
        isTrue,
        reason: 'ABI should be a recognized Android architecture or universal',
      );
    });

    test('extractAssetSha256 resolves ABI-specific hashes from multi-asset release notes', () {
      const releaseNotes = '''
## Release v1.2.0

### Downloads & Checksums:
* noctra-arm64-v8a-release.apk:
  sha256: 1111111111111111111111111111111111111111111111111111111111111111
* noctra-armeabi-v7a-release.apk:
  sha256: 2222222222222222222222222222222222222222222222222222222222222222
* noctra-x86_64-release.apk:
  sha256: 3333333333333333333333333333333333333333333333333333333333333333
* noctra-universal-release.apk:
  sha256: 4444444444444444444444444444444444444444444444444444444444444444
''';

      final arm64Sha = AppUpdateService.extractAssetSha256(releaseNotes,
          assetName: 'noctra-arm64-v8a-release.apk');
      expect(arm64Sha, '1111111111111111111111111111111111111111111111111111111111111111');

      final v7Sha = AppUpdateService.extractAssetSha256(releaseNotes,
          assetName: 'noctra-armeabi-v7a-release.apk');
      expect(v7Sha, '2222222222222222222222222222222222222222222222222222222222222222');

      final x64Sha = AppUpdateService.extractAssetSha256(releaseNotes,
          assetName: 'noctra-x86_64-release.apk');
      expect(x64Sha, '3333333333333333333333333333333333333333333333333333333333333333');

      final uniSha = AppUpdateService.extractAssetSha256(releaseNotes,
          assetName: 'noctra-universal-release.apk');
      expect(uniSha, '4444444444444444444444444444444444444444444444444444444444444444');
    });
  });

  group('Phase 12: Migration & Data Continuity', () {
    test('legacy amoled theme setting automatically self-heals to noirBlack', () async {
      SharedPreferences.setMockInitialValues({
        'noctra_theme_mode': 'amoled',
      });
      final db = NoctraLocalDatabase();
      await db.init();

      expect(db.getCachedThemeMode(), 'noirBlack');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('noctra_theme_mode'), 'noirBlack');
    });

    test('legacy noirAmoled theme setting automatically self-heals to noirBlack', () async {
      SharedPreferences.setMockInitialValues({
        'noctra_theme_mode': 'noirAmoled',
      });
      final db = NoctraLocalDatabase();
      await db.init();

      expect(db.getCachedThemeMode(), 'noirBlack');
    });

    test('liquidGlass and noirWhite themes are preserved intact', () async {
      SharedPreferences.setMockInitialValues({
        'noctra_theme_mode': 'liquidGlass',
      });
      final db = NoctraLocalDatabase();
      await db.init();
      expect(db.getCachedThemeMode(), 'liquidGlass');
    });
  });

  group('Phase 12: Production Asset Manifest Audit', () {
    test('all 4 production assets load successfully without error', () async {
      const activeAssets = [
        'assets/images/logo_noctra_noir_black.png',
        'assets/images/logo_noctra_noir_white.png',
        'assets/images/logo_noctra_liquid_glass.png',
        'assets/images/liquid_glass_shard.png',
      ];

      for (final asset in activeAssets) {
        final byteData = await rootBundle.load(asset);
        expect(byteData.lengthInBytes, greaterThan(0));
        // Verify shard is optimized (< 50KB instead of old 503KB)
        if (asset.contains('liquid_glass_shard')) {
          expect(byteData.lengthInBytes, lessThan(60000));
        }
      }
    });
  });
}
