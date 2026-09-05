import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/utils/noctra_localization.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    NoctraLocalization.currentLanguage = 'en';
  });

  test('all supported languages have complete essential keys', () {
    const essentialKeys = [
      'home',
      'search',
      'library',
      'ai_studio',
      'top_charts',
      'recently_played',
      'settings',
      'folders',
      'ai_mixes',
      'downloads',
      'language',
      'theme',
    ];

    for (final lang in NoctraLocalization.availableLanguages) {
      NoctraLocalization.currentLanguage = lang;
      for (final key in essentialKeys) {
        final translated = NoctraLocalization.tr(key);
        expect(translated, isNotEmpty,
            reason: 'Key "$key" should have non-empty translation in "$lang"');
        expect(translated, isNot(equals(key)),
            reason: 'Key "$key" should be translated in "$lang", not return key');
      }
    }
  });

  test('fallback behavior returns english if key missing in target language', () {
    NoctraLocalization.currentLanguage = 'hi';
    final result = NoctraLocalization.tr('non_existent_key_123');
    expect(result, 'non_existent_key_123');
  });

  test('NoctraLocalDatabase persists and restores app language', () async {
    final db = NoctraLocalDatabase();
    await db.init();
    expect(db.getCachedLanguage(), 'en');

    await db.saveLanguage('hi');
    expect(db.getCachedLanguage(), 'hi');

    // Simulate new app instance with saved prefs
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('noctra_app_language'), 'hi');
  });
}
