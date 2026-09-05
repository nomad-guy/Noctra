import '../romanized_translation_engine.dart';
import '../sanscript_engine.dart';

class MideastAndEuropeanTransliterator {
  static final RomanizedTranslationEngine _romanizer =
      RomanizedTranslationEngine();

  static String cyrillicToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_cyrillicMap[ch] ?? ch);
    }
    return sb.toString();
  }

  static String arabicToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_arabicMap[ch] ?? ch);
    }
    return sb.toString();
  }

  static String greekToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_greekMap[ch] ?? ch);
    }
    return sb.toString();
  }

  static String thaiToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_thaiMap[ch] ?? ch);
    }
    return sb.toString();
  }

  static String hebrewToLatin(String text) {
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(_hebrewMap[ch] ?? ch);
    }
    return sb.toString();
  }

  static String gurmukhiToRoman(String text) {
    return text.splitMapJoin(RegExp(r'\s+'),
        onMatch: (m) => m.group(0)!,
        onNonMatch: (token) {
          final leading =
              RegExp(r'^\p{P}+', unicode: true).stringMatch(token) ?? '';
          final trailing =
              RegExp(r'\p{P}+$', unicode: true).stringMatch(token) ?? '';
          if (leading.length + trailing.length >= token.length) return token;
          final core =
              token.substring(leading.length, token.length - trailing.length);
          if (core.isEmpty) return token;
          final override = _gurmukhiRomanOverrides[core];
          final deva = SanscriptEngine.t(
              core, SanscriptEngine.gurmukhi, SanscriptEngine.devanagari);
          return '$leading${override ?? _romanizer.toRomanized(deva).toLowerCase()}$trailing';
        });
  }

  static const Map<String, String> _cyrillicMap = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'E': 'E', 'Ё': 'Yo',
    'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
    'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
    'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch',
    'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
  };

  static const Map<String, String> _arabicMap = {
    'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'aa', 'ب': 'b', 'ت': 't', 'ث': 'th',
    'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z',
    'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': "'",
    'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
    'ه': 'h', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ة': 'h', 'ء': "'", 'ئ': "'",
    'ؤ': "'", 'پ': 'p', 'چ': 'ch', 'ژ': 'zh', 'گ': 'g', 'ک': 'k', 'ی': 'y',
  };

  static const Map<String, String> _greekMap = {
    'α': 'a', 'β': 'v', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'ζ': 'z', 'η': 'i',
    'θ': 'th', 'ι': 'i', 'κ': 'k', 'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'x',
    'ο': 'o', 'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'τ': 't', 'υ': 'y',
    'φ': 'f', 'χ': 'ch', 'ψ': 'ps', 'ω': 'o',
    'Α': 'A', 'Β': 'V', 'Γ': 'G', 'Δ': 'D', 'Ε': 'E', 'Ζ': 'Z', 'Η': 'I',
    'Θ': 'Th', 'Ι': 'I', 'Κ': 'K', 'Λ': 'L', 'Μ': 'M', 'Ν': 'N', 'Ξ': 'X',
    'Ο': 'O', 'Π': 'P', 'Ρ': 'R', 'Σ': 'S', 'Τ': 'T', 'Υ': 'Y', 'Φ': 'F',
    'Χ': 'Ch', 'Ψ': 'Ps', 'Ω': 'O',
  };

  static const Map<String, String> _thaiMap = {
    'ก': 'k', 'ข': 'kh', 'ค': 'kh', 'ง': 'ng', 'จ': 'ch', 'ฉ': 'ch',
    'ช': 'ch', 'ซ': 's', 'ด': 'd', 'ต': 't', 'ถ': 'th', 'ท': 'th',
    'น': 'n', 'บ': 'b', 'ป': 'p', 'ผ': 'ph', 'ฝ': 'f', 'พ': 'ph',
    'ฟ': 'f', 'ม': 'm', 'ย': 'y', 'ร': 'r', 'ล': 'l', 'ว': 'w',
    'ส': 's', 'ห': 'h', 'อ': '', 'ฮ': 'h',
    'ะ': 'a', 'า': 'a', 'ิ': 'i', 'ี': 'i', 'ึ': 'ue', 'ื': 'ue',
    'ุ': 'u', 'ู': 'u', 'เ': 'e', 'แ': 'ae', 'โ': 'o', 'ใ': 'ai', 'ไ': 'ai',
  };

  static const Map<String, String> _hebrewMap = {
    'א': "'", 'ב': 'b', 'ג': 'g', 'ד': 'd', 'ה': 'h', 'ו': 'v', 'ז': 'z',
    'ח': 'ch', 'ט': 't', 'י': 'y', 'כ': 'k', 'ך': 'k', 'ל': 'l', 'מ': 'm',
    'ם': 'm', 'נ': 'n', 'ן': 'n', 'ס': 's', 'ע': "'", 'פ': 'p', 'ף': 'p',
    'צ': 'tz', 'ץ': 'tz', 'ק': 'k', 'ר': 'r', 'ש': 'sh', 'ת': 't',
  };

  static const Map<String, String> _gurmukhiRomanOverrides = {
    'ਸਾਰੇ': 'saare', 'ਰੰਗ': 'rang', 'ਵੇਖ': 'vekh', 'ਲਏ': 'lae',
    'ਹੁਣ': 'hun', 'ਕੋਈ': 'koi', 'ਨਹੀਂ': 'nahi', 'ਤੇਰੇ': 'tere',
    'ਦਿਲ': 'dil', 'ਮੇਰਾ': 'mera', 'ਤੇਰਾ': 'tera', 'ਜਾਣਾ': 'jaana',
    'ਜਾਣੀ': 'jaani', 'ਕਰਦੇ': 'karde', 'ਕਹਿੰਦੇ': 'kehnde', 'ਆਖੀਂ': 'aakheen',
    'ਸਜਣਾ': 'sajna', 'ਸਜਨਾ': 'sajna', 'ਪਿਆਰ': 'pyaar', 'ਇਸ਼ਕ': 'ishq',
    'ਵਿੱਚ': 'vich', 'ਨਾਲ': 'naal', 'ਹੈ': 'hai', 'ਸੀ': 'si',
  };
}
