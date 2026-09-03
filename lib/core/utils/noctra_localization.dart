import 'localization/localization_strings_north.dart';
import 'localization/localization_strings_south_east.dart';

/// Full i18n system for Noctra.
/// Supported: English, Hindi, Punjabi, Urdu, Kannada, Tamil, Marathi, Odia
class NoctraLocalization {
  static String currentLanguage = 'en';

  /// All supported languages with display names.
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

  /// Language codes for the settings UI.
  static List<String> get availableLanguages =>
      supportedLanguages.keys.toList();

  /// Get display name for a language code.
  static String languageName(String code) =>
      _localizedValues[code]?['lang_name'] ??
      _localizedValues['en']?[code] ??
      code;

  static final Map<String, Map<String, String>> _localizedValues = {
    ...LocalizationStringsNorth.values,
    ...LocalizationStringsSouthEast.values,
  };

  static String tr(String key) {
    return _localizedValues[currentLanguage]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}
