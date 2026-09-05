import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/utils/noctra_logger.dart';
import '../trusted_audio_hosts.dart';
import 'innertube_client_catalog.dart';
import 'innertube_response.dart';

export 'innertube_response.dart';

/// Hosts this module is allowed to POST InnerTube requests to. Everything
/// else is rejected — defense in depth against host injection.
const Set<String> _allowedInnerTubeHosts = {
  'music.youtube.com',
  'www.youtube.com',
};

/// Maximum accepted response body for a `/player` call.
const int _maxPlayerResponseBytes = 5 * 1024 * 1024;

/// Visitor-data cache (refreshed lazily; YouTube visitor ids are long-lived).
String? _cachedVisitorData;
int _cachedVisitorAtMs = 0;
const int _visitorTtlMs = 6 * 60 * 60 * 1000;

/// Builds the endpoint URI for an InnerTube action, validating [host].
Uri innerTubePlayerUri(String host, {String action = 'player'}) {
  if (!_allowedInnerTubeHosts.contains(host)) {
    throw ArgumentError.value(host, 'host', 'Unsupported InnerTube host');
  }
  return Uri.parse('https://$host/youtubei/v1/$action');
}

/// True when a CDN probe response code means "this URL is servable".
/// 405 (HEAD refused) is accepted: the resource exists, ExoPlayer's GET works.
bool innerTubeProbeCodeAccepted(int code) =>
    code == 200 || code == 206 || code == 405;

/// Lightweight CDN validation: HEAD with a byte Range matching the first
/// chunk ExoPlayer requests. Network failures accept optimistically (let the
/// player attempt a GET rather than burning a fallback client).
Future<bool> innerTubeProbeUrl(String url) async {
  if (kIsWeb) return true;
  if (!TrustedAudioHosts.isTrusted(url)) return false;
  try {
    final client = http.Client();
    try {
      final res = await client.head(
        Uri.parse(url),
        headers: const {'Range': 'bytes=0-524287'},
      ).timeout(const Duration(seconds: 3));
      return innerTubeProbeCodeAccepted(res.statusCode);
    } finally {
      client.close();
    }
  } catch (_) {
    return true;
  }
}

/// One typed `/player` request against [host] with [client]'s identity.
Future<InnerTubePlayerData?> innerTubeFetchPlayer({
  required String videoId,
  required InnerTubeClientConfig client,
  required String host,
  String? visitorData,
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (videoId.length != 11) return null;
  final body = jsonEncode({
    'videoId': videoId,
    'context': {'client': client.toContextClient(visitorData)},
  });
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'User-Agent': client.userAgent,
    'X-Goog-Api-Format-Version': '1',
    'X-YouTube-Client-Name': client.clientId,
    'X-YouTube-Client-Version': client.clientVersion,
    'Origin': 'https://$host',
    'Referer': 'https://$host/',
    if (visitorData != null && visitorData.isNotEmpty)
      'X-Goog-Visitor-Id': visitorData,
  };
  try {
    final res = await http
        .post(innerTubePlayerUri(host), headers: headers, body: body)
        .timeout(timeout);
    if (res.statusCode != 200) return null;
    if (res.bodyBytes.length > _maxPlayerResponseBytes) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    final ps = decoded['playabilityStatus'];
    final sd = decoded['streamingData'];
    return InnerTubePlayerData(
      playability: classifyInnerTubePlayability(
        (ps is Map) ? ps['status']?.toString() : null,
        (ps is Map) ? ps['reason']?.toString() : null,
      ),
      statusReason:
          (ps is Map) ? ps['reason']?.toString() : 'malformed response',
      adaptiveFormats: (sd is Map) ? sd['adaptiveFormats'] as List? : null,
      expiresInSeconds: (sd is Map && sd['expiresInSeconds'] is num)
          ? (sd['expiresInSeconds'] as num).toInt()
          : 0,
    );
  } catch (_) {
    return null;
  }
}

