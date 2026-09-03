part of '../p2p_sync_service.dart';

/// Sliding-window rate state. Windows are fixed-size and reset lazily on
/// the first tick after expiry, so entries cost constant memory.
class _RateState {
  int startMs = 0;
  int count = 0;
}

bool _tickRate(_RateState st, int limit, int windowMs, int nowMs) {
  if (nowMs - st.startMs >= windowMs) {
    st.startMs = nowMs;
    st.count = 0;
  }
  st.count++;
  return st.count <= limit;
}

class _PeerInboundTrack {
  final _RateState general = _RateState();
  final _RateState chat = _RateState();
  int lastSeenMs = DateTime.now().millisecondsSinceEpoch;
}

/// A connection that upgraded but has not yet answered the auth challenge.
class _PendingAuth {
  final String ip;
  final String nonce;
  Timer? deadline;
  _PendingAuth(this.ip, this.nonce);
}

class _AuthTrack {
  int windowStartMs;
  int failures = 1;
  _AuthTrack(this.windowStartMs);
}

extension P2PRateLimiting on P2PSyncService {
  bool _isAuthThrottled(String ip) {
    if (ip.isEmpty) return false;
    final track = _authFailures[ip];
    if (track == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - track.windowStartMs >= P2PSyncService.authFailWindowMs) {
      _authFailures.remove(ip);
      return false;
    }
    return track.failures >= P2PSyncService.authFailLimit;
  }

  void _recordAuthFailure(String ip) {
    if (ip.isEmpty) return;
    _pruneAuthTracks();
    final now = DateTime.now().millisecondsSinceEpoch;
    final track = _authFailures[ip];
    if (track == null) {
      if (_authFailures.length >= P2PSyncService._authTrackMaxEntries) {
        String? oldestKey;
        int oldestStart = now;
        _authFailures.forEach((key, value) {
          if (value.windowStartMs <= oldestStart) {
            oldestStart = value.windowStartMs;
            oldestKey = key;
          }
        });
        if (oldestKey != null) _authFailures.remove(oldestKey);
      }
      _authFailures[ip] = _AuthTrack(now);
      return;
    }
    if (now - track.windowStartMs >= P2PSyncService.authFailWindowMs) {
      track.windowStartMs = now;
      track.failures = 1;
      return;
    }
    track.failures++;
  }

  void _clearAuthFailures(String ip) {
    if (ip.isNotEmpty) _authFailures.remove(ip);
  }

  void _pruneAuthTracks() {
    if (_authFailures.length < P2PSyncService._authTrackMaxEntries) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _authFailures.removeWhere(
        (_, t) => now - t.windowStartMs >= P2PSyncService.authFailWindowMs);
  }
}
