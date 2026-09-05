import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/resolvers/stream_resolver.dart';

/// Regression tests for the substring-matching bypass that
/// `DirectOpenStreamResolver` previously used. The old code did
/// `url.contains('scdn.co')` etc., which an attacker can defeat
/// by hosting a malicious file on a path that includes the
/// forbidden substring, e.g. `https://attacker.com/scdn.co/x`.
/// The new contract is: parse the URL, match the *host* against
/// the trusted allowlist, and reject hosts in the known-bad
/// suffixes — never on substring presence in the path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectOpenStreamResolver.canResolve', () {
    final resolver = DirectOpenStreamResolver();

    Future<bool> canResolveWith(String url) async {
      final song = Song(
        id: 'x',
        title: 't',
        artist: 'a',
        duration: const Duration(seconds: 1),
        streamUrl: url,
      );
      return await resolver.canResolve(song);
    }

    test('accepts a trusted host', () async {
      expect(await canResolveWith('https://aac.saavncdn.com/foo.mp4'), isTrue);
    });

    test('rejects a path-based substring attack', () async {
      // The URL is on `attacker.com`; the old code would have
      // flagged it as bad because of `scdn.co` substring, but the
      // new code must not over-match. Equally, an attacker who
      // puts `youtube.com` in the path must still be rejected
      // because the host is untrusted.
      expect(
          await canResolveWith('https://attacker.com/scdn.co/x.mp4'), isFalse);
    });

    test('rejects an attacker who embeds the trusted host as a suffix',
        () async {
      // `notyoutube.com` is not in the trusted list. The new
      // contract uses the parsed host, not substring search, so
      // this URL must be rejected.
      expect(
          await canResolveWith('https://notyoutube.com/watch?v=abc'), isFalse);
    });

    test('rejects known-bad suffixes even if the host is untrusted', () async {
      // The attacker controls `scdn.co` directly in this test —
      // obviously rejected.
      expect(await canResolveWith('https://scdn.co/track.mp3'), isFalse);
    });

    test('rejects YouTube watch pages (never direct audio streams)',
        () async {
      // A watch page needs InnerTube/yt-dlp resolution; handing it to
      // the direct player would attempt to stream an HTML page.
      expect(
          await canResolveWith('https://www.youtube.com/watch?v=abc123def45'),
          isFalse);
      expect(await canResolveWith('https://youtu.be/abc123def45'), isFalse);
      // But an actual audio CDN host stays accepted.
      expect(
          await canResolveWith('https://rr2---sn-a5mekn6e.googlevideo.com/x'),
          isTrue);
    });

    test('rejects null/empty streamUrl', () async {
      final song = Song(
        id: 'x',
        title: 't',
        artist: 'a',
        duration: const Duration(seconds: 1),
      );
      expect(await resolver.canResolve(song), isFalse);
    });

    test('rejects non-HTTPS URLs', () async {
      // The allowlist only accepts https; http must be refused.
      expect(
        await canResolveWith('http://aac.saavncdn.com/foo.mp4'),
        isFalse,
      );
    });
  });
}
