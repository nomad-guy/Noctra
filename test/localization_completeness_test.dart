import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/utils/noctra_localization.dart';
import 'package:noctra/core/utils/localization/languages/english.dart';
import 'package:noctra/core/utils/localization/languages/hindi.dart';
import 'package:noctra/core/utils/localization/languages/punjabi.dart';
import 'package:noctra/core/utils/localization/languages/urdu.dart';
import 'package:noctra/core/utils/localization/languages/kannada.dart';
import 'package:noctra/core/utils/localization/languages/tamil.dart';
import 'package:noctra/core/utils/localization/languages/marathi.dart';
import 'package:noctra/core/utils/localization/languages/odia.dart';

void main() {
  group('Localization Completeness & Parity Tests', () {
    final Map<String, Map<String, String>> allDictionaries = {
      'en': englishLocale,
      'hi': hindiLocale,
      'pa': punjabiLocale,
      'ur': urduLocale,
      'kn': kannadaLocale,
      'ta': tamilLocale,
      'mr': marathiLocale,
      'or': odiaLocale,
    };

    final englishKeys = englishLocale.keys.toSet();

    test('All 8 required languages are configured', () {
      expect(allDictionaries.length, equals(8));
      expect(
        allDictionaries.keys.toSet(),
        equals({'en', 'hi', 'pa', 'ur', 'kn', 'ta', 'mr', 'or'}),
      );
    });

    for (final entry in allDictionaries.entries) {
      final lang = entry.key;
      final dict = entry.value;

      test('[$lang] has 1:1 key parity with English dictionary', () {
        final currentKeys = dict.keys.toSet();
        final missingFromLang = englishKeys.difference(currentKeys);
        final extraInLang = currentKeys.difference(englishKeys);

        expect(
          missingFromLang,
          isEmpty,
          reason: 'Language "$lang" is missing keys present in English',
        );
        expect(
          extraInLang,
          isEmpty,
          reason: 'Language "$lang" contains extra keys not in English',
        );
      });

      test('[$lang] has no empty translation values', () {
        for (final item in dict.entries) {
          expect(
            item.value.trim(),
            isNotEmpty,
            reason: 'Key "${item.key}" in "$lang" has empty translation',
          );
        }
      });

      test('[$lang] contains ZERO emojis', () {
        final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F1E6}-\u{1F1FF}]',
          unicode: true,
        );

        for (final item in dict.entries) {
          expect(
            emojiRegex.hasMatch(item.value),
            isFalse,
            reason: 'Key "${item.key}" in "$lang" contains emoji: ${item.value}',
          );
        }
      });
    }

    test('RTL is correctly enabled only for Urdu (ur)', () {
      expect(NoctraLocalization.isRtl('ur'), isTrue);
      expect(NoctraLocalization.isRtl('en'), isFalse);
      expect(NoctraLocalization.isRtl('hi'), isFalse);
      expect(NoctraLocalization.isRtl('pa'), isFalse);
      expect(NoctraLocalization.isRtl('kn'), isFalse);
      expect(NoctraLocalization.isRtl('ta'), isFalse);
      expect(NoctraLocalization.isRtl('mr'), isFalse);
      expect(NoctraLocalization.isRtl('or'), isFalse);
    });

    test('Parameter interpolation works dynamically', () {
      final res = NoctraLocalization.tr(
        'connected_devices',
        language: 'en',
        args: {'count': '3'},
      );
      expect(res, equals('3 Connected'));

      final hindiRes = NoctraLocalization.tr(
        'connected_devices',
        language: 'hi',
        args: {'count': '5'},
      );
      expect(hindiRes, equals('5 जुड़े हुए'));
    });
  });
}
