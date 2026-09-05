import '../lyrics_service.dart';

enum LyricScript {
  latin,
  japanese,
  korean,
  chinese,
  cyrillic,
  arabic,
  greek,
  thai,
  hebrew,
  devanagari,
  gurmukhi,
  bengali,
  tamil,
  telugu,
  gujarati,
  kannada,
  malayalam,
  odia,
}

class ScriptOption {
  final String code;
  final String label;
  const ScriptOption({required this.code, required this.label});
}

class LyricScriptDetector {
  static LyricScript detectScript(String text) {
    int devanagariCount = 0;
    int gurmukhiCount = 0;
    int bengaliCount = 0;
    int tamilCount = 0;
    int teluguCount = 0;
    int gujaratiCount = 0;
    int kannadaCount = 0;
    int malayalamCount = 0;
    int odiaCount = 0;
    int japaneseCount = 0;
    int koreanCount = 0;
    int chineseCount = 0;
    int cyrillicCount = 0;
    int arabicCount = 0;
    int greekCount = 0;
    int thaiCount = 0;
    int hebrewCount = 0;

    for (final rune in text.runes) {
      if (rune >= 0x0900 && rune <= 0x097F) {
        devanagariCount++;
      } else if (rune >= 0x0A00 && rune <= 0x0A7F) {
        gurmukhiCount++;
      } else if (rune >= 0x0980 && rune <= 0x09FF) {
        bengaliCount++;
      } else if (rune >= 0x0B80 && rune <= 0x0BFF) {
        tamilCount++;
      } else if (rune >= 0x0C00 && rune <= 0x0C7F) {
        teluguCount++;
      } else if (rune >= 0x0A80 && rune <= 0x0AFF) {
        gujaratiCount++;
      } else if (rune >= 0x0C80 && rune <= 0x0CFF) {
        kannadaCount++;
      } else if (rune >= 0x0D00 && rune <= 0x0D7F) {
        malayalamCount++;
      } else if (rune >= 0x0B00 && rune <= 0x0B7F) {
        odiaCount++;
      } else if ((rune >= 0x3040 && rune <= 0x309F) ||
          (rune >= 0x30A0 && rune <= 0x30FF)) {
        japaneseCount++;
      } else if ((rune >= 0xAC00 && rune <= 0xD7AF) ||
          (rune >= 0x1100 && rune <= 0x11FF) ||
          (rune >= 0x3130 && rune <= 0x318F)) {
        koreanCount++;
      } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
        chineseCount++;
      } else if (rune >= 0x0400 && rune <= 0x04FF) {
        cyrillicCount++;
      } else if ((rune >= 0x0600 && rune <= 0x06FF) ||
          (rune >= 0x0750 && rune <= 0x077F) ||
          (rune >= 0xFB50 && rune <= 0xFDFF)) {
        arabicCount++;
      } else if (rune >= 0x0370 && rune <= 0x03FF) {
        greekCount++;
      } else if (rune >= 0x0E00 && rune <= 0x0E7F) {
        thaiCount++;
      } else if (rune >= 0x0590 && rune <= 0x05FF) {
        hebrewCount++;
      }
    }

    if (japaneseCount > 0) return LyricScript.japanese;
    if (koreanCount > 0) return LyricScript.korean;
    if (chineseCount > 10 && japaneseCount == 0) return LyricScript.chinese;
    if (devanagariCount > 0) return LyricScript.devanagari;
    if (gurmukhiCount > 0) return LyricScript.gurmukhi;
    if (tamilCount > 0) return LyricScript.tamil;
    if (teluguCount > 0) return LyricScript.telugu;
    if (bengaliCount > 0) return LyricScript.bengali;
    if (gujaratiCount > 0) return LyricScript.gujarati;
    if (kannadaCount > 0) return LyricScript.kannada;
    if (malayalamCount > 0) return LyricScript.malayalam;
    if (odiaCount > 0) return LyricScript.odia;
    if (cyrillicCount > 0) return LyricScript.cyrillic;
    if (arabicCount > 0) return LyricScript.arabic;
    if (greekCount > 0) return LyricScript.greek;
    if (thaiCount > 0) return LyricScript.thai;
    if (hebrewCount > 0) return LyricScript.hebrew;

    return LyricScript.latin;
  }

  static List<ScriptOption> getAvailableScriptOptions(LyricsData data) {
    final sample = data.lines.isNotEmpty
        ? data.lines.map((l) => l.text).take(10).join(' ')
        : data.plainText;
    final script = detectScript(sample);

    switch (script) {
      case LyricScript.japanese:
        return const [
          ScriptOption(code: 'original', label: 'Original (日本語)'),
          ScriptOption(code: 'roman', label: 'Romaji (Latin)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.korean:
        return const [
          ScriptOption(code: 'original', label: 'Original (한국어)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.chinese:
        return const [
          ScriptOption(code: 'original', label: 'Original (中文)'),
          ScriptOption(code: 'roman', label: 'Pinyin'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.cyrillic:
        return const [
          ScriptOption(code: 'original', label: 'Original (Русский)'),
          ScriptOption(code: 'roman', label: 'Romanized (Latin)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.arabic:
        return const [
          ScriptOption(code: 'original', label: 'Original (العربية)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.greek:
        return const [
          ScriptOption(code: 'original', label: 'Original (Ελληνικά)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ];
      case LyricScript.thai:
        return const [
          ScriptOption(code: 'original', label: 'Original (ไทย)'),
          ScriptOption(code: 'roman', label: 'Romanized (RTGS)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ];
      case LyricScript.hebrew:
        return const [
          ScriptOption(code: 'original', label: 'Original (עברית)'),
          ScriptOption(code: 'roman', label: 'Romanized'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी'),
        ];
      case LyricScript.devanagari:
        return const [
          ScriptOption(code: 'original', label: 'मूल (देवनागरी)'),
          ScriptOption(code: 'roman', label: 'Roman (English)'),
        ];
      case LyricScript.gurmukhi:
        return const [
          ScriptOption(code: 'original', label: 'ਮੂਲ (ਪੰਜਾਬੀ)'),
          ScriptOption(code: 'roman', label: 'Roman (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.tamil:
      case LyricScript.telugu:
      case LyricScript.bengali:
      case LyricScript.gujarati:
      case LyricScript.kannada:
      case LyricScript.malayalam:
      case LyricScript.odia:
        return const [
          ScriptOption(code: 'original', label: 'Original Script'),
          ScriptOption(code: 'roman', label: 'Romanized (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
      case LyricScript.latin:
        return const [
          ScriptOption(code: 'original', label: 'Original (English)'),
          ScriptOption(code: 'devanagari', label: 'देवनागरी (Hindi)'),
        ];
    }
  }
}
