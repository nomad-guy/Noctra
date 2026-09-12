import 'package:shared_preferences/shared_preferences.dart';

/// Speaker Mesh — audio-output latency profiles.
///
/// Bluetooth adds device/profile-dependent delay that clock sync cannot see.
/// Each member starts playback *early* by its estimated output latency so
/// the sound arrives in sync. Estimates ship from the table below and can
/// be fine-tuned per device with a persisted manual trim.
class MeshLatencyProfile {
  MeshLatencyProfile._();
  static final MeshLatencyProfile instance = MeshLatencyProfile._();

  static const int defaultPhoneSpeakerMs = 40;
  static const int defaultBluetoothSbcMs = 220;
  static const int defaultBluetoothAacMs = 160;
  static const int defaultWiredMs = 15;

  static const int trimMinMs = -500;
  static const int trimMaxMs = 500;

  static const _kTrimKey = 'noctra_mesh_latency_trim_ms';
  static const _kRouteKey = 'noctra_mesh_output_route';

  /// Currently selected output route key (see [MeshOutputRoute.values]).
  String routeKey = MeshOutputRoute.phoneSpeaker.key;

  /// Manual per-device trim in ms (negative = start earlier).
  int trimMs = 0;

  /// Loads persisted route + trim. Safe to call repeatedly.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      routeKey =
          prefs.getString(_kRouteKey) ?? MeshOutputRoute.phoneSpeaker.key;
      trimMs = prefs.getInt(_kTrimKey) ?? 0;
      _clampTrim();
    } catch (_) {
      // Defaults already set.
    }
  }

  /// Persists current route + trim (best effort).
  Future<void> save() async {
    _clampTrim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRouteKey, routeKey);
      await prefs.setInt(_kTrimKey, trimMs);
    } catch (_) {}
  }

  void setTrim(int ms) {
    trimMs = ms;
    _clampTrim();
  }

  void _clampTrim() {
    if (trimMs < trimMinMs) trimMs = trimMinMs;
    if (trimMs > trimMaxMs) trimMs = trimMaxMs;
  }

  /// Total start-early compensation for the selected route + trim.
  int get totalLatencyMs {
    final base = MeshOutputRoute.byKey(routeKey).latencyMs;
    final total = base + trimMs;
    return total < 0 ? 0 : total;
  }
}

enum MeshOutputRoute {
  phoneSpeaker('phoneSpeaker', 'Phone speaker', 40),
  bluetoothSbc('bluetoothSbc', 'Bluetooth (SBC)', 220),
  bluetoothAac('bluetoothAac', 'Bluetooth (AAC)', 160),
  wired('wired', 'Wired / USB', 15);

  const MeshOutputRoute(this.key, this.label, this.latencyMs);

  final String key;
  final String label;
  final int latencyMs;

  static MeshOutputRoute byKey(String key) => MeshOutputRoute.values
      .firstWhere((r) => r.key == key, orElse: () => phoneSpeaker);
}
