import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/audio/audio_player_service.dart';
import 'package:noctra/services/audio/noctra_audio_handler.dart';

/// Regression tests for [NoctraAudioHandler].
///
/// Why these matter: playback previously ran through the
/// `just_audio_background` plugin, which permits exactly ONE live
/// AudioPlayer. Noctra's crossfade engine keeps a second (pre-buffered)
/// player alive and swaps the current player on every track advance, so
/// that plugin rejected player creation and every `setAudioSource` call
/// failed with "just_audio_background supports only a single player
/// instance" — songs never played. The handler replaces the plugin and
/// must:
///   * attach to the real playback service idempotently,
///   * mirror an idle service as a coherent idle PlaybackState,
///   * tolerate media-button commands when nothing is loaded,
///   * publish a null media item when playback is stopped,
///   * tear down its subscriptions/timers on dispose.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handler mirrors an idle service without throwing', () async {
    final handler = NoctraAudioHandler();
    addTearDown(handler.dispose);
    final svc = AudioPlayerService.instance;

    handler.attach(svc);
    handler.attach(svc); // idempotent — must not double-subscribe/crash

    final state = handler.playbackState.value;
    expect(state.processingState, AudioProcessingState.idle);
    expect(state.playing, isFalse);
    expect(state.controls, isNotEmpty);
    expect(handler.mediaItem.value, isNull);
  });

  test('media-button commands are safe on an idle service', () async {
    final handler = NoctraAudioHandler();
    addTearDown(handler.dispose);
    final svc = AudioPlayerService.instance;
    handler.attach(svc);

    // Nothing is loaded: each command routes through the real service APIs
    // and must complete without throwing (the test environment's just_audio
    // platform may optimistically report playing=true after play(), so only
    // the no-throw + live-state guarantees are asserted here).
    await handler.play();
    await handler.pause();
    await handler.stop();
    await handler.seek(Duration.zero);
    await handler.skipToNext();
    await handler.skipToPrevious();
    expect(handler.playbackState.hasValue, isTrue);
  });

  test('stopAndDismiss clears the mirrored media item', () async {
    final handler = NoctraAudioHandler();
    addTearDown(handler.dispose);
    final svc = AudioPlayerService.instance;
    handler.attach(svc);

    await svc.stopAndDismiss();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(handler.mediaItem.value, isNull);
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('dispose closes subjects and later attach cannot throw', () async {
    final handler = NoctraAudioHandler();
    final svc = AudioPlayerService.instance;
    handler.attach(svc);

    handler.dispose();
    expect(handler.playbackState.isClosed, isTrue);
    expect(handler.mediaItem.isClosed, isTrue);
    expect(handler.queue.isClosed, isTrue);

    // After dispose the mirror must refuse to push (no StateError on the
    // closed subjects) even if attach is called again.
    expect(() => handler.attach(svc), returnsNormally);
  });
}
