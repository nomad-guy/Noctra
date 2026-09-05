import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_manifest.dart';

void main() {
  const shaA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const shaB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  String validManifest() => '''
{
  "version": "1.2.0",
  "versionCode": 120,
  "minimumAndroid": 26,
  "packages": {
    "arm64-v8a": { "file": "Noctra-1.2.0-arm64.apk", "sha256": "$shaA" },
    "universal": { "file": "Noctra-1.2.0-universal.apk", "sha256": "$shaB" }
  }
}''';

  group('ReleaseManifest.parse', () {
    test('accepts a well-formed manifest', () {
      final m = ReleaseManifest.parse(validManifest());
      expect(m, isNotNull);
      expect(m!.version, '1.2.0');
      expect(m.versionCode, 120);
      expect(m.minimumAndroid, 26);
      expect(m.packages.length, 2);
      expect(m.packages['arm64-v8a']!.sha256, shaA);
    });

    test('rejects malformed JSON', () {
      expect(ReleaseManifest.parse('{not json'), isNull);
    });

    test('rejects non-map roots and empty packages', () {
      expect(ReleaseManifest.parse('[]'), isNull);
      expect(ReleaseManifest.parse('{"version":"1.0.0"}'), isNull);
    });

    test('rejects missing/blank version', () {
      expect(
          ReleaseManifest.parse(
              '{"packages":{"universal":{"file":"a.apk","sha256":"$shaA"}}}'),
          isNull);
      expect(
          ReleaseManifest.parse(
              '{"version":" ","packages":{"universal":{"file":"a.apk","sha256":"$shaA"}}}'),
          isNull);
    });

    test('rejects unknown ABI keys (typo cannot silently serve)', () {
      expect(
          ReleaseManifest.parse(
              '{"version":"1.0.0","packages":{"arm64-v8aa":{"file":"a.apk","sha256":"$shaA"}}}'),
          isNull);
    });

    test('rejects unsafe filenames (traversal / absolute / wrong suffix)',
        () {
      for (final bad in [
        '../evil.apk',
        'a/../evil.apk',
        '/absolute/evil.apk',
        'C:\\\\evil.apk',
        'update.zip',
        '',
      ]) {
        expect(
            ReleaseManifest.parse(
                '{"version":"1.0.0","packages":{"universal":{"file":"$bad","sha256":"$shaA"}}}'),
            isNull,
            reason: 'should reject file "$bad"');
      }
    });

    test('rejects invalid SHA-256 digests', () {
      for (final bad in ['', 'abc', 'zz' * 32, 'a' * 63]) {
        expect(
            ReleaseManifest.parse(
                '{"version":"1.0.0","packages":{"universal":{"file":"a.apk","sha256":"$bad"}}}'),
            isNull,
            reason: 'should reject digest "$bad"');
      }
    });

    test('accepts uppercase digest and normalizes to lowercase', () {
      final m = ReleaseManifest.parse(
          '{"version":"1.0.0","packages":{"universal":{"file":"a.apk","sha256":"${shaA.toUpperCase()}"}}}');
      expect(m!.packages['universal']!.sha256, shaA);
    });

    test('rejects oversized manifests (bounded input)', () {
      final big = '{"version":"1.0.0","packages":{"universal":'
          '{"file":"a.apk","sha256":"$shaA"},"pad":"'
          '${'x' * (ReleaseManifest.maxManifestChars)}"}}';
      expect(ReleaseManifest.parse(big), isNull);
    });
  });

  group('ReleaseManifest.selectForAbi', () {
    test('prefers the exact ABI over the universal fallback', () {
      final m = ReleaseManifest.parse(validManifest())!;
      final pkg = ReleaseManifest.selectForAbi(m, 'arm64-v8a');
      expect(pkg!.file, 'Noctra-1.2.0-arm64.apk');
    });

    test('falls back to universal for unknown/unpublished ABIs', () {
      final m = ReleaseManifest.parse(validManifest())!;
      final pkg = ReleaseManifest.selectForAbi(m, 'x86');
      expect(pkg!.file, 'Noctra-1.2.0-universal.apk');
    });

    test('returns null when neither exact nor universal exists', () {
      final m = ReleaseManifest.parse(
          '{"version":"1.0.0","packages":{"arm64-v8a":{"file":"a.apk","sha256":"$shaA"}}}')!;
      expect(ReleaseManifest.selectForAbi(m, 'x86'), isNull);
    });

    test('normalizes device ABI casing/whitespace', () {
      final m = ReleaseManifest.parse(validManifest())!;
      expect(
          ReleaseManifest.selectForAbi(m, '  ARM64-v8a  ')!.file,
          'Noctra-1.2.0-arm64.apk');
    });
  });

  group('ReleaseManifest.downloadUriFor', () {
    test('derives URL from the pinned base only', () {
      final uri = ReleaseManifest.downloadUriFor('Noctra-1.2.0-arm64.apk');
      expect(uri.toString(),
          'https://github.com/nomad-guy/Noctra/releases/latest/download/Noctra-1.2.0-arm64.apk');
    });

    test('never accepts unsafe filenames', () {
      for (final bad in ['', 'x.apk/y', '..%2f..%2fevil.apk', 'a\\b.apk']) {
        expect(ReleaseManifest.downloadUriFor(bad), isNull,
            reason: 'should reject "$bad"');
      }
    });
  });

  group('ReleaseManifest.isNewerThan', () {
    test('newer semver wins regardless of versionCode', () {
      final m = ReleaseManifest.parse(validManifest())!;
      expect(ReleaseManifest.isNewerThan(m, installedVersion: 'v1.1.0'),
          isTrue);
    });

    test('older or equal semver is not an update without a code bump', () {
      final m = ReleaseManifest.parse(validManifest())!;
      expect(ReleaseManifest.isNewerThan(m, installedVersion: 'v1.2.0'),
          isFalse);
      expect(
          ReleaseManifest.isNewerThan(m,
              installedVersion: 'v1.2.0', installedVersionCode: 130),
          isFalse); // newer build but lower versionCode is not an update
    });

    test('equal semver with a newer published versionCode is an update', () {
      final m = ReleaseManifest.parse(validManifest())!;
      expect(
          ReleaseManifest.isNewerThan(m,
              installedVersion: 'v1.2.0', installedVersionCode: 100),
          isTrue);
    });

    test('older semver never downgrades even with higher code', () {
      final m = ReleaseManifest.parse(validManifest())!;
      expect(
          ReleaseManifest.isNewerThan(m,
              installedVersion: 'v2.0.0', installedVersionCode: 10),
          isFalse);
    });
  });
}
