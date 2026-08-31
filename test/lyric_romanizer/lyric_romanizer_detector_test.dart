import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyric_romanizer/lyric_romanizer_detector.dart';
import 'package:noctra/services/lyric_romanizer/lyric_romanizer_types.dart';

void main() {
  group('detector', () {
    test('detects japanese', () {
      expect(detectScript(['春はあけぼの', 'やうやう白くなりゆく際']),
          ScriptType.japanese);
    });

    test('detects chinese', () {
      expect(detectScript(['你好，世界', '这是一个测试']), ScriptType.chinese);
    });

    test('detects korean', () {
      expect(detectScript(['안녕하세요', '세상아']), ScriptType.korean);
    });

    test('detects cyrillic', () {
      expect(detectScript(['Привет', 'мир']), ScriptType.cyrillic);
    });

    test('detects devanagari', () {
      expect(detectScript(['नमस्ते', 'दुनिया']), ScriptType.devanagari);
    });

    test('detects tamil', () {
      expect(detectScript(['வணக்கம்', 'உலகம்']), ScriptType.tamil);
    });

    test('detects thai', () {
      expect(detectScript(['สวัสดี', 'ชาวโลก']), ScriptType.thai);
    });

    test('detects latin and symbols', () {
      expect(detectScript(['Hello world', 'Café au lait']), ScriptType.latin);
      expect(detectScript(['123', '??? !!!']), ScriptType.other);
    });

    test('matches latin fast-path expectations', () {
      expect(isLatinScript(['Hello world']), isTrue);
      expect(isLatinScript(['안녕하세요']), isFalse);
      expect(isLatinScript(['♪♪♪']), isFalse);
    });

    test('keeps kana definitive over Han scoring in mixed CJK input', () {
      expect(detectScript(['你好世界', 'こんにちは']), ScriptType.japanese);
    });

    test('preserves tie-break priority (earlier script wins equal count)', () {
      // '你' is Chinese, '안' is Korean — 1 each, Chinese listed first
      expect(detectScript(['你안']), ScriptType.chinese);
    });
  });

  group('nonLatinScriptRegex derivation', () {
    test('contains expected ranges', () {
      // The regex should match Japanese kana
      expect(nonLatinScriptRegex.hasMatch('あ'), isTrue);
      // Should match Chinese Han
      expect(nonLatinScriptRegex.hasMatch('你'), isTrue);
      // Should match Korean Hangul
      expect(nonLatinScriptRegex.hasMatch('안'), isTrue);
      // Should match Cyrillic
      expect(nonLatinScriptRegex.hasMatch('А'), isTrue);
      // Should NOT match Latin
      expect(nonLatinScriptRegex.hasMatch('A'), isFalse);
      expect(nonLatinScriptRegex.hasMatch('z'), isFalse);
    });
  });

  group('requiresExternalRomanization', () {
    test('classifies external scripts', () {
      for (final script in [
        ScriptType.malayalam,
        ScriptType.bengali,
        ScriptType.arabic,
        ScriptType.hebrew,
        ScriptType.other,
      ]) {
        expect(requiresExternalRomanization(script), isTrue,
            reason: '${script.name} should be external');
      }
    });

    test('classifies local scripts', () {
      for (final script in [
        ScriptType.japanese,
        ScriptType.chinese,
        ScriptType.korean,
        ScriptType.cyrillic,
        ScriptType.devanagari,
        ScriptType.gujarati,
        ScriptType.telugu,
        ScriptType.kannada,
        ScriptType.odia,
        ScriptType.tamil,
        ScriptType.thai,
        ScriptType.latin,
      ]) {
        expect(requiresExternalRomanization(script), isFalse,
            reason: '${script.name} should be local');
      }
    });
  });

  group('script metadata', () {
    test('has entries for all ScriptType values', () {
      for (final script in ScriptType.values) {
        expect(scriptMetadata.containsKey(script), isTrue,
            reason: 'Missing metadata for ${script.name}');
      }
    });

    test('japanese is marked definitive', () {
      expect(scriptMetadata[ScriptType.japanese]!.definitive, isTrue);
    });

    test('external scripts are marked external', () {
      expect(scriptMetadata[ScriptType.malayalam]!.external, isTrue);
      expect(scriptMetadata[ScriptType.bengali]!.external, isTrue);
      expect(scriptMetadata[ScriptType.arabic]!.external, isTrue);
      expect(scriptMetadata[ScriptType.hebrew]!.external, isTrue);
    });
  });
}
