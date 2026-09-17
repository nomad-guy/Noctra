import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/noctra_logger.dart';

/// Observed network quality bucket, derived from a lightweight RTT probe.
enum NetworkQuality {
  /// No connectivity (airplane mode, dead Wi-Fi).
  offline,

  /// RTT > 1500ms or probe failed on an "online" interface — 2G / congested.
  poor,

  /// RTT 400–1500ms — ordinary mobile data.
  fair,

  /// RTT < 400ms — good Wi-Fi / 4G+.
  good,
}

/// Single shared probe host used for RTT measurement. Small, CORS-free,
/// globally CDN-distributed, and unlikely to be blocked.
const _probeHosts = [
  'https://www.google.com/generate_204',
  'https://www.jiosaavn.com/favicon.ico',
];

/// One authoritative owner for network state across the app.
///
/// Consumers:
///  - StreamQualityService: Smart policy downgrades quality on mobile/poor.
///  - Adaptive timeouts: every provider request scales by [timeoutScale].
///  - Offline UX: widgets can show an offline banner.
///
/// The probe fires at startup and refreshes on connectivity change + every
/// 5 minutes while online. Probes are cheap HEAD/GET-204 requests (~1 byte).
class NetworkQualityService {
  NetworkQualityService._internal();
  static final NetworkQualityService instance = NetworkQualityService._internal();

  NetworkQuality _quality = NetworkQuality.good;
  NetworkQuality get quality => _quality;

  bool get isOffline => _quality == NetworkQuality.offline;

  /// Multiplier applied to request timeouts. 1.0 on good networks, up to
  /// 3x on poor ones so weak-network devices get real results instead of
  /// timed-out empty lists.
  double get timeoutScale => switch (_quality) {
        NetworkQuality.offline => 1.0,
        NetworkQuality.poor => 3.0,
        NetworkQuality.fair => 1.8,
        NetworkQuality.good => 1.0,
      };

  /// Last known connectivity interface types (e.g. wifi, mobile).
  Set<ConnectivityResult> _interfaces = {ConnectivityResult.wifi};
  Set<ConnectivityResult> get interfaces => _interfaces;

  bool get onMobileData =>
      _interfaces.contains(ConnectivityResult.mobile) &&
      !_interfaces.contains(ConnectivityResult.wifi) &&
      !_interfaces.contains(ConnectivityResult.ethernet);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _refreshTimer;
  bool _started = false;
  bool _probing = false;

  /// Starts connectivity monitoring and fires the first probe. Safe to
  /// call multiple times; work happens once.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _connectivitySub = Connectivity()
          .onConnectivityChanged
          .listen(_onConnectivityChanged);
      final initial = await Connectivity().checkConnectivity();
      await _onConnectivityChanged(initial);
    } catch (e) {
      // Desktop platforms without the plugin backing can throw — degrade to
      // "good" so requests are never artificially slowed.
      NoctraLogger.w('NetworkQuality: connectivity init failed', e);
    }
    unawaited(probe());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _refreshTimer?.cancel();
    _started = false;
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    _interfaces = results.toSet();
    if (_interfaces.contains(ConnectivityResult.none) || _interfaces.isEmpty) {
      _setQuality(NetworkQuality.offline);
      _refreshTimer?.cancel();
      return;
    }
    // Interface changed: probe immediately to reclassify speed.
    await probe();
  }

  /// Measures RTT with a tiny request and updates [quality]. Returns the
  /// measured round-trip, or null when offline/probe impossible.
  Future<Duration?> probe() async {
    if (_probing) return null;
    _probing = true;
    final client = http.Client();
    try {
      for (final host in _probeHosts) {
        try {
          final sw = Stopwatch()..start();
          await client
              .get(Uri.parse(host), headers: {'Connection': 'close'})
              .timeout(NetworkQualityService.adaptiveTimeout(
                  const Duration(seconds: 6)));
          sw.stop();
          _classifyByRtt(sw.elapsed);
          _schedulePeriodicRefresh();
          return sw.elapsed;
        } catch (_) {
          // Try the next probe host.
        }
      }
      // All probes failed: if connectivity says offline, believe it;
      // otherwise keep the current classification (probe may be blocked).
      if (_interfaces.contains(ConnectivityResult.none) ||
          _interfaces.isEmpty) {
        _setQuality(NetworkQuality.offline);
      }
      return null;
    } finally {
      _probing = false;
      client.close();
    }
  }

  void _classifyByRtt(Duration rtt) {
    final ms = rtt.inMilliseconds;
    _setQuality(switch (ms) {
      < 400 => NetworkQuality.good,
      < 1500 => NetworkQuality.fair,
      _ => NetworkQuality.poor,
    });
  }

  void _schedulePeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(minutes: 5), () => unawaited(probe()));
  }

  void _setQuality(NetworkQuality q) {
    if (q == _quality) return;
    final old = _quality;
    _quality = q;
    NoctraLogger.d('NetworkQuality: $old → $q');
    _qualityController.add(q);
  }

  final _qualityController = StreamController<NetworkQuality>.broadcast();
  Stream<NetworkQuality> get qualityStream => _qualityController.stream;

  /// Scales [base] by the current network quality. Used by every provider
  /// request so timeouts adapt instead of hard-failing on slow networks.
  static Duration adaptiveTimeout(Duration base, {double? scale}) {
    final s = scale ?? instance.timeoutScale;
    final scaled = base * s;
    // Never let a timeout balloon past 15s — the resolution/search budgets
    // upstream depend on requests eventually giving up.
    return scaled > const Duration(seconds: 15)
        ? const Duration(seconds: 15)
        : scaled;
  }
}

/// Shared retry with exponential backoff + jitter for idempotent GETs.
///
/// ```text
/// attempt 1 → fail → wait 250–500ms
/// attempt 2 → fail → wait 500–1000ms
/// attempt 3 → fail → give up (caller decides fallback)
/// ```
class Retry {
  /// Runs [task], retrying on retryable errors up to [maxAttempts] times.
  /// [retryable] decides which exceptions are worth retrying (default:
  /// SocketException, TimeoutException, and HTTP 5xx/429 surfaces thrown
  /// as exceptions). Cancellation/epoch errors must NOT be retried.
  static Future<T?> run<T>(
    Future<T> Function() task, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 250),
    bool Function(Object error)? retryable,
    String? debugLabel,
  }) async {
    final rng = Random();
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await task();
      } catch (e) {
        lastError = e;
        final isLast = attempt == maxAttempts - 1;
        final worth = retryable?.call(e) ?? _defaultRetryable(e);
        if (isLast || !worth) break;
        final delay = baseDelay * pow(2, attempt).toDouble();
        final jittered = delay * (0.8 + rng.nextDouble() * 0.4);
        if (kDebugMode && debugLabel != null) {
          NoctraLogger.d('Retry[$debugLabel] attempt ${attempt + 1} '
              'failed ($e) — retrying in ${jittered.inMilliseconds}ms');
        }
        await Future<void>.delayed(jittered);
      }
    }
    if (kDebugMode && debugLabel != null) {
      NoctraLogger.d('Retry[$debugLabel] exhausted: $lastError');
    }
    return null;
  }

  static bool _defaultRetryable(Object e) {
    if (e is TimeoutException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('connection refused') ||
        msg.contains('socketexception') ||
        msg.contains('software caused connection') ||
        msg.contains('broken pipe');
  }
}
