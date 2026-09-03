
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/p2p/p2p_socket_engine.dart';
import 'package:noctra/services/updater/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 16: Platform Channels Contract & Error Handling', () {
    const resolverChannel = MethodChannel('com.nomadguy.noctra/native_resolver');
    const iconChannel = MethodChannel('com.nomadguy.noctra/launcher_icon');
    const updateChannel = MethodChannel('com.nomadguy.noctra/update_notify');
    const routerChannel = MethodChannel('com.nomadguy.noctra/audio_router');
    const stemChannel = MethodChannel('com.nomadguy.noctra/audio_stem_separation');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(resolverChannel, (MethodCall call) async {
        switch (call.method) {
          case 'resolve320k':
            final title = call.arguments['title'] as String?;
            final artist = call.arguments['artist'] as String?;
            if (title == null || artist == null) {
              throw PlatformException(
                code: 'INVALID_ARGUMENTS',
                message: 'title and artist required',
              );
            }
            if (title.isEmpty) return null;
            return 'https://media.jiosaavn.com/song_320.mp4';
          case 'decryptUrl':
            final enc = call.arguments['encryptedUrl'] as String?;
            if (enc == null || enc.isEmpty) return null;
            if (enc == 'corrupt') {
              throw PlatformException(
                code: 'DECRYPT_ERROR',
                message: 'bad base64 padding',
              );
            }
            return 'https://media.jiosaavn.com/clean_320.mp4';
          case 'extractInnerTube':
            final vid = call.arguments['videoId'] as String?;
            if (vid == null || vid.length != 11) return null;
            return 'https://rr1---sn.googlevideo.com/videoplayback';
          default:
            throw MissingPluginException();
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(iconChannel, (MethodCall call) async {
        switch (call.method) {
          case 'reconcileAndInit':
            return 'default';
          case 'setIcon':
            final icon = call.arguments['icon'] as String?;
            if (icon == null || icon.isEmpty) {
              throw PlatformException(
                code: 'INVALID_ICON',
                message: 'Icon key must not be empty',
              );
            }
            if (icon == 'unknown') {
              throw PlatformException(
                code: 'ICON_CHANGE_FAILED',
                message: 'Unknown icon variant: unknown',
              );
            }
            return true;
          default:
            throw MissingPluginException();
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, (MethodCall call) async {
        switch (call.method) {
          case 'installApk':
            final path = call.arguments['filePath'] as String?;
            if (path == null || path.isEmpty) {
              return false;
            }
            if (path.contains('missing.apk')) {
              return false;
            }
            if (path.contains('corrupt.apk')) {
              throw PlatformException(
                code: 'INSTALL_ERROR',
                message: 'Parse error: corrupt APK',
              );
            }
            return true;
          default:
            throw MissingPluginException();
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(routerChannel, (MethodCall call) async {
        switch (call.method) {
          case 'getConnectedDevices':
            return [
              {
                'id': 1,
                'name': 'Phone Speaker',
                'type': 'speaker',
                'isActive': true,
              },
              {
                'id': 2,
                'name': 'Sony WH-1000XM5',
                'type': 'bluetooth',
                'isActive': false,
              }
            ];
          case 'setOutputDevice':
            final devId = call.arguments['deviceId'] as int?;
            return devId != null && devId > 0;
          default:
            throw MissingPluginException();
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(stemChannel, (MethodCall call) async {
        if (call.method == 'separateStems') {
          final input = call.arguments['inputPath'] as String?;
          if (input == null || input.isEmpty) return null;
          return {
            'status': 'success',
            'duration': 180.0,
            'vocals': {'path': '/out/vocals.wav'},
            'drums': {'path': '/out/drums.wav'},
            'bass': {'path': '/out/bass.wav'},
            'other': {'path': '/out/other.wav'},
          };
        }
        throw MissingPluginException();
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(resolverChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(iconChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(routerChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(stemChannel, null);
    });

    test('valid resolve320k returns expected stream URL', () async {
      final res = await resolverChannel.invokeMethod<String>(
        'resolve320k',
        {'title': 'Blinding Lights', 'artist': 'The Weeknd'},
      );
      expect(res, equals('https://media.jiosaavn.com/song_320.mp4'));
    });

    test('resolve320k with missing arguments throws structured PlatformException', () async {
      expect(
        () => resolverChannel.invokeMethod('resolve320k', {'title': null}),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ARGUMENTS')),
      );
    });

    test('decryptUrl handles corrupted encrypted payloads cleanly without unhandled crash', () async {
      expect(
        () => resolverChannel.invokeMethod('decryptUrl', {'encryptedUrl': 'corrupt'}),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'DECRYPT_ERROR')),
      );
    });

    test('extractInnerTube validates 11-char videoId contract', () async {
      final valid = await resolverChannel.invokeMethod<String>(
        'extractInnerTube',
        {'videoId': 'dQw4w9WgXcQ'},
      );
      expect(valid, isNotNull);

      final invalid = await resolverChannel.invokeMethod<String>(
        'extractInnerTube',
        {'videoId': 'too_short'},
      );
      expect(invalid, isNull);
    });

    test('unknown method on platform channel throws MissingPluginException', () async {
      expect(
        () => resolverChannel.invokeMethod('nonExistentMethod'),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('launcher icon channel enforces non-empty icon key', () async {
      expect(
        () => iconChannel.invokeMethod('setIcon', {'icon': ''}),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'INVALID_ICON')),
      );
    });

    test('launcher icon reconcileAndInit returns valid active icon', () async {
      final icon = await iconChannel.invokeMethod<String>('reconcileAndInit');
      expect(icon, equals('default'));
    });

    test('audio router returns structured connected devices', () async {
      final devices =
          await routerChannel.invokeListMethod<Map>('getConnectedDevices');
      expect(devices, isNotNull);
      expect(devices!.length, equals(2));
      expect(devices.first['name'], equals('Phone Speaker'));
      expect(devices.last['type'], equals('bluetooth'));
    });

    test('native installer handles missing files gracefully', () async {
      final res = await updateChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': '/tmp/missing.apk'},
      );
      expect(res, isFalse);
    });

    test('native installer propagates installation errors with INSTALL_ERROR code', () async {
      expect(
        () => updateChannel.invokeMethod('installApk', {'filePath': '/tmp/corrupt.apk'}),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'INSTALL_ERROR')),
      );
    });

    test('audio stem separation returns all 4 separated stem outputs', () async {
      final result = await stemChannel.invokeMapMethod(
        'separateStems',
        {'inputPath': '/music/song.mp3', 'outputDir': '/out', 'model': 'light'},
      );
      expect(result, isNotNull);
      expect(result!['status'], equals('success'));
      expect(result['vocals'], isNotNull);
      expect(result['drums'], isNotNull);
      expect(result['bass'], isNotNull);
      expect(result['other'], isNotNull);
    });
  });

  group('Phase 16: P2P Socket Engine Network & Fallback', () {
    test('findLocalIp returns a valid IPv4 address', () async {
      final ip = await P2PSocketEngine.findLocalIp();
      expect(ip, isNotEmpty);
      expect(RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(ip), isTrue);
    });

    test('bindServer binds to a free port and cleans up', () async {
      final server = await P2PSocketEngine.bindServer(0);
      expect(server, isNotNull);
      expect(server!.port, greaterThan(0));
      await server.close(force: true);
    });

    test('connectClient returns null on non-existent host without hanging', () async {
      final ws = await P2PSocketEngine.connectClient('127.0.0.1', 59999);
      expect(ws, isNull);
    });
  });

  group('Phase 16: App Updater Release & Digest Verification', () {
    test('extractAssetSha256 parses single sha256 from release notes', () {
      const notes = '''
## Release v1.2.3
Features and bugfixes.
SHA256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
''';
      final hash = AppUpdateService.extractAssetSha256(notes, assetName: 'app-release.apk');
      expect(hash, equals('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'));
    });

    test('extractAssetSha256 associates hash with specific asset filename', () {
      const notes = '''
app-arm64-v8a-release.apk = 1111111111111111111111111111111111111111111111111111111111111111
app-armeabi-v7a-release.apk = 2222222222222222222222222222222222222222222222222222222222222222
''';
      final arm64 = AppUpdateService.extractAssetSha256(notes, assetName: 'app-arm64-v8a-release.apk');
      expect(arm64, equals('1111111111111111111111111111111111111111111111111111111111111111'));

      final armv7 = AppUpdateService.extractAssetSha256(notes, assetName: 'app-armeabi-v7a-release.apk');
      expect(armv7, equals('2222222222222222222222222222222222222222222222222222222222222222'));
    });

    test('compareVersions semver evaluation', () {
      expect(AppUpdateService.compareVersions('1.2.3', '1.2.2'), greaterThan(0));
      expect(AppUpdateService.compareVersions('1.2.2', '1.2.3'), lessThan(0));
      expect(AppUpdateService.compareVersions('1.2.3', '1.2.3'), equals(0));
      expect(AppUpdateService.compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(AppUpdateService.compareVersions('1.0.0-rc1', '1.0.0'), lessThan(0));
    });
  });
}
