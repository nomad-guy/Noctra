/// Universal transliteration fallback engine.
///
/// Used when a script-specific engine fails. Applies a conservative
/// character-mapping approach for common scripts.

/// Universal fallback: best-effort character-by-character transliteration.
///
/// This is the last resort when a script-specific engine throws. It covers
/// the most common scripts with simple character mappings.
library;
class UniversalFallbackEngine {
  const UniversalFallbackEngine();

  static const Map<int, String> _fallbackMap = {
    // Cyrillic basic
    0x0410: 'A', 0x0411: 'B', 0x0412: 'V', 0x0413: 'G', 0x0414: 'D',
    0x0415: 'E', 0x0416: 'Zh', 0x0417: 'Z', 0x0418: 'I', 0x0419: 'Y',
    0x041A: 'K', 0x041B: 'L', 0x041C: 'M', 0x041D: 'N', 0x041E: 'O',
    0x041F: 'P', 0x0420: 'R', 0x0421: 'S', 0x0422: 'T', 0x0423: 'U',
    0x0424: 'F', 0x0425: 'Kh', 0x0426: 'Ts', 0x0427: 'Ch', 0x0428: 'Sh',
    0x0429: 'Shch', 0x042A: '', 0x042B: 'Y', 0x042C: '', 0x042D: 'E',
    0x042E: 'Yu', 0x042F: 'Ya',
    0x0430: 'a', 0x0431: 'b', 0x0432: 'v', 0x0433: 'g', 0x0434: 'd',
    0x0435: 'e', 0x0436: 'zh', 0x0437: 'z', 0x0438: 'i', 0x0439: 'y',
    0x043A: 'k', 0x043B: 'l', 0x043C: 'm', 0x043D: 'n', 0x043E: 'o',
    0x043F: 'p', 0x0440: 'r', 0x0441: 's', 0x0442: 't', 0x0443: 'u',
    0x0444: 'f', 0x0445: 'kh', 0x0446: 'ts', 0x0447: 'ch', 0x0448: 'sh',
    0x0449: 'shch', 0x044A: '', 0x044B: 'y', 0x044C: '', 0x044D: 'e',
    0x044E: 'yu', 0x044F: 'ya',
    // Ukrainian extras
    0x0406: 'i', 0x0407: 'yi', 0x0404: 'ye', 0x0490: 'g',
    0x0456: 'i', 0x0457: 'yi', 0x0454: 'ye', 0x0491: 'g',
  };

  /// Attempt universal transliteration. Returns original on failure.
  static String transliterate(String line) {
    final buf = StringBuffer();
    for (final rune in line.runes) {
      final mapped = _fallbackMap[rune];
      if (mapped != null) {
        buf.write(mapped);
      } else if (rune < 0x0080) {
        buf.write(String.fromCharCode(rune));
      } else {
        // Unknown character — keep as-is
        buf.write(String.fromCharCode(rune));
      }
    }
    return buf.toString();
  }
}
