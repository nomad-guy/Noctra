import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'package:noctra/features/discovery/infrastructure/jiosaavn_pure_engine.dart';
import 'package:noctra/services/resolvers/innertube/innertube_player_api.dart';
import 'package:noctra/services/resolvers/trusted_audio_hosts.dart';

/// LIVE-NETWORK diagnostic probe for the download pipeline (tag: live).
///
/// IMPORTANT: deliberately does NOT call TestWidgetsFlutterBinding —
/// that binding mocks every HTTP request to status 400. Real sockets are
/// the entire point of this probe.
///
/// Runs each stage of the resolution chain directly with the failure visible
/// instead of swallowed, to locate where downloads actually die:
///   1. JioSaavn search API reachability + parsing + decrypt
///   2. JioSaavn CDN URL reachability (HEAD)
///   3. InnerTube /player direct-URL cascade (visionOS + ANDROID_VR)
///   4. googlevideo CDN reachability of whatever InnerTube returns
void main() {
  test('probe: JioSaavn search + decrypt + CDN reachable', tags: 'live', () async {
    final results = await JioSaavnPureEngine.searchSongs('kesariya', limit: 5);
    expect(results, isNotEmpty, reason: 'JioSaavn search returned zero results');
    final first = results.first;
    final streamUrl = first['stream_url'] as String? ?? '';
    expect(
      streamUrl,
      isNotEmpty,
      reason: 'decryptMediaUrl produced empty stream_url for ${first['id']}',
    );
    expect(
      TrustedAudioHosts.isTrusted(streamUrl),
      isTrue,
      reason: 'Decrypted URL not trusted: $streamUrl',
    );
    final client = IOClient(HttpClient());
    try {
      final head = await client
          .head(
            Uri.parse(streamUrl),
            headers: {'Range': 'bytes=0-1', 'User-Agent': 'Mozilla/5.0'},
          )
          .timeout(const Duration(seconds: 8));
      expect(
        head.statusCode,
        isIn([200, 206]),
        reason: 'JioSaavn CDN rejected HEAD: HTTP ${head.statusCode}',
      );
    } finally {
      client.close();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('probe: InnerTube direct-URL cascade resolves a known video', tags: 'live', () async {
    // Stable, well-known music video id.
    const videoId = 'BddP6PYo2gs';
    final url = await resolveInnerTubeStreamUrl(
      videoId,
      perRequestTimeout: const Duration(seconds: 8),
    );
    expect(
      url,
      isNotNull,
      reason: 'InnerTube cascade returned null for $videoId '
          '(visionOS/ANDROID_VR clients may be gated — check catalog pins)',
    );
    if (url != null) {
      final client = http.Client();
      try {
        final head = await client
            .head(Uri.parse(url),
                headers: {'Range': 'bytes=0-1', 'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: 8));
        expect(
          head.statusCode,
          isIn([200, 206, 403]),
          reason: 'googlevideo CDN responded HTTP ${head.statusCode}',
        );
      } finally {
        client.close();
      }
    }
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('probe: raw InnerTube /player response visibility', tags: 'live', () async {
    const videoId = 'BddP6PYo2gs';
    // ignore: const_eval_throwsException
    final client = InnerTubeClientSpecProbe();
    final body = jsonEncode({
      'videoId': videoId,
      'context': {'client': client.context},
    });
    final res = await http
        .post(
          Uri.parse('https://music.youtube.com/youtubei/v1/player'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': client.userAgent,
            'X-YouTube-Client-Name': client.clientId,
            'X-YouTube-Client-Version': client.clientVersion,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 8));
    final decoded = res.statusCode == 200
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final playability =
        (decoded['playabilityStatus'] as Map?)?['status']?.toString();
    final formats = (decoded['streamingData'] as Map?)?['adaptiveFormats']
            as List? ??
        const [];
    // Diagnostic output: this is a probe, not a strict contract.
    // ignore: avoid_print
    print('HTTP ${res.statusCode} playability=$playability '
        'formats=${formats.length} '
        'directUrls=${formats.where((f) => (f as Map)['url'] != null).length}');
    expect(res.statusCode, 200, reason: 'music.youtube.com unreachable');
  }, timeout: const Timeout(Duration(seconds: 20)));
}

/// Minimal inline client spec so the probe does not depend on internals.
class InnerTubeClientSpecProbe {
  final context = <String, Object?>{
    'clientName': 'ANDROID_VR',
    'clientVersion': '1.65.10',
    'osName': 'Android',
    'osVersion': '12L',
    'deviceMake': 'Oculus',
    'deviceModel': 'Quest 3',
    'androidSdkVersion': 32,
  };
  final clientId = '28';
  final clientVersion = '1.65.10';
  final userAgent =
      'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android '
      '12L; eureka-user Build/SQ3A.220605.009.A1) gzip';
}
