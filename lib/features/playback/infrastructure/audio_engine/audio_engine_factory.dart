import 'package:just_audio/just_audio.dart';
import '../../../../core/platform/contracts/playback_engine.dart';
import '../../../../core/platform/noctra_capabilities.dart';
import 'android_audio_engine.dart';
import 'desktop_audio_engine.dart';
import 'ios_audio_engine.dart';

/// Factory producing platform-appropriate [PlaybackEngine] instances.
class AudioEngineFactory {
  AudioEngineFactory._();

  /// Creates a [PlaybackEngine] suited for the active runtime OS.
  static PlaybackEngine createEngine({AudioPlayer? player}) {
    switch (NoctraCapabilities.platform) {
      case NoctraPlatform.android:
        return AndroidAudioEngine(player: player);
      case NoctraPlatform.iOS:
        return IOSAudioEngine(player: player);
      case NoctraPlatform.windows:
      case NoctraPlatform.linux:
      case NoctraPlatform.macOS:
      case NoctraPlatform.web:
      case NoctraPlatform.other:
        return DesktopAudioEngine(player: player);
    }
  }
}
