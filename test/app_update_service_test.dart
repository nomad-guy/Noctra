import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.nomadguy.noctra/signing_cert');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('AppUpdateInfo', () {
    test('rejects empty expectedSha256 at construction time', () {
      const info = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '0.0.0',
        latestVersion: '1.0.0',
        releaseNotes: '',
        downloadUrl: 'https://github.com/nomad-guy/Noctra/releases',
        expectedSha256: '',
      );
      expect(info.expectedSha256, isEmpty);
    });

    test('required field enforced via non-nullable type', () {
      const info = AppUpdateInfo(
        hasUpdate: false,
        currentVersion: '1.0.0',
        latestVersion: '1.0.0',
        releaseNotes: '',
        downloadUrl: 'https://github.com/nomad-guy/Noctra/releases',
        expectedSha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(info.expectedSha256.length, 64);
    });
  });

  group('isSignaturePinned', () {
    test('returns true when platform reports matching digest', () async {
      const digest =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String>[digest.toUpperCase()];
      });
      expect(await AppUpdateService.isSignaturePinned(digest), isTrue);
    });

    test('returns true for case-insensitive match', () async {
      const digest =
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String>[digest.toUpperCase()];
      });
      expect(await AppUpdateService.isSignaturePinned(digest), isTrue);
    });

    test('returns false when platform reports no match', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String>[
          '0000000000000000000000000000000000000000000000000000000000000000'
        ];
      });
      expect(
        await AppUpdateService.isSignaturePinned(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
        isFalse,
      );
    });

    test('returns false when platform returns null', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(
        await AppUpdateService.isSignaturePinned(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
        isFalse,
      );
    });

    test('returns false when platform returns empty list', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String>[];
      });
      expect(
        await AppUpdateService.isSignaturePinned(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
        isFalse,
      );
    });

    test('returns false when expected digest is empty', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String>[
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        ];
      });
      expect(await AppUpdateService.isSignaturePinned(''), isFalse);
    });

    test('returns false on platform error (default deny)', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'SIGNING_CERT_ERROR');
      });
      expect(
        await AppUpdateService.isSignaturePinned(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
        isFalse,
      );
    });

    test('tolerates non-string entries in returned list', () async {
      const digest =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <dynamic>[42, null, digest];
      });
      expect(await AppUpdateService.isSignaturePinned(digest), isTrue);
    });
  });

  group('extractAssetSha256', () {
    const hashA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const hashB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const hashC =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    test('accepts a hash explicitly named on its line', () {
      final notes = '## SHA-256\n'
          'noctra-universal-release.apk: sha256:$hashA\n'
          'noctra-arm64-v8a-release.apk: sha256:$hashB';
      expect(
          AppUpdateService.extractAssetSha256(notes,
              assetName: 'noctra-universal-release.apk'),
          hashA);
    });

    test('accepts a lone hash when the body pins exactly one total', () {
      final notes = 'Release notes\nSHA256: $hashA\nEnjoy!';
      expect(
          AppUpdateService.extractAssetSha256(notes,
              assetName: 'noctra-universal-release.apk'),
          hashA);
    });

    test('accepts uppercase and surrounding whitespace', () {
      final notes =
          'noctra-universal-release.apk   sha256: ${hashA.toUpperCase()}  ';
      expect(
          AppUpdateService.extractAssetSha256(notes,
              assetName: 'noctra-universal-release.apk'),
          hashA);
    });

    test('refuses multiple anonymous hashes (ambiguous)', () {
      final notes = 'h1: $hashA\nh2: $hashB';
      expect(
          AppUpdateService.extractAssetSha256(notes,
              assetName: 'noctra-universal-release.apk'),
          isNull);
    });

    test('refuses when another artifact hash is present and ours is unnamed',
        () {
      final notes =
          'noctra-arm64-v8a-release.apk: sha256:$hashB\nother: $hashC';
      expect(
          AppUpdateService.extractAssetSha256(notes,
              assetName: 'noctra-universal-release.apk'),
          isNull);
    });

    test('ignores wrong-length hex strings', () {
      final notes = 'sha256:abcd1234 (too short) sha256:$hashA';
      expect(
          AppUpdateService.extractAssetSha256(notes,
              assetName: 'noctra-universal-release.apk'),
          hashA);
    });

    test('empty notes refuse', () {
      expect(
          AppUpdateService.extractAssetSha256('',
              assetName: 'noctra-universal-release.apk'),
          isNull);
    });
  });
}
