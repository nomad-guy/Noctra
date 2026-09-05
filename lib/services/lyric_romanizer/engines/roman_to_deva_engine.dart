/// Roman-to-Devanagari romanizer engine.
///
/// Converts Romanized/Hindi transliterated text back to Devanagari script
/// using the existing DevanagariTransliterationEngine's rule-based phonetic
/// parser + dynamic lexicon.
///
/// This is the inverse of the Devanagari→Roman romanizer in the same package.

library;
import '../../lyrics/devanagari_transliteration_service.dart';

/// Roman-to-Devanagari engine.
///
/// Wraps the existing [DevanagariTransliterationEngine] to provide a
/// drop-in engine for the lyric_romanizer orchestrator. When a user
/// wants to view lyrics in Devanagari but the source is Romanized
/// Hindi/Urdu, this engine handles the conversion.
class RomanToDevaEngine {
  RomanToDevaEngine._();

  static final DevanagariTransliterationEngine _engine =
      DevanagariTransliterationEngine();

  /// Convert a single Romanized line to Devanagari.
  static String romanToDevanagari(String line) {
    return _engine.toDevanagari(line);
  }

  /// Teach the engine a new word mapping.
  static void learnWord(String romanWord, String devanagari) {
    _engine.learnWord(romanWord, devanagari);
  }
}
