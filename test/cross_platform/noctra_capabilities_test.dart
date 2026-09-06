import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/platform/noctra_capabilities.dart';

void main() {
  group('NoctraCapabilities Registry Tests', () {
    test('Platform detection adheres to defaultTargetPlatform', () {
      final p = NoctraCapabilities.platform;
      expect(p, isNotNull);
      if (defaultTargetPlatform == TargetPlatform.windows) {
        expect(NoctraCapabilities.isDesktop, isTrue);
        expect(NoctraCapabilities.supportsDesktopWindowControls, isTrue);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        expect(NoctraCapabilities.isAndroid, isTrue);
        expect(NoctraCapabilities.supportsNativeAudioEffects, isTrue);
      }
    });

    test('supportsNativeMediaControls is enabled on major supported platforms', () {
      expect(NoctraCapabilities.supportsNativeMediaControls, isTrue);
    });

    test('supportsFolderPicker is available on native targets', () {
      expect(NoctraCapabilities.supportsFolderPicker, !kIsWeb);
    });
  });
}
