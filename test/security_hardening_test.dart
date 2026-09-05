import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/core/utils/path_safe_identifier.dart';
import 'package:noctra/services/audio/audio_stem_separation_service.dart';
import 'package:noctra/services/lyrics/parts/lyrics_provider_fallback.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';
import 'package:noctra/services/updater/app_update_service.dart';
import 'p2p_test_helpers.dart';

/// Phase 21 regression tests: trust-boundary hardening.
///
/// Background findings:
///  * Song ids are attacker-influenced (Jam peers may send arbitrary ids,
///    metadata/resolver providers may be compromised). Several storage
///    paths interpolated `songId` verbatim (`NoctraStems/<songId>`,
///    `stem_input_<songId>.wav`), so a hostile id like `../../databases/x`
///    could create/delete directories outside the intended folder — e.g.
///    recursive deletion of the app's own database directory via
///    deleteStems(). All such paths now funnel the id through
///    [safePathSegment].
///  * The in-app updater accepted remote-controlled download URLs for the
///    "open in browser" / notification paths; update metadata is fetched
///    over TLS, but a defense-in-depth https-only coercion now applies.
///  * The JioSaavn lyrics fallback interpolated the song id raw into the
///    query string; it is now percent-encoded.
void main() {
  group('safePathSegment', () {
    test('neutralizes path traversal separators and dot segments', () {
      const hostile = [
        '../../databases/evil',
        '..\\..\\databases\\evil',
        '..',
        '.',
        '/etc/passwd',
        'C:\\absolute\\path',
        '..%2e%2e/..',
        'a/b\\c',
      ];
      for (final input in hostile) {
        final seg = safePathSegment(input);
        expect(seg, isNotEmpty, reason: 'input: $input');
        expect(seg.contains('/'), isFalse, reason: 'input: $input -> $seg');
        expect(seg.contains('\\'), isFalse, reason: 'input: $input -> $seg');
        expect(seg, isNot('..'), reason: 'input: $input');
        expect(seg, isNot('.'), reason: 'input: $input');
        expect(isSafePathSegment(seg), isTrue, reason: 'input: $input -> $seg');
      }
      expect(safePathSegment('..'), 'segment');
    });

    test('keeps legitimate source ids intact', () {
      for (final id in [
        'dQw4w9WgXcQ', // YouTube
        'itunes_1456342913', // iTunes store
        'lrc_20210501_1', // LRC search
        'JioSaavn_song_123', // JioSaavn style
        'remote-1',
        'yt_abc123_-', // base64url-style
      ]) {
        expect(safePathSegment(id), id);
        expect(isSafePathSegment(id), isTrue);
      }
    });

    test('bounds length and collapses repeated underscores', () {
      final long = 'a' * 500;
      final seg = safePathSegment(long);
      expect(seg.length, lessThanOrEqualTo(80));
      expect(seg.contains('__'), isFalse);

      final crushed = safePathSegment('a///b  c\t\n');
      expect(crushed, 'a_b_c');
    });

    test('is deterministic', () {
      const input = '../../weird id/../x';
      expect(safePathSegment(input), safePathSegment(input));
    });
  });

  group('stem separation paths', () {
    test('stemDirName maps hostile ids to single safe components', () {
      for (final input in [
        '../../databases/evil',
        '..\\..\\databases\\evil',
        '..',
        '/etc/passwd',
        'a/b\\c',
      ]) {
        final dirName = AudioStemSeparationService.stemDirName(input);
        expect(dirName, isNotEmpty);
        expect(dirName.contains('/'), isFalse, reason: '$input -> $dirName');
        expect(dirName.contains('\\'), isFalse, reason: '$input -> $dirName');
        expect(dirName, isNot('..'));
        expect(dirName, isNot('.'));
        expect(isSafePathSegment(dirName), isTrue,
            reason: '$input -> $dirName');
      }
    });

    test('the resulting directory always stays inside NoctraStems', () {
      // Simulate the service's path construction for an app dir so the
      // containment invariant is pinned without needing platform plugins.
      const appDir = '/data/data/com.nomadguy.noctra/app_flutter';
      for (final input in ['../../databases/evil', '..', 'x/y\\z']) {
        final path =
            '$appDir/NoctraStems/${AudioStemSeparationService.stemDirName(input)}';
        expect(path.startsWith('$appDir/NoctraStems/'), isTrue,
            reason: '$input -> $path');
        expect(path, isNot(contains('/../')));
        expect(path, isNot(contains('/..\\')));
      }
    });
  });

  group('update URL coercion', () {
    test('accepts legitimate https github URLs unchanged', () {
      const ok =
          'https://github.com/nomad-guy/Noctra/releases/download/v1/noctra.apk';
      expect(AppUpdateService.coerceHttpsDownloadUrl(ok), ok);
      expect(
        AppUpdateService.coerceHttpsDownloadUrl(
            'https://objects.githubusercontent.com/x/noctra.apk'),
        isNot(''),
      );
    });

    test('rejects non-https and custom schemes with the https fallback', () {
      const fallback = AppUpdateService.fallbackDownloadUrl;
      for (final bad in [
        'http://evil.example/noctra.apk',
        'intent://evil.example/#Intent;scheme=https;end',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'ftp://github.com/x.apk',
        'https://', // empty host
        'not a url',
        '',
      ]) {
        final coerced = AppUpdateService.coerceHttpsDownloadUrl(bad);
        expect(coerced, fallback, reason: 'input: $bad');
        expect(Uri.parse(coerced).scheme, 'https');
        expect(coerced, isNot(bad));
      }
    });
  });

  group('Jam wire song ids', () {
    late P2PSyncService host;

    setUp(() async {
      P2PSyncService.inboundWindowMs = 2000;
      P2PSyncService.inboundLimitPerWindow = 40;
      P2PSyncService.chatWindowMs = 2000;
      P2PSyncService.chatLimitPerWindow = 12;
      P2PSyncService.authFailLimit = 6;
      P2PSyncService.authFailWindowMs = 30000;
      host = P2PSyncService.newForTest();
    });

    tearDown(() async {
      await host.stopParty();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });

    test('hostile traversal song ids are reduced to one safe component',
        () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);

      // A peer-supplied id must never survive as a path-traversal payload:
      // these ids later feed filesystem paths (stem dirs, temp download
      // names) on the receiving device.
      for (final hostile in [
        '../../databases/evil',
        '..\\..\\databases\\evil',
        '..',
        '/etc/passwd',
        'C:\\absolute\\path',
      ]) {
        ws.add(jsonEncode({
          'type': 'add_to_queue',
          'song': {'id': hostile, 'title': 'T', 'artist': 'A'}
        }));
      }
      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {'id': 'normal-id', 'title': 'T', 'artist': 'A'}
      }));
      expect(
          await waitFor(
              () => host.collaborativeQueue.any((s) => s.id == 'normal-id')),
          isTrue);
      for (final song in host.collaborativeQueue) {
        expect(song.id.contains('/'), isFalse, reason: song.id);
        expect(song.id.contains('\\'), isFalse, reason: song.id);
        expect(song.id, isNot('..'));
        expect(song.id, isNot('.'));
        expect(song.id.isEmpty, isFalse);
      }
      await ws.close();
    });

    test('a benign wire id is preserved verbatim', () async {
      expect(await host.startHost(port: 0), isTrue);
      final ws = await connectRaw(host);
      ws.add(jsonEncode({
        'type': 'add_to_queue',
        'song': {'id': 'remote-1', 'title': 'T', 'artist': 'A'}
      }));
      expect(await waitFor(() => host.collaborativeQueue.isNotEmpty), isTrue);
      expect(host.collaborativeQueue.first.id, 'remote-1');
      await ws.close();
    });
  });

  group('lyrics endpoint URIs', () {
    test('song id is percent-encoded and cannot smuggle parameters', () {
      final uri = LyricsProviderFallback.jioSaavnLyricsUri('123&evil=1');
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.jiosaavn.com');
      expect(uri.queryParameters['__call'], 'lyrics.getLyrics');
      // Raw '&' must not appear as a parameter separator from the id.
      final rawQuery = uri.query;
      expect(rawQuery.contains('lyrics_id=123&evil=1'), isFalse);
      expect(uri.queryParameters['lyrics_id'], '123&evil=1');
      expect(uri.queryParameters.containsKey('evil'), isFalse);
    });
  });
}
