@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/resolvers/innertube/innertube_player_api.dart';
import 'package:noctra/services/resolvers/trusted_audio_hosts.dart';

/// Live-network smoke tests for the production InnerTube cascade.
///
/// These hit real YouTube endpoints and must be run explicitly:
///   flutter test --run-skipped --tags live
void main() {
  test('resolves a known-good video to a trusted playable URL', () async {
    // Rick Astley - Never Gonna Give You Up (public, un-restricted).
    final url = await resolveInnerTubeStreamUrl('dQw4w9WgXcQ');
    expect(url, isNotNull, reason: 'known-good video must resolve');
    expect(url, startsWith('https://'));
    expect(TrustedAudioHosts.isTrusted(url), isTrue,
        reason: 'resolved stream must pass the trusted-host allowlist');
    // Direct googlevideo URL must not carry an untransformed web n-challenge.
    expect(url, isNot(contains('youtube.com/watch')));
  });

  test('cascade rejects a source-unavailable video without crashing', () async {
    // Deliberately malformed/nonexistent id — must fail cleanly and fast.
    final url = await resolveInnerTubeStreamUrl('AAAAAAAAAAA');
    expect(url, isNull);
  });

  test('visitor data endpoint returns an anonymous visitor id', () async {
    final visitor = await innerTubeFetchVisitorData();
    expect(visitor, isNotNull);
    expect(visitor, isNotEmpty);
  });
}
