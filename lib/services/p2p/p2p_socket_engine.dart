import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class P2PSocketEngine {
  static Future<String> findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              !addr.isLinkLocal &&
              addr.address != '0.0.0.0') {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static Future<HttpServer?> bindServer(int port) async {
    if (kIsWeb) return null;
    try {
      return await HttpServer.bind(InternetAddress.anyIPv4, port);
    } catch (_) {
      return null;
    }
  }

  /// Open a raw WebSocket to a host's Jam endpoint.
  ///
  /// Authentication happens AFTER the upgrade via an in-band
  /// challenge/response handshake (see [P2PSyncService]); the room secret
  /// is therefore NEVER placed in a header or URL, where it could be
  /// captured from logs or sniffed off the wire in reusable form. Returns
  /// the socket on success, or null on refusal/timeout/failure.
  static Future<dynamic> connectClient(String host, int port) async {
    if (kIsWeb) return null;
    try {
      final trimmed = host.trim();
      if (trimmed.isEmpty) return null;
      final isIpv6 = trimmed.contains(':');
      final url =
          isIpv6 ? 'ws://[$trimmed]:$port/ws' : 'ws://$trimmed:$port/ws';
      return await WebSocket.connect(url).timeout(const Duration(seconds: 5));
    } catch (_) {
      try {
        return await _connectRawWebSocket(host, port)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        return null;
      }
    }
  }

  static Future<WebSocket?> _connectRawWebSocket(String host, int port) async {
    final trimmed = host.trim();
    if (trimmed.isEmpty) return null;
    final socket = await Socket.connect(trimmed, port);
    final rng = Random.secure();
    final keyBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final secKey = base64Encode(keyBytes);

    final request = 'GET /ws HTTP/1.1\r\n'
        'Host: $trimmed:$port\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: $secKey\r\n'
        'Sec-WebSocket-Version: 13\r\n\r\n';

    socket.add(utf8.encode(request));
    await socket.flush();

    final buffer = <int>[];
    final completer = Completer<WebSocket?>();

    late StreamSubscription<List<int>> sub;
    sub = socket.listen(
      (data) {
        buffer.addAll(data);
        final str = String.fromCharCodes(buffer);
        final headerEnd = str.indexOf('\r\n\r\n');
        if (headerEnd != -1) {
          sub.cancel();
          final headerPart = str.substring(0, headerEnd);
          if (headerPart.contains('101 Switching Protocols') ||
              headerPart.contains('101 Web Socket Protocol Handshake')) {
            try {
              final ws =
                  WebSocket.fromUpgradedSocket(socket, serverSide: false);
              if (!completer.isCompleted) completer.complete(ws);
            } catch (_) {
              socket.destroy();
              if (!completer.isCompleted) completer.complete(null);
            }
          } else {
            socket.destroy();
            if (!completer.isCompleted) completer.complete(null);
          }
        }
      },
      onError: (_) {
        socket.destroy();
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(null);
      },
      cancelOnError: true,
    );

    return completer.future;
  }
}
