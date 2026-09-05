import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';

String hmacHex(String key, String message) {
  final hmac = Hmac(sha256, utf8.encode(key));
  return hmac.convert(utf8.encode(message)).toString();
}

Future<bool> waitFor(
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (cond()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
  return cond();
}

Future<WebSocket> connectRaw(P2PSyncService h, {String? secret}) async {
  final ws = await WebSocket.connect('ws://127.0.0.1:${h.boundPort}/ws')
      .timeout(const Duration(seconds: 3));
  final handshake = Completer<void>();
  var answered = false;
  ws.listen((dynamic d) {
    if (!answered) {
      answered = true;
      try {
        final obj = jsonDecode(d as String) as Map<String, dynamic>;
        if (obj['type'] == 'jam_auth_challenge' && obj['nonce'] is String) {
          ws.add(jsonEncode({
            'type': 'jam_auth_response',
            'response':
                hmacHex(secret ?? h.roomSecret, obj['nonce'] as String),
          }));
        }
      } catch (_) {}
      if (!handshake.isCompleted) handshake.complete();
    }
  }, onDone: () {
    if (!handshake.isCompleted) handshake.complete();
  });
  await handshake.future.timeout(const Duration(seconds: 4));
  return ws;
}
