/// Public API for the lyric romanizer engine.
///
/// Port of lyric-romanizer/src/index.ts
///
/// ```dart
/// import 'lyric_romanizer/lyric_romanizer_api.dart';
///
/// final romanizer = createRomanizer();
/// final result = await romanizer.romanizeLines(['你好世界']);
/// // result.script == ScriptType.chinese
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

export 'engines/roman_to_deva_engine.dart'
    show RomanToDevaEngine;
