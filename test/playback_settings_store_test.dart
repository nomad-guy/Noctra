import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/utils/playback_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the persisted playback settings store.
///
/// Windows bug: every playback setting (fade, crossfade, autoplay delay,
/// shuffle, loop, volume) lived only in memory, so closing the app reset
/// them all to defaults.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PlaybackSettingsStore.instance.fadeEnabled = true;
    PlaybackSettingsStore.instance.crossfadeSeconds = 3;
    PlaybackSettingsStore.instance.autoplayDelaySeconds = 3;
    PlaybackSettingsStore.instance.shuffleEnabled = false;
    PlaybackSettingsStore.instance.loopMode = 'off';
    PlaybackSettingsStore.instance.volume = 1.0;
  });

  test('save() persists values and load() restores them', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlaybackSettingsStore.instance;
    store.save(
      fadeEnabled: false,
      crossfadeSeconds: 8,
      autoplayDelaySeconds: 7,
      shuffleEnabled: true,
      loopMode: 'one',
      volume: 0.42,
    );
    await store.unawaitedPersist();

    // Simulate a fresh process: reset in-memory state, then load.
    store
      ..fadeEnabled = true
      ..crossfadeSeconds = 3
      ..autoplayDelaySeconds = 3
      ..shuffleEnabled = false
      ..loopMode = 'off'
      ..volume = 1.0;
    await store.load();

    expect(store.fadeEnabled, isFalse);
    expect(store.crossfadeSeconds, 8);
    expect(store.autoplayDelaySeconds, 7);
    expect(store.shuffleEnabled, isTrue);
    expect(store.loopMode, 'one');
    expect(store.volume, moreOrLessEquals(0.42));
  });

  test('save() clamps volume into [0,1] and survives NaN-ish input via caller',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlaybackSettingsStore.instance;
    store.save(volume: 5.0);
    expect(store.volume, 1.0);
    store.save(volume: -2.0);
    expect(store.volume, 0.0);
  });

  test('load() falls back to defaults on empty storage', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PlaybackSettingsStore.instance;
    await store.load();
    expect(store.fadeEnabled, isTrue);
    expect(store.crossfadeSeconds, 3);
    expect(store.volume, 1.0);
  });
}
