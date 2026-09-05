/// Port of lyric-romanizer/src/index.ts
///
/// Public API for the lyric romanizer engine.
///
/// ```dart
/// import 'package:noctra/services/lyric_romanizer/lyric_romanizer_api.dart';
///
/// final romanizer = createRomanizer();
/// final result = await romanizer.romanizeLines(['你好世界']);
/// // result.script == ScriptType.chinese
/// // result.lines == ['nǐ hǎo shì jiè']
/// ```
library;

export 'lyric_romanizer_types.dart'
    show
        ScriptType,
        ChineseDialect,
        RomanizeOptions,
        RomanizeResult,
        RomanizeEngine,
        RomanizeEngineContext,
        Romanizer,
        RomanizerOptions,
        UnsupportedRomanizationError;

export 'lyric_romanizer_detector.dart'
    show
        detectScript,
        isLatinScript,
        requiresExternalRomanization,
        nonLatinScriptRegex,
        scriptMetadata,
        ScriptMeta,
        CodeRange;

export 'lyric_romanizer_romanizer.dart'
    show createRomanizer, selectCyrillicPreset;
