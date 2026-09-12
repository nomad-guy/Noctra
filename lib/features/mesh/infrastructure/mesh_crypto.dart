import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Speaker Mesh — standalone crypto helpers for the join handshake.
///
/// Mirrors Jam's proven scheme (HMAC-SHA256 challenge/response, constant-time
/// compare, CSPRNG secrets) as public functions so the mesh transport is
/// self-contained and Jam's private implementation stays untouched.
class MeshCrypto {
  MeshCrypto._();

  /// Cryptographically strong room secret: 8 base32 chunks (~190 bits).
  static String generateRoomSecret() {
    final rng = Random.secure();
    const alphabet = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';
    String chunk() =>
        List.generate(5, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
    return '${chunk()}-${chunk()}-${chunk()}-${chunk()}-'
        '${chunk()}-${chunk()}-${chunk()}-${chunk()}';
  }

  /// Constant-time equality (no timing oracles during secret verification).
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// HMAC-SHA256([key], [message]) hex-encoded. The room secret never
  /// crosses the wire — only its MAC of a server-issued one-time nonce.
  static String hmacHex(String key, String message) {
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(message)).toString();
  }

  /// Random 32-byte challenge nonce (base64url), per connection.
  static String randomNonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
