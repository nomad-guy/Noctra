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
}
