import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_service.dart';
import 'package:path_provider/path_provider.dart';

/// Resume + single-flight tests against a local [HttpServer] that honors
/// byte ranges (200 / 206 / 416), overriding the trusted-host seam to
/// the loopback server exactly as `updater_download_test.dart` does.
void main() {
  late HttpServer server;
  late Directory tempDir;
  int fullRequests = 0;
  int resumeRequests = 0;

  // 256 KB payload so mid-stream interruptions are observable.
  final payload = List<int>.generate(256 * 1024, (i) => i % 251);
  final digest = crypto.sha256.convert(payload).toString();
  final partName = 'noctra-update-${digest.substring(0, 16)}.part';

  Uri url() => Uri.parse('http://127.0.0.1:${server.port}/apk');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('noctra_resume_');
    fullRequests = 0;
    resumeRequests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    AppUpdateService.updateTempDirProvider = () async => tempDir;
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

  AppUpdateInfo info() => AppUpdateInfo(
        hasUpdate: true,
        currentVersion: 'v1.0.0',
        latestVersion: 'v2.0.0',
        releaseNotes: '',
        downloadUrl: url().toString(),
        expectedSha256: digest,
      );

  /// Healthy Range-capable handler.
  void serveRangeAware() {
    server.listen((req) async {
      if (req.uri.path != '/apk') {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range == null) {
        fullRequests++;
        req.response.statusCode = 200;
        req.response.contentLength = payload.length;
        req.response.add(payload);
        await req.response.close();
        return;
      }
      final m = RegExp(r'bytes=(\d+)-').firstMatch(range);
      final start = m == null ? 0 : int.parse(m.group(1)!);
      if (start >= payload.length) {
        req.response.statusCode = 416;
        await req.response.close();
        return;
      }
      resumeRequests++;
      req.response.statusCode = 206;
      req.response.headers
          .set(HttpHeaders.contentRangeHeader,
              'bytes $start-${payload.length - 1}/${payload.length}');
      req.response.contentLength = payload.length - start;
      req.response.add(payload.sublist(start));
      await req.response.close();
    });
  }

  File partFile() => File('${tempDir.path}/$partName');

  group('byte-range resume', () {
    test('a seeded partial downloads the remainder and verifies the full '
        'file hash', () async {
      serveRangeAware();
      // Simulate an interrupted earlier attempt: first 40% on disk.
      final seedLength = (payload.length * 0.4).round();
      await partFile().writeAsBytes(payload.sublist(0, seedLength));

      final path = await AppUpdateService.downloadAndVerifyApk(info());
      expect(path, isNotNull);
      expect(await File(path!).readAsBytes(), payload);
      expect(fullRequests, 0); // never re-downloaded from zero
      expect(resumeRequests, 1);
      expect(partFile().existsSync(), isFalse);
      expect(tempDir.listSync().whereType<File>().length, 1);
    });

    test('a complete-but-unpromoted part is finished via 416 + hash check',
        () async {
      serveRangeAware();
      await partFile().writeAsBytes(payload);

      final path = await AppUpdateService.downloadAndVerifyApk(info());
      expect(path, isNotNull);
      expect(resumeRequests, 0); // server answered 416, no body sent
      expect(await File(path!).readAsBytes(), payload);
    });

    test('an interrupted download keeps its partial for the next attempt',
        () async {
      // Raw socket drops the connection after a prefix of the declared
      // body — a genuine mid-stream truncation the client observes as a
      // connection error (dart HttpServer refuses to under-send itself).
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      raw.listen((socket) async {
        socket.write('HTTP/1.1 200 OK\r\n'
            'Content-Length: ${payload.length}\r\n'
            'Connection: close\r\n\r\n');
        socket.add(payload.sublist(0, 4096));
        await socket.flush();
        await socket.close();
      });
      final rawUrl =
          Uri.parse('http://127.0.0.1:${raw.port}/apk');

      AppUpdateInfo rawInfo() => AppUpdateInfo(
            hasUpdate: true,
            currentVersion: 'v1.0.0',
            latestVersion: 'v2.0.0',
            releaseNotes: '',
            downloadUrl: rawUrl.toString(),
            expectedSha256: digest,
          );
      final first = await AppUpdateService.downloadAndVerifyApk(rawInfo());
      expect(first, isNull);
      // The interrupted partial survives for a retry.
      expect(partFile().existsSync(), isTrue);
      expect(partFile().lengthSync(), lessThan(payload.length));
      await raw.close();

      serveRangeAware();
      final second = await AppUpdateService.downloadAndVerifyApk(info());
      expect(second, isNotNull);
      expect(await File(second!).readAsBytes(), payload);
      expect(partFile().existsSync(), isFalse);
    });

    test('a corrupted partial fails closed, then a clean retry succeeds',
        () async {
      serveRangeAware();
      // Garbage prefix that does not match the real payload bytes.
      await partFile().writeAsBytes(List<int>.filled(1024, 7));

      // 206 continuation over corrupt bytes can never match the pinned
      // full-file hash → refused and cleaned up.
      final poisoned = await AppUpdateService.downloadAndVerifyApk(info());
      expect(poisoned, isNull);
      expect(partFile().existsSync(), isFalse);

      // No stale state: the next attempt re-downloads from zero fine.
      final retry = await AppUpdateService.downloadAndVerifyApk(info());
      expect(retry, isNotNull);
      expect(await File(retry!).readAsBytes(), payload);
      expect(fullRequests, 1);
    });
  });

  group('single-flight deduplication', () {
    test('concurrent identical downloads issue exactly one request', () async {
      serveRangeAware();
      final results = await Future.wait([
        AppUpdateService.downloadAndVerifyApk(info()),
        AppUpdateService.downloadAndVerifyApk(info()),
        AppUpdateService.downloadAndVerifyApk(info()),
      ]);
      expect(results.every((p) => p != null), isTrue);
      expect(fullRequests, 1);
      expect(resumeRequests, 0);
      final files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      expect(await files.single.readAsBytes(), payload);
    });

    test('a failed attempt does not poison later retries', () async {
      serveRangeAware();
      AppUpdateInfo bad() => AppUpdateInfo(
            hasUpdate: true,
            currentVersion: 'v1.0.0',
            latestVersion: 'v2.0.0',
            releaseNotes: '',
            downloadUrl: url().toString(),
            expectedSha256: crypto.sha256
                .convert(List<int>.filled(4, 0))
                .toString(),
          );
      expect(await AppUpdateService.downloadAndVerifyApk(bad()), isNull);
      // Same artifact key is free again: a fresh good attempt succeeds.
      final path = await AppUpdateService.downloadAndVerifyApk(info());
      expect(path, isNotNull);
      expect(await File(path!).readAsBytes(), payload);
    });
  });
}
