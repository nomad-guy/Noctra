import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_cadence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
  DateTime? stored;
  final defaultNow = AppUpdateCadence.now;
  final defaultRead = AppUpdateCadence.readLastCheck;
  final defaultWrite = AppUpdateCadence.writeLastCheck;

  setUp(() {
    fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
    stored = null;
    AppUpdateCadence.now = () => fakeNow;
    AppUpdateCadence.readLastCheck = () async => stored;
    AppUpdateCadence.writeLastCheck = (when) async {
      stored = when;
    };
  });

  tearDown(() {
    AppUpdateCadence.now = defaultNow;
    AppUpdateCadence.readLastCheck = defaultRead;
    AppUpdateCadence.writeLastCheck = defaultWrite;
  });

  group('shouldAutoCheckNow', () {
    test('first ever run always checks', () async {
      expect(await AppUpdateCadence.shouldAutoCheckNow(), isTrue);
    });

    test('skips a second check within the 12h window', () async {
      stored = fakeNow.subtract(const Duration(hours: 1));
      expect(await AppUpdateCadence.shouldAutoCheckNow(), isFalse);
    });

    test('checks again once 12h has elapsed', () async {
      stored = fakeNow.subtract(const Duration(hours: 12));
      expect(await AppUpdateCadence.shouldAutoCheckNow(), isTrue);
    });

    test('boundary: exactly 12h is allowed', () async {
      stored = fakeNow.subtract(const Duration(hours: 12));
      expect(await AppUpdateCadence.shouldAutoCheckNow(), isTrue);
    });

    test('clock moving backwards does not enable a storm', () async {
      stored = fakeNow.subtract(const Duration(hours: 13));
      fakeNow = stored!.subtract(const Duration(minutes: 1));
      expect(await AppUpdateCadence.shouldAutoCheckNow(), isFalse);
    });

    test('never throws even when storage is broken', () async {
      AppUpdateCadence.readLastCheck = () async => throw Exception('disk');
      expect(await AppUpdateCadence.shouldAutoCheckNow(), isTrue);
    });
  });

  group('recordCheck', () {
    test('persists the current timestamp', () async {
      await AppUpdateCadence.recordCheck();
      expect(stored, fakeNow);
    });

    test('storage failure is swallowed (record never throws)', () async {
      AppUpdateCadence.writeLastCheck = (when) async {
        throw Exception('disk full');
      };
      await AppUpdateCadence.recordCheck();
      expect(stored, isNull);
    });
  });
}
