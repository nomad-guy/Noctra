import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_service.dart';
import 'package:path_provider/path_provider.dart';

/// End-to-end tests for `downloadAndVerifyApk` against a real local
/// [HttpServer]. Production trust is GitHub-only, so the tests override
/// the [AppUpdateService.isTrustedDownloadUri] seam to accept the
/// loopback server — the redirect VALIDATION LOGIC itself is exactly
/// what runs in production (every hop re-checked, not just the first).
void main() {
  late HttpServer server;
  late Directory tempDir;
  final requested = <String>[];

  final apkBytes =
      utf8.encode('META-INF/MANIFEST.MF\nfake apk payload for tests\n');
  String digestOf(List<int> bytes) => crypto.sha256.convert(bytes).toString();
  final goodDigest = digestOf(
      utf8.encode('META-INF/MANIFEST.MF\nfake apk payload for tests\n'));
  final badDigest = digestOf(utf8.encode('other'));

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('noctra_upd_test_');
    requested.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    AppUpdateService.updateTempDirProvider = () async => tempDir;
    // Accept only our loopback server — mirrors the production HTTPS +
    // host allowlist shape without needing GitHub in a unit test.
    AppUpdateService.isTrustedDownloadUri =
        (uri) => uri.scheme == 'http' && uri.host == '127.0.0.1';
  });

  tearDown(() async {
    AppUpdateService.updateTempDirProvider = () => getTemporaryDirectory();
    AppUpdateService.isTrustedDownloadUri =
        AppUpdateService.defaultIsTrustedDownloadUri;
    await server.close(force: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void serveApk({bool chunked = false}) {
    server.listen((req) {
      requested.add(req.uri.path);
      if (req.uri.path == '/apk') {
        req.response.statusCode = 200;
        req.response.headers.contentType =
            ContentType('application', 'vnd.android.package-archive');
        if (!chunked) {
          req.response.contentLength = apkBytes.length;
        }
        req.response.add(apkBytes);
        req.response.close();
      } else {
        req.response.statusCode = 404;
        req.response.close();
      }
    });
  }

  test('verifies SHA-256 and returns the verified file', () async {
    serveApk();
    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: 'v1.0.0',
      latestVersion: 'v2.0.0',
      releaseNotes: '',
      downloadUrl: url('/apk').toString(),
      expectedSha256: goodDigest,
    );
    final path = await AppUpdateService.downloadAndVerifyApk(info);
    expect(path, isNotNull);
    final file = File(path!);
    expect(await file.readAsBytes(), apkBytes);
    // The .part temp file must be gone.
    expect(tempDir.listSync().whereType<File>().length, 1);
  });

  test('refuses a SHA-256 mismatch and cleans up', () async {
    serveApk();
    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: 'v1.0.0',
      latestVersion: 'v2.0.0',
      releaseNotes: '',
      downloadUrl: url('/apk').toString(),
      expectedSha256: badDigest,
    );
    final path = await AppUpdateService.downloadAndVerifyApk(info);
    expect(path, isNull);
    expect(tempDir.listSync(), isEmpty);
  });

  test('follows a redirect but re-validates EVERY hop', () async {
    server.listen((req) {
      requested.add(req.uri.path);
      if (req.uri.path == '/start') {
        req.response.statusCode = 302;
        req.response.headers.set('location', '/apk');
        req.response.close();
      } else if (req.uri.path == '/apk') {
        req.response.contentLength = apkBytes.length;
        req.response.add(apkBytes);
        req.response.close();
      } else {
        req.response.statusCode = 404;
        req.response.close();
      }
    });
    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: 'v1.0.0',
      latestVersion: 'v2.0.0',
      releaseNotes: '',
      downloadUrl: url('/start').toString(),
      expectedSha256: goodDigest,
    );
    final path = await AppUpdateService.downloadAndVerifyApk(info);
    expect(path, isNotNull);
    expect(requested, ['/start', '/apk']);
  });

  test('refuses a redirect to an untrusted host', () async {
    server.listen((req) async {
      requested.add(req.uri.path);
      req.response.statusCode = 302;
      req.response.headers
          .set('location', 'https://evil.example.com/steal.apk');
      await req.response.close();
    });
    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: 'v1.0.0',
      latestVersion: 'v2.0.0',
      releaseNotes: '',
      downloadUrl: url('/start').toString(),
      expectedSha256: goodDigest,
    );
    final path = await AppUpdateService.downloadAndVerifyApk(info);
    expect(path, isNull);
    expect(tempDir.listSync(), isEmpty);
  });

  test('refuses an APK larger than the hard cap', () async {
    // Shrink the injectable cap below the payload so the guard triggers
    // with a real, well-formed response.
    AppUpdateService.maxDownloadBytes = 32; // apkBytes is 48 bytes
    serveApk();
    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: 'v1.0.0',
      latestVersion: 'v2.0.0',
      releaseNotes: '',
      downloadUrl: url('/apk').toString(),
      expectedSha256: goodDigest,
    );
    final path = await AppUpdateService.downloadAndVerifyApk(info);
    expect(path, isNull);
    expect(tempDir.listSync(), isEmpty);
    AppUpdateService.maxDownloadBytes =
        AppUpdateService.defaultMaxDownloadBytes;
  });

  test('two concurrent downloads never corrupt each other', () async {
    serveApk();
    AppUpdateInfo info() => AppUpdateInfo(
          hasUpdate: true,
          currentVersion: 'v1.0.0',
          latestVersion: 'v2.0.0',
          releaseNotes: '',
          downloadUrl: url('/apk').toString(),
          expectedSha256: goodDigest,
        );
    final results = await Future.wait([
      AppUpdateService.downloadAndVerifyApk(info()),
      AppUpdateService.downloadAndVerifyApk(info()),
    ]);
    // Both attempts succeed; per-attempt unique .part files mean neither
    // truncated the other. Exactly one verified final file remains.
    expect(results.every((p) => p != null), isTrue);
    final files = tempDir.listSync().whereType<File>().toList();
    expect(files.length, 1);
    expect(await files.single.readAsBytes(), apkBytes);
  });

  test('refuses when no SHA-256 digest is published (never downloads)',
      () async {
    server.listen((req) {
      requested.add(req.uri.path);
      req.response.statusCode = 200;
      req.response.add(apkBytes);
      req.response.close();
    });
    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: 'v1.0.0',
      latestVersion: 'v2.0.0',
      releaseNotes: '',
      downloadUrl: url('/apk').toString(),
      expectedSha256: '',
    );
    final path = await AppUpdateService.downloadAndVerifyApk(info);
    expect(path, isNull);
    expect(requested, isEmpty); // refused before any network I/O
  });

  test('reports indeterminate progress (-1 total) when length is unknown',
      () async {
    server.listen((req) {
      req.response.statusCode = 200;
      // No contentLength → chunked, unknown size.
      req.response.add(apkBytes);
      req.response.close();
    });
    final progress = <(int, int)>[];
    final info = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: 'v1.0.0',
      latestVersion: 'v2.0.0',
      releaseNotes: '',
      downloadUrl: url('/apk').toString(),
      expectedSha256: goodDigest,
    );
    final path = await AppUpdateService.downloadAndVerifyApk(
      info,
      onProgress: (received, total) => progress.add((received, total)),
    );
    expect(path, isNotNull);
    expect(progress, isNotEmpty);
    final (lastReceived, lastTotal) = progress.last;
    expect(lastReceived, apkBytes.length);
    expect(lastTotal, -1); // never a fabricated 60 MB guess
  });
}
