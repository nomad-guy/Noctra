part 'parts/sanscript_mapping_tables.dart';

/// Phoneme-driven cross-Indic-script converter.
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
  static const String itrans = 'itrans';
  static const String iast = 'iast';
  static const String hk = 'hk';

  /// Transliterate [input] text from [fromScript] to [toScript].
  static String transliterate(
          String input, String fromScript, String toScript) =>
      t(input, fromScript, toScript);

  static String t(String input, String fromScript, String toScript) {
    if (input.trim().isEmpty || fromScript == toScript) return input;
    final from = fromScript.toLowerCase();
    final to = toScript.toLowerCase();
    if (!SanscriptMappingTables.base.containsKey(from) ||
        !SanscriptMappingTables.base.containsKey(to)) {
      return input;
    }

    if (from == devanagari) {
      return _emit(_normalizeNukta(input, from), to);
    }
    final pivot = _normalizeNukta(_parseToDevanagari(input, from), devanagari);
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
        if (code == 0x0A71) {
          if (i + 1 < text.length) {
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
          i++;
          continue;
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
          final mapped = SanscriptMappingTables.gurmukhiNuktaBaseToDeva[code];
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

      final override = consonants[ch] ?? vowels[ch] ?? matras[ch] ?? marks[ch];
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
