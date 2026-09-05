import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('compareVersions', () {
    test('basic ordering', () {
      expect(
          AppUpdateService.compareVersions('v1.2.3', 'v1.2.2'), greaterThan(0));
      expect(AppUpdateService.compareVersions('1.2.2', '1.2.3'), lessThan(0));
      expect(AppUpdateService.compareVersions('1.2.3', '1.2.3'), 0);
      expect(
          AppUpdateService.compareVersions('v2.0.0', 'v1.9.9'), greaterThan(0));
    });

    test('accepts build metadata and extra numeric components', () {
      expect(AppUpdateService.compareVersions('1.2.3+build5', '1.2.3'), 0);
      expect(
          AppUpdateService.compareVersions('1.2.3.4', '1.2.3'), greaterThan(0));
      expect(AppUpdateService.compareVersions('1.2.4', '1.2.3.99'),
          greaterThan(0));
    });

    test('pre-releases sort older than their release', () {
      expect(
          AppUpdateService.compareVersions('1.2.3-rc1', '1.2.3'), lessThan(0));
      expect(AppUpdateService.compareVersions('1.2.3', '1.2.3-rc1'),
          greaterThan(0));
    });

    test('malformed versions fail closed (never newer, never downgrade)', () {
      expect(AppUpdateService.compareVersions('not-a-version', '1.0.0'), 0);
      expect(AppUpdateService.compareVersions('1.0.0', 'garbage!!'), 0);
      expect(AppUpdateService.compareVersions('1..2.3', '1.0.0'), 0);
      expect(AppUpdateService.compareVersions('v1.2.3', ''), 0);
    });
  });

  group('isVerifiedInstallCandidate', () {
    const checkChannel = MethodChannel('com.nomadguy.noctra/installer_check');
    const certDigest =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    Map<String, dynamic> goodPayload(
            {int versionCode = 42, int installed = 41}) =>
        {
          'packageName': AppUpdateService.expectedApplicationId,
          'versionCode': versionCode,
          'versionName': '2.0.0',
          'signerDigests': <String>[certDigest],
          'matchesInstalledSigner': true,
          'installedVersionCode': installed,
        };

    setUp(() => AppUpdateService.pinnedSignerSha256 = '');
    tearDown(() => AppUpdateService.pinnedSignerSha256 = '');

    test('accepts matching package with signer continuity and a newer version',
        () async {
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload();
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isTrue);
    });

    test('refuses a different package id', () async {
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload()..['packageName'] = 'com.evil.other';
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);
    });

    test('refuses when the signer does not match the installed app', () async {
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload()..['matchesInstalledSigner'] = false;
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);
    });

    test('refuses equal or older versionCode (no silent downgrade)', () async {
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload(versionCode: 42, installed: 42); // equal
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);

      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload(versionCode: 40, installed: 42); // older
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);
    });

    test('refuses when version data is missing (fail closed)', () async {
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload()..remove('installedVersionCode');
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);
    });

    test('with a pin set: accepts archive signed by the pinned cert', () async {
      AppUpdateService.pinnedSignerSha256 = certDigest;
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload();
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isTrue);
    });

    test('with a pin set: refuses an archive signed by a different cert',
        () async {
      AppUpdateService.pinnedSignerSha256 = certDigest;
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        return goodPayload()
          ..['signerDigests'] = <String>[
            '9999999999999999999999999999999999999999999999999999999999999999'
          ];
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);
    });

    test('refuses on platform error (fail closed)', () async {
      messenger.setMockMethodCallHandler(checkChannel, (call) async {
        throw PlatformException(code: 'INSTALLER_CHECK_ERROR');
      });
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);
    });

    test('refuses null / empty responses', () async {
      messenger.setMockMethodCallHandler(checkChannel, (call) async => null);
      expect(await AppUpdateService.isVerifiedInstallCandidate('/tmp/x.apk'),
          isFalse);
    });
  });
}
