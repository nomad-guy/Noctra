import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level regression guard for the P0 playback fix.
///
/// Songs previously never played because the app initialized
/// `just_audio_background`, whose platform plugin permits exactly ONE
/// live [AudioPlayer] — while Noctra's crossfade engine keeps a second
/// (pre-buffered) player alive and replaces the current player per
/// track. Every extra player construction was rejected and
/// `setAudioSource` failed with:
///
///   PlatformException: just_audio_background supports only a single
///   player instance
///
/// The fix removed that plugin and wired background playback through
/// audio_service's [NoctraAudioHandler], which mirrors the playback
/// service's logical state rather than binding to one player instance.
/// These tests fail loudly if the single-player plugin (or a player-bound
/// init) is ever re-introduced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  test('just_audio_background is not a dependency, import, or init anywhere',
      () {
    final pubspec = read('pubspec.yaml');
    expect(pubspec.contains('just_audio_background:'), isFalse,
        reason: 'just_audio_background enforces a single AudioPlayer and '
            'breaks Noctra crossfade/preload playback.');
    expect(pubspec.contains('audio_service:'), isTrue,
        reason: 'audio_service hosts the media session + notification.');

    final serviceLib = read('lib/services/audio/audio_player_service.dart');
    expect(serviceLib.contains('just_audio_background'), isFalse);
    expect(
        serviceLib
            .contains("import 'package:audio_service/audio_service.dart'"),
        isTrue,
        reason: 'MediaItem tags come from audio_service now.');

    final mainLib = read('lib/main.dart');
    expect(mainLib.contains('import \'package:just_audio_background'), isFalse);
    expect(mainLib.contains('JustAudioBackground.init'), isFalse);
  });

  test('startup wires the media session through the player-agnostic handler',
      () {
    final mainLib = read('lib/main.dart');
    expect(mainLib.contains('NoctraAudioHandler'), isTrue);
    expect(mainLib.contains('AudioService.init'), isTrue);
    expect(mainLib.contains('noctraAudioHandler?.attach(svc)'), isTrue,
        reason: 'the handler must be bound to the playback service once the '
            'service exists, or the notification cannot follow playback.');

    final handler = read('lib/services/audio/noctra_audio_handler.dart');
    expect(
        handler.contains('class NoctraAudioHandler extends BaseAudioHandler'),
        isTrue);
    expect(handler.contains('Timer.periodic'), isTrue,
        reason: 'the 1 Hz mirror tick keeps notification state fresh even for '
            'in-app playback changes.');
  });

  test('MainActivity shares audio_service engine (no second main() engine)',
      () {
    final activity =
        read('android/app/src/main/kotlin/com/nomadguy/noctra/MainActivity.kt');
    expect(activity.contains('AudioServiceActivity'), isTrue,
        reason: 'a plain FlutterActivity leaves audio_service engine cache '
            'empty, so audio_service spins a second engine running main() '
            'again (duplicated service instances + session restores).');
    expect(activity.contains(': FlutterActivity()'), isFalse);
  });
}