/// Acquires an anonymous visitor id (bound to no account) from the WEB
/// client's account menu endpoint. Used only when a client is gated.
Future<String?> innerTubeFetchVisitorData({
  Duration timeout = const Duration(seconds: 6),
}) async {
  const client = InnerTubeClientConfig(
    clientName: 'WEB',
    clientVersion: '2.20260213.00.00',
    clientId: '1',
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) '
        'Gecko/20100101 Firefox/140.0',
  );
  final body = jsonEncode({
    'context': {'client': client.toContextClient()},
  });
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'User-Agent': client.userAgent,
    'X-Goog-Api-Format-Version': '1',
    'X-YouTube-Client-Name': client.clientId,
    'X-YouTube-Client-Version': client.clientVersion,
  };
  try {
    final res = await http
        .post(
          innerTubePlayerUri('music.youtube.com',
              action: 'account/account_menu'),
          headers: headers,
          body: body,
        )
        .timeout(timeout);
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    final visitor =
        (decoded['responseContext'] as Map?)?['visitorData']?.toString();
    if (visitor == null || visitor.isEmpty) return null;
    _cachedVisitorData = visitor;
    _cachedVisitorAtMs = DateTime.now().millisecondsSinceEpoch;
    return visitor;
  } catch (_) {
    return null;
  }
}

/// Resolves a playable audio URL for [videoId] through the direct-URL client
/// cascade against [host].
///
/// Pass structure:
/// 1. Try every client with the currently cached visitorData (may be none).
/// 2. If every client failed and no visitorData was used, acquire one and
///    retry once — some networks gate these clients behind `LOGIN_REQUIRED`
///    without it. A cached visitorData older than the TTL is also refreshed
///    before the retry pass.
Future<String?> resolveInnerTubeStreamUrl(
  String videoId, {
  String host = 'music.youtube.com',
  bool probe = true,
  Duration perRequestTimeout = const Duration(seconds: 5),
}) async {
  if (videoId.length != 11) return null;
  final now = DateTime.now().millisecondsSinceEpoch;
  var visitor = _cachedVisitorData;
  var visitorUsed = false;
  String? failureReason;

  for (var pass = 0; pass < 2; pass++) {
    final clients = InnerTubeClientCatalog.streamClients;
    for (var i = 0; i < clients.length; i++) {
      final client = clients[i];
      final data = await innerTubeFetchPlayer(
        videoId: videoId,
        client: client,
        host: host,
        visitorData: visitor,
        timeout: perRequestTimeout,
      );
      if (data == null) {
        failureReason = 'request_failed';
        continue;
      }
      if (data.playability != InnerTubePlayability.ok) {
        failureReason = data.statusReason ?? data.playability.name;
        // A permanent source-level refusal applies to every client of the
        // same source — do not burn the rest of the cascade on it.
        if (data.playability == InnerTubePlayability.unavailable ||
            data.playability == InnerTubePlayability.ageRestricted ||
            data.playability == InnerTubePlayability.live) {
          return null;
        }
        continue;
      }
      final url = selectBestDirectAudioUrl(data.adaptiveFormats);
      if (url == null) {
        failureReason = 'no_direct_audio';
        continue;
      }
      // Validate every candidate except the last fallback: a rejected CDN
      // URL is worse than one more request.
      if (probe && i < clients.length - 1) {
        final accepted = await innerTubeProbeUrl(url);
        if (!accepted) {
          failureReason = 'cdn_rejected';
          continue;
        }
      }
      if (visitor != null && visitor.isNotEmpty) visitorUsed = true;
      if (visitorUsed) {
        _cachedVisitorData = visitor;
        _cachedVisitorAtMs = now;
      }
      return url;
    }

    final visitorStale =
        _cachedVisitorData == null || now - _cachedVisitorAtMs > _visitorTtlMs;
    if (visitorUsed || !visitorStale) break;
    visitor = await innerTubeFetchVisitorData(timeout: perRequestTimeout);
    if (visitor == null || visitor.isEmpty) break;
    visitorUsed = true;
  }
  NoctraLogger.d('InnerTube resolution failed for $videoId: $failureReason');
  return null;
}
