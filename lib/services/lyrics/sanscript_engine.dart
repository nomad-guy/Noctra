import 'package:indic_transliteration_dart/indic_transliteration_dart.dart'
    as it;
import 'devanagari_transliteration_service.dart';
import 'scripts/mideast_and_european_transliterator.dart';

part 'parts/devanagari_to_urdu_transliterator.dart';
part 'parts/sanscript_mapping_tables.dart';

/// High-performance cross-Indic and Perso-Arabic script converter
/// combining custom phonetic mapping with compiled SchemeMaps from [indic_transliteration_dart].
class SanscriptEngine {
  SanscriptEngine._();

  static const String devanagari = 'devanagari';
  static const String gurmukhi = 'gurmukhi';
  static const String bengali = 'bengali';
  static const String gujarati = 'gujarati';
  static const String telugu = 'telugu';
  static const String tamil = 'tamil';
  static const String kannada = 'kannada';
  static const String malayalam = 'malayalam';
  static const String odia = 'odia';
  static const String oriya = 'oriya';
  static const String urdu = 'urdu';
  static const String itrans = 'itrans';
  static const String iast = 'iast';
  static const String hk = 'hk';
  static const String slp1 = 'slp1';
  static const String velthuis = 'velthuis';
  static const String wx = 'wx';

  static const Set<String> _indicSchemes = {
    'devanagari',
    'gurmukhi',
    'bengali',
    'gujarati',
    'telugu',
    'tamil',
    'kannada',
    'malayalam',
    'oriya',
    'itrans',
    'iast',
    'hk',
    'slp1',
    'velthuis',
    'wx',
  };

  static bool _schemesInitialized = false;
  static final Map<String, it.SchemeMap> _schemeMapCache = {};

  static void _ensureInitialized() {
    if (!_schemesInitialized) {
      it.initializeSchemes();
      _schemesInitialized = true;
    }
  }

  static String _normalizeScheme(String scheme) {
    final lower = scheme.toLowerCase().trim();
    if (lower == 'odia') return 'oriya';
    return lower;
  }

  /// Transliterate [input] text from [fromScript] to [toScript].
  static String transliterate(
          String input, String fromScript, String toScript) =>
      t(input, fromScript, toScript);

  static String t(String input, String fromScript, String toScript) {
    if (input.trim().isEmpty) return input;
    final from = _normalizeScheme(fromScript);
    final to = _normalizeScheme(toScript);
    if (from == to) return input;

    // 1. Urdu / Perso-Arabic bidirectional handling
    if (from == urdu) {
      final latin = MideastAndEuropeanTransliterator.arabicToLatin(input);
      final deva = DevanagariTransliterationService.toDevanagari(latin);
      if (to == devanagari) return deva;
      return t(deva, devanagari, to);
    }
    if (to == urdu) {
      final deva = (from == devanagari) ? input : t(input, from, devanagari);
      return DevanagariToUrduTransliterator.toUrdu(deva);
    }

    // 2. Custom linguistic tables for regional phonetic collapsing (Bengali/Gurmukhi/Tamil/Odia)
    final fromBaseKey = from == 'oriya' ? 'odia' : from;
    final toBaseKey = to == 'oriya' ? 'odia' : to;
    if (SanscriptMappingTables.base.containsKey(fromBaseKey) &&
        SanscriptMappingTables.base.containsKey(toBaseKey)) {
      return _customTransliterate(input, fromBaseKey, toBaseKey);
    }

    // 3. High-speed compiled SchemeMap conversion via indic_transliteration_dart
    if (_indicSchemes.contains(from) && _indicSchemes.contains(to)) {
      try {
        _ensureInitialized();
        final cacheKey = '$from->$to';
        var schemeMap = _schemeMapCache[cacheKey];
        if (schemeMap == null) {
          schemeMap = it.getSchemeMap(from, to);
          _schemeMapCache[cacheKey] = schemeMap;
        }
        return it.transliterate(input, schemeMap: schemeMap);
      } catch (_) {
        return input;
      }
    }

    return input;
  }

