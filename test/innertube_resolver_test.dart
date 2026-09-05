import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/resolvers/innertube/innertube_client_catalog.dart';
import 'package:noctra/services/resolvers/innertube/innertube_player_api.dart';
import 'package:noctra/services/resolvers/trusted_audio_hosts.dart';

/// Regression tests for the direct-URL InnerTube cascade.
///
/// Background: the previous client list (ANDROID_TESTSUITE 1.9, ANDROID_MUSIC
/// 6.42.52, WEB_REMIX 1.20240820.01.00, TVHTML5 7.20240801.12.00) was dead or
/// version-gated server-side; ANDROID_TESTSUITE was retired by YouTube in
/// 2024 and answers "not available" for every video. These tests lock the
/// replacement catalog and the pure parsing/selection logic.
void main() {
  group('InnerTubeClientCatalog', () {
    test('streamClients only contains the two pinned direct-URL clients', () {
      expect(InnerTubeClientCatalog.streamClients, hasLength(2));
      expect(InnerTubeClientCatalog.streamClients[0].clientName, 'VISIONOS');
      expect(
        InnerTubeClientCatalog.streamClients[1].clientName,
        'ANDROID_VR',
      );
      expect(InnerTubeClientCatalog.streamClients[1].clientVersion, '1.65.10');
    });

    test('retired and cipher-only clients are never in the stream cascade', () {
      final names =
          InnerTubeClientCatalog.streamClients.map((c) => c.clientName).toSet();
      expect(names, isNot(contains('ANDROID_TESTSUITE')));
      expect(names, isNot(contains('ANDROID_MUSIC')));
      expect(names, isNot(contains('WEB_REMIX')));
      expect(names, isNot(contains('TVHTML5')));
      expect(names, isNot(contains('WEB')));
    });

    test('every cascade client carries a full identity', () {
      for (final c in InnerTubeClientCatalog.streamClients) {
        expect(c.clientName, isNotEmpty);
        expect(c.clientVersion, isNotEmpty);
        expect(c.clientId, isNotEmpty);
        expect(c.userAgent, isNotEmpty);
        final ctx = c.toContextClient();
        expect(ctx['clientName'], c.clientName);
        expect(ctx['clientVersion'], c.clientVersion);
        expect(ctx.containsKey('visitorData'), isFalse);
        final ctxV = c.toContextClient('abc123');
        expect(ctxV['visitorData'], 'abc123');
      }
    });

    test('host allowlist rejects arbitrary hosts (anti host-injection)', () {
      expect(() => innerTubePlayerUri('evil.example.com'), throwsArgumentError);
      expect(
          () => innerTubePlayerUri('youtube.com.evil.io'), throwsArgumentError);
      expect(() => innerTubePlayerUri('youtube.com'), throwsArgumentError);
      final ok = innerTubePlayerUri('music.youtube.com').toString();
      expect(ok, 'https://music.youtube.com/youtubei/v1/player');
      final web = innerTubePlayerUri('www.youtube.com', action: 'player');
      expect(web.host, 'www.youtube.com');
    });
  });

  group('classifyInnerTubePlayability', () {
    test('classifies OK', () {
      expect(classifyInnerTubePlayability('OK', null), InnerTubePlayability.ok);
      expect(classifyInnerTubePlayability('ok', 'whatever'),
          InnerTubePlayability.ok);
    });

    test('classifies login-required (visitor-gated)', () {
      expect(classifyInnerTubePlayability('LOGIN_REQUIRED', null),
          InnerTubePlayability.loginRequired);
      expect(
          classifyInnerTubePlayability(
              'ERROR', "Sign in to confirm you're not a bot"),
          InnerTubePlayability.loginRequired);
    });

    test('classifies age-restricted', () {
      expect(classifyInnerTubePlayability('AGE_CHECK_REQUIRED', null),
          InnerTubePlayability.ageRestricted);
      expect(
          classifyInnerTubePlayability(
              'LOGIN_REQUIRED', 'This video is age-restricted'),
          InnerTubePlayability.ageRestricted);
    });

    test('classifies live and unavailable', () {
      expect(classifyInnerTubePlayability('LIVE_STREAM_OFFLINE', null),
          InnerTubePlayability.live);
      expect(classifyInnerTubePlayability('UNPLAYABLE', null),
          InnerTubePlayability.unavailable);
      expect(classifyInnerTubePlayability('ERROR', 'Video unavailable'),
          InnerTubePlayability.unavailable);
      expect(
          classifyInnerTubePlayability('', ''), InnerTubePlayability.unknown);
    });
  });

  group('selectBestDirectAudioUrl', () {
    test('rejects video-only and cipher-only formats', () {
      final url = selectBestDirectAudioUrl([
        {
          'mimeType': 'video/mp4; codecs="avc1.64001f"',
          'bitrate': 1000000,
          'url': 'https://rr.googlevideo.com/video',
        },
        {
          'mimeType': 'audio/webm; codecs="opus"',
          'bitrate': 130000,
          'signatureCipher': 's=abc&sp=sig&url=https://rr.googlevideo.com/x',
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 128000,
          'url': '',
        },
      ]);
      expect(url, isNull);
    });

    test('picks a direct trusted audio url only', () {
      final url = selectBestDirectAudioUrl([
        {
          'mimeType': 'video/mp4',
          'bitrate': 900000,
          'url': 'https://rr.googlevideo.com/video-only',
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 50000,
          'url': 'https://rr.googlevideo.com/low',
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 128000,
          'url': 'https://rr.googlevideo.com/high',
        },
      ]);
      expect(url, isNotNull);
      expect(url, isNot(contains('video-only')));
      expect(url, isNot(contains('/low')));
      expect(TrustedAudioHosts.isTrusted(url), isTrue);
      expect(url, startsWith('https://'));
    });

    test('rejects http and empty adaptive formats', () {
      expect(selectBestDirectAudioUrl(null), isNull);
      expect(selectBestDirectAudioUrl([]), isNull);
      expect(
        selectBestDirectAudioUrl([
          {
            'mimeType': 'audio/mp4',
            'bitrate': 128000,
            'url': 'http://rr.googlevideo.com/insecure',
          },
        ]),
        isNull,
      );
    });
  });

  group('CDN probe codes', () {
    test('accepts servable and HEAD-refused responses', () {
      expect(innerTubeProbeCodeAccepted(200), isTrue);
      expect(innerTubeProbeCodeAccepted(206), isTrue);
      expect(innerTubeProbeCodeAccepted(405), isTrue);
    });

    test('rejects dead/expired URLs', () {
      expect(innerTubeProbeCodeAccepted(403), isFalse);
      expect(innerTubeProbeCodeAccepted(404), isFalse);
      expect(innerTubeProbeCodeAccepted(410), isFalse);
      expect(innerTubeProbeCodeAccepted(429), isFalse);
    });
  });

  group('resolveInnerTubeStreamUrl guards', () {
    test('rejects malformed video ids without any network work', () async {
      expect(await resolveInnerTubeStreamUrl('short'), isNull);
      expect(await resolveInnerTubeStreamUrl(''), isNull);
      expect(await resolveInnerTubeStreamUrl('has_underscores!x'), isNull);
      expect(
          await resolveInnerTubeStreamUrl(
              'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
          isNull);
    });
  });
}
