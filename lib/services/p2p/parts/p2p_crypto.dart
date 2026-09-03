part of '../p2p_sync_service.dart';

/// Cryptographically strong room secret generator. Produces 8
/// alphanumeric chunks separated by `-` for human-readable entry
/// without sacrificing entropy. Total entropy ~190 bits — effectively
/// unguessable on a LAN.
String _generateRoomSecret() {
  final rng = Random.secure();
  // RFC4648 base32 alphabet (no I/L/O/U to avoid confusion).
  const alphabet = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';
  String chunk() => List.generate(
        5,
        (_) => alphabet[rng.nextInt(alphabet.length)],
      ).join();
  return '${chunk()}-${chunk()}-${chunk()}-${chunk()}-${chunk()}-'
      '${chunk()}-${chunk()}-${chunk()}';
}

/// Constant-time string equality to prevent timing oracles during
/// room-secret verification.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// HMAC-SHA256 of [message] keyed by [key], hex-encoded. Used by the
/// challenge/response authentication handshake so the raw room secret is
/// never transmitted over the wire and a captured response is bound to the
/// server-issued one-time nonce (not replayable against a later challenge).
String _hmacHex(String key, String message) {
  final hmac = Hmac(sha256, utf8.encode(key));
  return hmac.convert(utf8.encode(message)).toString();
}

/// Random 32-byte challenge nonce (base64url). Generated per connection by
/// the host; the client proves knowledge of the room secret by MACing it.
String _randomNonce() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64UrlEncode(bytes);
}

/// Legacy display-only room code. Authentication uses [_roomSecret].
String _generateRoomCode() {
  final rng = Random.secure();
  return 'JAM-${1000 + rng.nextInt(9000)}';
}

bool _isValidHostOrIp(String host) {
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return true;
  }
  // Hostnames (.local, .lan, alphanumeric)
  if (RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(host) && !host.contains('..')) {
    // If looks like IPv4, validate strictly
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) {
      final parts = host.split('.');
      if (parts.length != 4) return false;
      int first = 0, second = 0;
      for (int i = 0; i < 4; i++) {
        final n = int.tryParse(parts[i]);
        if (n == null || n < 0 || n > 255) return false;
        if (i == 0) first = n;
        if (i == 1) second = n;
      }
      // Rejects broadcast and link-local address ranges on join attempt
      if (first == 0 || first == 255) return false;
      if (first == 169 && second == 254) return false; // RFC 3927 link-local
    }
    return true;
  }
  // Bracketed IPv6 (e.g., [fe80::1])
  if (host.startsWith('[') && host.endsWith(']')) {
    final inner = host.substring(1, host.length - 1);
    return Uri.parseIPv6Address(inner).isNotEmpty;
  }
  return false;
}
