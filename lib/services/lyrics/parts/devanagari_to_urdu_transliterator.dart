part of '../sanscript_engine.dart';

/// Algorithmic deterministic transliterator from Devanagari to Urdu (Perso-Arabic script).
/// Handles virama suppression, dependent matras, medial/final bari-yeh (ے / ی),
/// and nasalized noon ghunna (ں / ن).
class DevanagariToUrduTransliterator {
  DevanagariToUrduTransliterator._();

  static const Map<String, String> _consonants = {
    'क': 'ک',
    'ख': 'کھ',
    'ग': 'گ',
    'घ': 'گھ',
    'ङ': 'ن',
    'च': 'چ',
    'छ': 'چھ',
    'ज': 'ج',
    'झ': 'جھ',
    'ञ': 'ن',
    'ट': 'ٹ',
    'ठ': 'ٹھ',
    'ड': 'ڈ',
    'ढ': 'ڈھ',
    'ण': 'ن',
    'त': 'ت',
    'थ': 'تھ',
    'द': 'د',
    'ध': 'دھ',
    'न': 'ن',
    'प': 'پ',
    'फ': 'پھ',
    'ब': 'ب',
    'भ': 'بھ',
    'म': 'م',
    'य': 'ی',
    'र': 'ر',
    'ल': 'ل',
    'व': 'و',
    'श': 'ش',
    'ष': 'ش',
    'स': 'س',
    'ह': 'ہ',
    'क़': 'ق',
    'ख़': 'خ',
    'ग़': 'غ',
    'ज़': 'ز',
    'फ़': 'ف',
    'ड़': 'ڑ',
    'ढ़': 'ڑھ',
    'झ़': 'ژ',
  };

  static const Map<String, String> _vowelsInitial = {
    'अ': 'ا',
    'आ': 'آ',
    'इ': 'ا',
    'ई': 'ای',
    'उ': 'ا',
    'ऊ': 'او',
    'ए': 'اے',
    'ऐ': 'اے',
    'ओ': 'او',
    'औ': 'او',
  };

  static const Map<String, String> _matras = {
    'ा': 'ا',
    'ि': '',
    'ी': 'ی',
    'ु': '',
    'ू': 'و',
    'े': 'ے',
    'ै': 'ے',
    'ो': 'و',
    'ौ': 'و',
    'ं': 'ں',
    'ँ': 'ں',
    '्': '',
  };

  static String toUrdu(String text) {
    if (text.trim().isEmpty) return text;
    return text.splitMapJoin(
      RegExp(r'\s+'),
      onMatch: (m) => m.group(0)!,
      onNonMatch: (w) => _convertWord(w),
    );
  }

  static String _convertWord(String word) {
    if (word.isEmpty) return word;
    final sb = StringBuffer();
    final n = word.length;
    var i = 0;

    while (i < n) {
      if (i + 1 < n && word[i + 1] == '़') {
        final withNukta = word.substring(i, i + 2);
        if (_consonants.containsKey(withNukta)) {
          sb.write(_consonants[withNukta]);
          i += 2;
          if (i < n && _matras.containsKey(word[i])) {
            final matra = word[i];
            final isFinal = (i + 1 == n);
            if (matra == 'े' || matra == 'ै') {
              sb.write(isFinal ? 'ے' : 'ی');
            } else {
              sb.write(_matras[matra]);
            }
            i++;
          }
          continue;
        }
      }

      final ch = word[i];
      if (_consonants.containsKey(ch)) {
        sb.write(_consonants[ch]);
        i++;
        if (i < n) {
          if (word[i] == '्') {
            i++;
            continue;
          }
          if (_matras.containsKey(word[i])) {
            final matra = word[i];
            final isFinal = (i + 1 == n);
            if (matra == 'े' || matra == 'ै') {
              sb.write(isFinal ? 'ے' : 'ی');
            } else if (matra == 'ं' || matra == 'ँ') {
              sb.write(isFinal ? 'ں' : 'ن');
            } else {
              sb.write(_matras[matra]);
            }
            i++;
            if (i < n && (word[i] == 'ं' || word[i] == 'ँ')) {
              final isSubFinal = (i + 1 == n);
              sb.write(isSubFinal ? 'ں' : 'ن');
              i++;
            }
            continue;
          }
        }
        continue;
      }

      if (_vowelsInitial.containsKey(ch)) {
        sb.write(_vowelsInitial[ch]);
        i++;
        continue;
      }

      if (_matras.containsKey(ch)) {
        sb.write(_matras[ch]);
        i++;
        continue;
      }

      sb.write(ch);
      i++;
    }

    return sb.toString();
  }
}
