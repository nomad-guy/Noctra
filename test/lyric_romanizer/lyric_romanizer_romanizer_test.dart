import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/lyric_romanizer/lyric_romanizer_types.dart';
import 'package:noctra/services/lyric_romanizer/lyric_romanizer_romanizer.dart';

void main() {
  group('romanizer', () {
    test('returns no-op for latin lines', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(['Hello world']);
      expect(result.script, ScriptType.latin);
      expect(result.lines, ['Hello world']);
    });

    test('detects and romanizes chinese', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(['你好']);
      expect(result.script, ScriptType.chinese);
      expect(result.lines[0], isNot(contains('你')));
    });

    test('detects and romanizes korean', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(['안녕하세요']);
      expect(result.script, ScriptType.korean);
      expect(result.lines[0], isNot(contains('안')));
    });

    test('detects and romanizes cyrillic', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(['Привет']);
      expect(result.script, ScriptType.cyrillic);
      expect(result.lines[0], isNot(contains('П')));
    });

    test('detects and romanizes thai', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(['สวัสดี']);
      expect(result.script, ScriptType.thai);
      expect(result.lines[0], isNot(contains('ส')));
    });

    test('throws for external scripts without adapter', () async {
      final romanizer = createRomanizer();
      expect(
        () => romanizer.romanizeLines(['مرحبا'], options: RomanizeOptions(script: ScriptType.arabic)),
        throwsA(isA<UnsupportedRomanizationError>()),
      );
    });

    test('returns fallbacks for latin input', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(['Hello world']);
      expect(result.fallbacks, [false]);
    });
  });

  group('cantonese romanization', () {
    test('uses Pinyin by default (dialect defaults to mandarin)', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLine('你好世界');
      // Default is Mandarin Pinyin
      expect(result, isNot(startsWith('jyutping:')));
    });

    test('uses Jyutping when dialect is cantonese', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLine(
        '你好',
        options: RomanizeOptions(
          script: ScriptType.chinese,
          dialect: ChineseDialect.cantonese,
        ),
      );
      // Cantonese should produce Jyutping-style output
      expect(result, isNotEmpty);
      // Should not contain Han characters
      expect(result, isNot(contains('你')));
    });

    test('uses Pinyin when dialect is mandarin', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLine(
        '你好',
        options: RomanizeOptions(
          script: ScriptType.chinese,
          dialect: ChineseDialect.mandarin,
        ),
      );
      expect(result, isNotEmpty);
      expect(result, isNot(contains('你')));
    });
  });

  group('engine injection', () {
    test('replaces a built-in engine', () async {
      final romanizer = createRomanizer(
        RomanizerOptions(
          engines: {
            ScriptType.korean: (line, ctx) async => 'fake:$line',
          },
        ),
      );
      final result = await romanizer.romanizeLine(
        '안녕',
        options: RomanizeOptions(script: ScriptType.korean),
      );
      expect(result, 'fake:안녕');
    });

    test('passes dialect context to injected engines', () async {
      final romanizer = createRomanizer(
        RomanizerOptions(
          engines: {
            ScriptType.chinese: (line, ctx) async =>
                '${ctx.dialect.name}:$line',
          },
        ),
      );
      final result1 = await romanizer.romanizeLine(
        '你好',
        options: RomanizeOptions(script: ScriptType.chinese),
      );
      expect(result1, 'mandarin:你好');

      final result2 = await romanizer.romanizeLine(
        '你好',
        options: RomanizeOptions(
          script: ScriptType.chinese,
          dialect: ChineseDialect.cantonese,
        ),
      );
      expect(result2, 'cantonese:你好');
    });

    test('routes external scripts to injected adapter', () async {
      final romanizer = createRomanizer(
        RomanizerOptions(
          engines: {
            ScriptType.arabic: (line, ctx) async => 'api:$line',
          },
        ),
      );
      final result = await romanizer.romanizeLines(['مرحبا']);
      expect(result.script, ScriptType.arabic);
      expect(result.lines[0], 'api:مرحبا');
      expect(result.fallbacks, [false]);
    });

    test('ignores undefined engine entries', () async {
      final romanizer = createRomanizer(
        RomanizerOptions(
          engines: {ScriptType.korean: null},
        ),
      );
      final result = await romanizer.romanizeLine(
        '안녕',
        options: RomanizeOptions(script: ScriptType.korean),
      );
      // Should use the default Korean engine
      expect(result, isNot(contains('안')));
    });
  });

  group('universal fallback', () {
    test('reports fallbacks when engine fails', () async {
      final romanizer = createRomanizer(
        RomanizerOptions(
          engines: {
            ScriptType.thai: (line, ctx) async =>
                throw Exception('engine down'),
          },
        ),
      );
      final result = await romanizer.romanizeLines(
        ['สวัสดี', 'ชาวโลก'],
        options: RomanizeOptions(script: ScriptType.thai),
      );
      expect(result.fallbacks, [true, true]);
    });

    test('reports no fallbacks on healthy path', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(
        ['안녕하세요', '세상아'],
        options: RomanizeOptions(script: ScriptType.korean),
      );
      expect(result.fallbacks, [false, false]);
    });
  });

  group('cyrillic preset selection', () {
    test('selects Ukrainian preset for Ukrainian-specific chars', () {
      expect(selectCyrillicPreset('Привет мир'), 'ru');
      expect(selectCyrillicPreset('Привіт світ'), 'uk');
      expect(selectCyrillicPreset('Ґанок'), 'uk');
      expect(selectCyrillicPreset('Їжак'), 'uk');
      expect(selectCyrillicPreset('Єнот'), 'uk');
    });

    test('applies preset per line through public interface', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(
        ['Привет мир', 'Привіт світ'],
        options: RomanizeOptions(script: ScriptType.cyrillic),
      );
      expect(result.lines[0], 'Privet mir');
      expect(result.lines[1], 'Pryvit svit');
    });
  });

  group('latin guard under pinned script', () {
    test('returns pure-latin lines unchanged', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLines(
        ['Hello', '世界'],
        options: RomanizeOptions(script: ScriptType.chinese),
      );
      expect(result.lines[0], 'Hello');
    });

    test('applies to explicitly pinned single lines', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLine(
        'Hello world',
        options: RomanizeOptions(script: ScriptType.chinese),
      );
      expect(result, 'Hello world');
    });

    test('keeps letterless input as a no-op', () async {
      final romanizer = createRomanizer();
      final result = await romanizer.romanizeLine(
        '123 !!!',
        options: RomanizeOptions(script: ScriptType.chinese),
      );
      expect(result, '123 !!!');
    });
  });
}
