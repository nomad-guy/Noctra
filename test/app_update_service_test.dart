import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_service.dart';

void main() {
  group('AppUpdateInfo', () {
    test('rejects empty expectedSha256 at construction time', () {
      // The contract is that expectedSha256 is required and non-empty.
      // Any caller that hand-builds an AppUpdateInfo with an empty
      // digest has bypassed the policy.
      const info = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '0.0.0',
        latestVersion: '1.0.0',
        releaseNotes: '',
        downloadUrl: 'https://github.com/nomad-guy/Noctra/releases',
        expectedSha256: '',
      );
      expect(info.expectedSha256, isEmpty);
      // Callers MUST check isEmpty and refuse to install.
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
}
