import 'package:flutter/widgets.dart';
import 'localization/languages/english.dart';
import 'localization/languages/hindi.dart';
import 'localization/languages/kannada.dart';
import 'localization/languages/marathi.dart';
import 'localization/languages/odia.dart';
import 'localization/languages/punjabi.dart';
import 'localization/languages/tamil.dart';
import 'localization/languages/urdu.dart';

/// Complete System-Wide i18n Localization Engine for Noctra.
/// Supports 8 Indian and Global languages with native scripts and RTL Urdu.
class NoctraLocalization {
  static String currentLanguage = 'en';

  /// Supported languages with their native display script.
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'pa': 'ਪੰਜਾਬੀ',
    'ur': 'اردو',
    'kn': 'ಕನ್ನಡ',
    'ta': 'தமிழ்',
    'mr': 'मराठी',
    'or': 'ଓଡ଼ିଆ',
  };

  /// Language codes available for selection.
  static List<String> get availableLanguages =>
      supportedLanguages.keys.toList();

  /// Native display name for a language code.
  static String languageName(String code) =>
      supportedLanguages[code] ?? code;

  /// Whether the specified or current language uses right-to-left layout.
  static bool isRtl([String? lang]) => (lang ?? currentLanguage) == 'ur';

  /// Returns the appropriate TextDirection for the language.
  static TextDirection textDirection([String? lang]) =>
      isRtl(lang) ? TextDirection.rtl : TextDirection.ltr;

  static final Map<String, Map<String, String>> _dictionaries = {
    'en': englishLocale,
    'hi': hindiLocale,
    'pa': punjabiLocale,
    'ur': urduLocale,
    'kn': kannadaLocale,
    'ta': tamilLocale,
    'mr': marathiLocale,
    'or': odiaLocale,
  };

  /// Resolves a localized string by [key], falling back to English, with
  /// dynamic parameter interpolation for tokens like `{count}`, `{query}`, etc.
  static String tr(
    String key, {
    String? language,
    Map<String, dynamic>? args,
  }) {
    final lang = language ?? currentLanguage;
    final raw = _dictionaries[lang]?[key] ??
        _dictionaries['en']?[key] ??
        key;

    if (args == null || args.isEmpty) return raw;

    var formatted = raw;
    for (final entry in args.entries) {
      formatted = formatted.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return formatted;
  }
}
