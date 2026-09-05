import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/platform/noctra_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('NoctraCapabilities', () {
    test('reports Android capabilities', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(NoctraCapabilities.platform, NoctraPlatform.android);
      expect(NoctraCapabilities.isAndroid, isTrue);
      expect(NoctraCapabilities.isMobile, isTrue);
      expect(NoctraCapabilities.isDesktop, isFalse);
      // Android-only adapters
      expect(NoctraCapabilities.supportsLauncherIcons, isTrue);
      expect(NoctraCapabilities.supportsNativeAudioEffects, isTrue);
      expect(NoctraCapabilities.supportsNativeResolver, isTrue);
      expect(NoctraCapabilities.supportsSelfUpdate, isTrue);
    });

    test('reports iOS as mobile without Android adapters', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(NoctraCapabilities.platform, NoctraPlatform.iOS);
      expect(NoctraCapabilities.isMobile, isTrue);
      expect(NoctraCapabilities.isAndroid, isFalse);
      expect(NoctraCapabilities.supportsLauncherIcons, isFalse);
      expect(NoctraCapabilities.supportsNativeResolver, isFalse);
      expect(NoctraCapabilities.supportsSelfUpdate, isFalse);
    });

    test('reports Windows/Linux as desktop without Android adapters', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(NoctraCapabilities.platform, NoctraPlatform.windows);
      expect(NoctraCapabilities.isDesktop, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(NoctraCapabilities.platform, NoctraPlatform.linux);
      expect(NoctraCapabilities.isDesktop, isTrue);
      expect(NoctraCapabilities.isAndroid, isFalse);
      expect(NoctraCapabilities.supportsNativeAudioEffects, isFalse);
    });
  });
}
