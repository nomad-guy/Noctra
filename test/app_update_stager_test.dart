import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_stager.dart';

void main() {
  tearDown(() {
    AppUpdateStager.clear();
    AppUpdateStager.verifyCandidate = (_) async => false;
  });

  test('stages only a verified candidate until installation is requested',
      () async {
    AppUpdateStager.verifyCandidate = (path) async => path == '/tmp/update.apk';

    expect(await AppUpdateStager.stage('/tmp/update.apk'), isTrue);
    expect(AppUpdateStager.hasStagedUpdate, isTrue);
    expect(AppUpdateStager.stagedPath, '/tmp/update.apk');
    expect(AppUpdateStager.takeStagedPath(), '/tmp/update.apk');
    expect(AppUpdateStager.hasStagedUpdate, isFalse);
  });

  test('refuses to stage an unverified candidate', () async {
    AppUpdateStager.verifyCandidate = (_) async => false;

    expect(await AppUpdateStager.stage('/tmp/tampered.apk'), isFalse);
    expect(AppUpdateStager.hasStagedUpdate, isFalse);
  });
}
