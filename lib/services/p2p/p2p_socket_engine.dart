import 'dart:async';
import 'dart:io';
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
      return null;
    }
  }
}
