import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted playback settings (cross-platform via SharedPreferences).
///
/// Everything the Settings > Playback & Audio section exposes must survive an
/// app restart. On Windows the process fully exits when the window closes, so
/// any setting kept only in memory resets to defaults on relaunch — this store
/// is the single persistence seam for those knobs.
class PlaybackSettingsStore {
  PlaybackSettingsStore._();
  static final PlaybackSettingsStore instance = PlaybackSettingsStore._();

  static const _kFade = 'noctra_setting_fade_enabled';
  static const _kCrossfade = 'noctra_setting_crossfade_seconds';
  static const _kAutoplayDelay = 'noctra_setting_autoplay_delay';
  static const _kShuffle = 'noctra_setting_shuffle_enabled';
  static const _kLoopMode = 'noctra_setting_loop_mode';
  static const _kVolume = 'noctra_setting_volume';

  bool fadeEnabled = true;
  int crossfadeSeconds = 3;
  int autoplayDelaySeconds = 3;
  bool shuffleEnabled = false;
  String loopMode = 'off';
  double volume = 1.0;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      fadeEnabled = prefs.getBool(_kFade) ?? true;
      crossfadeSeconds = prefs.getInt(_kCrossfade) ?? 3;
      autoplayDelaySeconds = prefs.getInt(_kAutoplayDelay) ?? 3;
      shuffleEnabled = prefs.getBool(_kShuffle) ?? false;
      loopMode = prefs.getString(_kLoopMode) ?? 'off';
      volume = (prefs.getDouble(_kVolume) ?? 1.0).clamp(0.0, 1.0);
    } catch (_) {
      // Defaults already set; persistence failure must never crash startup.
    }
  }

  /// Updates in-memory values immediately (synchronous reads stay correct)
  /// and fires a best-effort async persist.
  void save({
    bool? fadeEnabled,
    int? crossfadeSeconds,
    int? autoplayDelaySeconds,
    bool? shuffleEnabled,
    String? loopMode,
    double? volume,
  }) {
    if (fadeEnabled != null) this.fadeEnabled = fadeEnabled;
    if (crossfadeSeconds != null) this.crossfadeSeconds = crossfadeSeconds;
    if (autoplayDelaySeconds != null) {
      this.autoplayDelaySeconds = autoplayDelaySeconds;
    }
    if (shuffleEnabled != null) this.shuffleEnabled = shuffleEnabled;
    if (loopMode != null) this.loopMode = loopMode;
    if (volume != null) this.volume = volume.clamp(0.0, 1.0);
    unawaitedPersist();
  }

  Future<void> unawaitedPersist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kFade, fadeEnabled);
      await prefs.setInt(_kCrossfade, crossfadeSeconds);
      await prefs.setInt(_kAutoplayDelay, autoplayDelaySeconds);
      await prefs.setBool(_kShuffle, shuffleEnabled);
      await prefs.setString(_kLoopMode, loopMode);
      await prefs.setDouble(_kVolume, volume);
    } catch (_) {}
  }
}