  static String _customTransliterate(
      String input, String from, String to) {
    if (from == devanagari) {
      return _emit(_normalizeNukta(input, from), to);
    }
    final pivot =
        _normalizeNukta(_parseToDevanagari(input, from), devanagari);
    if (to == devanagari) return pivot;
    return _emit(pivot, to);
  }

  static String _normalizeNukta(String text, String script) {
    final compose = script == gurmukhi
        ? SanscriptMappingTables.gurmukhiNuktaCompose
        : SanscriptMappingTables.devaNuktaCompose;
    if (compose.isEmpty) return text;
    var out = text;
    compose.forEach((decomposed, composed) {
      out = out.replaceAll(decomposed, composed);
    });
    return out;
  }

  static String _parseToDevanagari(String text, String from) {
    final fromBase = SanscriptMappingTables.base[from]!;
    final devaBase = SanscriptMappingTables.base[devanagari]!;
    final buf = StringBuffer();

    var i = 0;
    while (i < text.length) {
      final code = text.codeUnitAt(i);
      if (from == gurmukhi) {
        if (code == 0x0A71 && i + 1 < text.length) {
          final next = text.codeUnitAt(i + 1);
          if (next >= 0x0A15 && next <= 0x0A39) {
            final devaNext = String.fromCharCode(next - 0x0A00 + devaBase);
            buf
              ..write(devaNext)
              ..write('\u094D')
              ..write(devaNext);
            i += 2;
            continue;
          }
        }
        if (code == 0x0A70) {
          buf.write('\u0902');
          i++;
          continue;
        }
        if (code >= 0x0A15 &&
            code <= 0x0A39 &&
            i + 1 < text.length &&
            text.codeUnitAt(i + 1) == 0x0A3C) {
          final mapped =
              SanscriptMappingTables.gurmukhiNuktaBaseToDeva[code];
          if (mapped != null) {
            buf.write(mapped);
            i += 2;
            continue;
          }
        }
        if (code == 0x0A3C) {
          buf.write('़');
          i++;
          continue;
        }
        final composed = SanscriptMappingTables.gurmukhiComposedToDeva[code];
        if (composed != null) {
          buf.write(composed);
          i++;
          continue;
        }
      }
      if (code >= fromBase && code < fromBase + 0x80) {
        final rel = code - fromBase;
        final target = devaBase + rel;
        if (target >= devaBase && target < devaBase + 0x80) {
          buf.writeCharCode(target);
          i++;
          continue;
        }
      }
      buf.writeCharCode(code);
      i++;
    }
    return buf.toString();
  }

  static String _emit(String devaText, String to) {
    final toBase = SanscriptMappingTables.base[to]!;
    final devaBase = SanscriptMappingTables.base[devanagari]!;
    final consonants =
        SanscriptMappingTables.consonantOverrides[to] ?? const {};
    final vowels = SanscriptMappingTables.vowelOverrides[to] ?? const {};
    final matras = SanscriptMappingTables.matraOverrides[to] ?? const {};
    final marks = SanscriptMappingTables.markOverrides[to] ?? const {};
    final buf = StringBuffer();

    var i = 0;
    while (i < devaText.length) {
      final ch = devaText[i];
      final code = ch.codeUnitAt(0);

      if (code >= 0x0958 && code <= 0x095F) {
        final override = consonants[ch];
        if (override != null) {
          buf.write(override);
          i++;
          continue;
        }
      }

      final override =
          consonants[ch] ?? vowels[ch] ?? matras[ch] ?? marks[ch];
      if (override != null) {
        buf.write(override);
        i++;
        continue;
      }
      if (code >= devaBase && code < devaBase + 0x80) {
        final rel = code - devaBase;
        final target = toBase + rel;
        if (target >= toBase && target < toBase + 0x80) {
          buf.writeCharCode(target);
          i++;
          continue;
        }
      }
      buf.write(ch);
      i++;
    }
    return buf.toString();
  }
}
