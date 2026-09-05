import 'package:flutter/foundation.dart';

/// Logical platform identifiers used across Noctra. Code that needs a platform
/// decision must go through [NoctraCapabilities] instead of scattering
/// `Platform.is*` / `defaultTargetPlatform` checks through the app.
enum NoctraPlatform { android, iOS, windows, linux, macOS, web, other }

/// Centralized platform/capability registry.
///
/// Everything here is derived from `defaultTargetPlatform` / [kIsWeb] so it is
/// safe on every target and can be overridden in tests via
/// `debugDefaultTargetPlatformOverride`. Platform adapters are the only code
/// allowed to read the raw platform; the rest of the app consumes these
/// capabilities.
class NoctraCapabilities {
  NoctraCapabilities._();

  static NoctraPlatform get platform {
    if (kIsWeb) return NoctraPlatform.web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return NoctraPlatform.android;
      case TargetPlatform.iOS:
        return NoctraPlatform.iOS;
      case TargetPlatform.windows:
        return NoctraPlatform.windows;
      case TargetPlatform.linux:
        return NoctraPlatform.linux;
      case TargetPlatform.macOS:
        return NoctraPlatform.macOS;
      default:
        return NoctraPlatform.other;
    }
  }

  static bool get isAndroid => platform == NoctraPlatform.android;
  static bool get isIOS => platform == NoctraPlatform.iOS;
  static bool get isDesktop =>
      platform == NoctraPlatform.windows ||
      platform == NoctraPlatform.linux ||
      platform == NoctraPlatform.macOS;
  static bool get isMobile => isAndroid || isIOS;

  /// Android-only launcher-icon switching (native `launcher_icon` channel).
  static bool get supportsLauncherIcons => isAndroid;

  /// Native audio-effect DSP (equalizer/bass boost via Android audio session).
  static bool get supportsNativeAudioEffects => isAndroid;

  /// Native Kotlin stream resolver fast path (`native_resolver` channel).
  static bool get supportsNativeResolver => isAndroid;

  /// Native audio-device routing (Bluetooth/headphone endpoints).
  static bool get supportsNativeAudioRouting => isAndroid;

  /// Native visualizer frequency data.
  static bool get supportsNativeVisualizer => isAndroid;

  /// Package-installer driven self update (GitHub APK distribution).
  static bool get supportsSelfUpdate => isAndroid;
}
