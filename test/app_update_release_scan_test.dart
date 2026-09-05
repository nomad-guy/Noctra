import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:noctra/services/updater/app_update_manifest.dart';
import 'package:noctra/services/updater/app_update_release_scan.dart';
import 'package:noctra/services/updater/app_update_manifest_signature.dart';

void main() {
  const shaA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const shaB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  http.Response apiOk(Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), 200);

  Map<String, dynamic> releaseWith(
          {String tag = 'v1.2.0', List<Map<String, dynamic>>? assets}) =>
      {
        'tag_name': tag,
        'body': 'Release notes here',
        'assets': assets ?? [],
      };

  Map<String, dynamic> manifestAsset() => {
        'name': ReleaseManifest.manifestAssetName,
        'browser_download_url':
            'https://github.com/nomad-guy/Noctra/releases/download/v1.2.0/${ReleaseManifest.manifestAssetName}',
      };

  Map<String, dynamic> signatureAsset() => {
        'name': ReleaseManifest.manifestSignatureAssetName,
        'browser_download_url':
            'https://github.com/nomad-guy/Noctra/releases/download/v1.2.0/${ReleaseManifest.manifestSignatureAssetName}',
      };

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

  tearDown(() {
    AppUpdateReleaseScan.apiGet = (uri,
            {timeout = AppUpdateReleaseScan.apiTimeout}) =>
        throw StateError('apiGet not stubbed');
    AppUpdateReleaseScan.manifestFetcher = (uri) async => null;
    AppUpdateReleaseScan.verifyManifestSignature =
        AppUpdateManifestSignature.verify;
    AppUpdateManifestSignature.publicKeyBase64 = '';
  });

  group('manifest-first scan', () {
    test('offers the exact artifact when the release is newer', () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(assets: [manifestAsset()]));
      AppUpdateReleaseScan.manifestFetcher = (uri) async => validManifest();

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res, isNotNull);
      expect(res!.hasUpdate, isTrue);
      expect(res.latestVersion, '1.2.0');
      expect(res.downloadUrl,
          'https://github.com/nomad-guy/Noctra/releases/latest/download/Noctra-1.2.0-universal.apk');
      expect(res.expectedSha256, shaB);
    });

    test('declines when the release is not newer (no repeated offers)',
        () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(tag: 'v1.2.0', assets: [manifestAsset()]));
      AppUpdateReleaseScan.manifestFetcher = (uri) async => validManifest();

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.2.0', installedVersionCode: 120);
      expect(res!.hasUpdate, isFalse);
    });

    test('no update when the manifest lacks a package for this ABI', () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(assets: [manifestAsset()]));
      AppUpdateReleaseScan.manifestFetcher = (uri) async => '''
{
  "version": "1.2.0",
  "packages": {
    "arm64-v8a": { "file": "Noctra-1.2.0-arm64.apk", "sha256": "$shaA" }
  }
}''';

      // Test host ABI is not arm64-v8a and no universal package exists.
      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res!.hasUpdate, isFalse);
    });

    test('malformed manifest falls through to the legacy scan', () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(tag: 'v1.2.0', assets: [
            manifestAsset(),
            {
              'name': 'noctra-universal-release.apk',
              'browser_download_url':
                  'https://github.com/nomad-guy/Noctra/releases/download/v1.2.0/noctra-universal-release.apk',
              'digest': 'sha256:$shaB',
            },
          ]));
      AppUpdateReleaseScan.manifestFetcher = (uri) async => '{broken';

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res!.hasUpdate, isTrue);
      expect(res.expectedSha256, shaB);
      expect(res.downloadUrl, contains('noctra-universal-release.apk'));
    });

    test('configured signing key accepts a valid manifest-signature pair',
        () async {
      AppUpdateManifestSignature.publicKeyBase64 = 'configured-key';
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(assets: [manifestAsset(), signatureAsset()]));
      AppUpdateReleaseScan.manifestFetcher = (uri) async {
        return uri.path.endsWith('.sig') ? 'signature' : validManifest();
      };
      AppUpdateReleaseScan.verifyManifestSignature = (
              {required manifest, required detachedSignature}) async =>
          manifest == validManifest() && detachedSignature == 'signature';

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res!.hasUpdate, isTrue);
      expect(res.expectedSha256, shaB);
    });

    test('configured signing key refuses a missing signature asset', () async {
      AppUpdateManifestSignature.publicKeyBase64 = 'configured-key';
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(assets: [manifestAsset()]));
      AppUpdateReleaseScan.manifestFetcher = (uri) async => validManifest();

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res!.hasUpdate, isFalse);
    });

    test('configured signing key refuses an invalid signature', () async {
      AppUpdateManifestSignature.publicKeyBase64 = 'configured-key';
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(assets: [manifestAsset(), signatureAsset()]));
      AppUpdateReleaseScan.manifestFetcher = (uri) async {
        return uri.path.endsWith('.sig') ? 'invalid' : validManifest();
      };
      AppUpdateReleaseScan.verifyManifestSignature =
          ({required manifest, required detachedSignature}) async => false;

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res!.hasUpdate, isFalse);
    });
  });

  group('legacy scan', () {
    test('matches a digest-bearing asset without release-notes scraping',
        () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(assets: [
            {
              'name': 'noctra-universal-release.apk',
              'browser_download_url':
                  'https://github.com/nomad-guy/Noctra/releases/download/v1.2.0/noctra-universal-release.apk',
              'digest': 'sha256:$shaB',
            },
          ]));

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res!.hasUpdate, isTrue);
      expect(res.expectedSha256, shaB);
    });

    test('refuses a newer release with no unambiguous digest', () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          apiOk(releaseWith(tag: 'v1.2.0', assets: [
            {'name': 'noctra-universal-release.apk'},
          ]));

      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res!.hasUpdate, isFalse);
    });
  });

  group('feed failures', () {
    test('API error maps to no scan result', () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          http.Response('rate limited', 429);
      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res, isNull);
    });

    test('network failure maps to no scan result (no crash)', () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          throw http.ClientException('offline');
      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res, isNull);
    });

    test('malformed API JSON maps to no scan result', () async {
      AppUpdateReleaseScan.apiGet = (uri,
              {timeout = AppUpdateReleaseScan.apiTimeout}) async =>
          http.Response('<!doctype html>', 200);
      final res = await AppUpdateReleaseScan.scan(
          installedVersion: 'v1.1.6', installedVersionCode: 116);
      expect(res, isNull);
    });
  });
}
