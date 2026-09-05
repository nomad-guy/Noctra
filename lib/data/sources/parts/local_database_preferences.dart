part of '../noctra_local_database.dart';

extension LocalDatabasePreferences on NoctraLocalDatabase {
  String getCachedLanguage() {
    try {
      return _prefs?.getString('noctra_app_language') ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  Future<void> saveLanguage(String languageCode) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_app_language', languageCode);
      } catch (e) {
        NoctraLogger.w('Failed to persist app language', e);
      }
    });
  }

  String getCachedThemeMode() => _cachedThemeMode;

  Future<void> saveCachedThemeMode(String modeName) => saveThemeMode(modeName);

  Future<void> saveThemeMode(String mode) {
    final clean = NoctraLocalDatabase.normalizeThemeMode(mode);
    _cachedThemeMode = clean;
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_theme_mode', clean);
      } catch (e) {
        NoctraLogger.e('Failed to persist theme mode', e);
      }
    });
  }

  String getCachedDownloadLocation() {
    try {
      return _prefs?.getString('noctra_download_location') ??
          DownloadLocation.appDocs;
    } catch (_) {
      return DownloadLocation.appDocs;
    }
  }

  Future<void> saveDownloadLocation(String key) {
    return _enqueuePrefsWrite(() async {
      try {
        final prefs = _prefs ?? await SharedPreferences.getInstance();
        _prefs = prefs;
        await prefs.setString('noctra_download_location', key);
      } catch (e) {
        NoctraLogger.w('Failed to persist download location', e);
      }
    });
  }
}
