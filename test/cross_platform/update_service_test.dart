import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/platform/contracts/update_service.dart';
import 'package:noctra/services/updater/providers/desktop_update_provider.dart';
import 'package:noctra/services/updater/providers/ios_update_provider.dart';
import 'package:noctra/services/updater/providers/update_provider_factory.dart';

void main() {
  group('Cross-Platform UpdateProvider Contract Tests', () {
    test('UpdateProviderFactory resolves without error', () {
      final provider = UpdateProviderFactory.getProvider();
      expect(provider, isNotNull);
    });

    test('IOSUpdateProvider safely reports unsupported without launching installer', () async {
      const provider = IOSUpdateProvider();
      const release = UpdateReleaseInfo(
        version: '1.2.0',
        changelog: 'iOS Bug fixes',
        downloadUrl: 'https://example.com/update.apk',
        platformTarget: 'ios',
      );

      final result = await provider.performUpdate(release);
      expect(result.status, UpdateInstallStatus.unsupported);
    });

    test('DesktopUpdateProvider model properties are preserved', () {
      const provider = DesktopUpdateProvider(platform: 'windows');
      expect(provider.platform, 'windows');
    });
  });
}
