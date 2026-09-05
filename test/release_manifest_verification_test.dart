import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_manifest.dart';

void main() {
  group('Release Manifest & Artifact Integrity Verification', () {
    test('release/noctra-update-manifest.json parses strictly and matches physical APKs', () {
      final manifestFile = File('release/noctra-update-manifest.json');
      expect(manifestFile.existsSync(), isTrue);

      final raw = manifestFile.readAsStringSync();
      final manifest = ReleaseManifest.parse(raw);
      expect(manifest, isNotNull, reason: 'Manifest must pass ReleaseManifest.parse');

      expect(manifest!.version, equals('1.0.1'));
      expect(manifest.versionCode, equals(13001));
      expect(manifest.minimumAndroid, equals(21));
      expect(manifest.packages.containsKey('arm64-v8a'), isTrue);
      expect(manifest.packages.containsKey('armeabi-v7a'), isTrue);
      expect(manifest.packages.containsKey('x86_64'), isTrue);
      expect(manifest.packages.containsKey('universal'), isTrue);

      for (final entry in manifest.packages.entries) {
        final abi = entry.key;
        final pkg = entry.value;
        final apkFile = File('release/${pkg.file}');
        expect(apkFile.existsSync(), isTrue, reason: 'APK ${pkg.file} for $abi must exist');

        final bytes = apkFile.readAsBytesSync();
        final digest = sha256.convert(bytes).toString().toLowerCase();
        expect(digest, equals(pkg.sha256.toLowerCase()),
            reason: 'SHA-256 in manifest for $abi must match physical file');
      }
    });

    test('release/SHA256SUMS.txt matches physical APKs', () {
      final sumsFile = File('release/SHA256SUMS.txt');
      expect(sumsFile.existsSync(), isTrue);

      final lines = sumsFile.readAsLinesSync().where((l) => l.trim().isNotEmpty);
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        expect(parts.length, equals(2));
        final expectedHash = parts[0].toLowerCase();
        final fileName = parts[1];

        final apkFile = File('release/$fileName');
        expect(apkFile.existsSync(), isTrue, reason: '$fileName must exist');

        final bytes = apkFile.readAsBytesSync();
        final digest = sha256.convert(bytes).toString().toLowerCase();
        expect(digest, equals(expectedHash), reason: '$fileName hash must match SHA256SUMS.txt');
      }
    });
  });
}
