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
          if (!addr.isLoopback) return addr.address;
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

  static Future<dynamic> connectClient(String host, int port) async {
    if (kIsWeb) return null;
    try {
      final url = 'ws://$host:$port/ws';
      return await WebSocket.connect(url).timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }
}
