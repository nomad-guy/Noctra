part 'parts/canonical_script_matrix.dart';

enum TokenType { consonant, vowel, matra, modifier, literal }

class PhoneticToken {
  final String key;
  final TokenType type;
  const PhoneticToken(this.key, this.type);
}

class ScriptDefinition {
  final Map<String, String> consonants;
  final Map<String, String> vowels;
  final Map<String, String> matras;
  final Map<String, String> modifiers;

  final Map<String, String> reverseConsonants = {};
  final Map<String, String> reverseVowels = {};
  final Map<String, String> reverseMatras = {};
  final Map<String, String> reverseModifiers = {};

  final Map<String, PhoneticToken> allMatches = {};
  final List<String> sortedKeys = [];

  ScriptDefinition({
    required this.consonants,
    required this.vowels,
    required this.matras,
    required this.modifiers,
  }) {
    consonants.forEach((k, v) => reverseConsonants[v] = k);
    vowels.forEach((k, v) => reverseVowels[v] = k);
    matras.forEach((k, v) => reverseMatras[v] = k);
    modifiers.forEach((k, v) => reverseModifiers[v] = k);

    reverseVowels.forEach(
        (k, v) => allMatches[k] = PhoneticToken(v, TokenType.vowel));
    reverseMatras.forEach(
        (k, v) => allMatches[k] = PhoneticToken(v, TokenType.matra));
    reverseModifiers.forEach(
        (k, v) => allMatches[k] = PhoneticToken(v, TokenType.modifier));

    final virama = modifiers['virama'] ?? '';
    consonants.forEach((canonicalKey, grapheme) {
      final bare = grapheme.replaceAll(virama, '');
      if (bare.isNotEmpty) {
        allMatches[bare] = PhoneticToken(canonicalKey, TokenType.consonant);
      }
      allMatches[grapheme] = PhoneticToken(canonicalKey, TokenType.consonant);
    });

    sortedKeys
      ..addAll(allMatches.keys)
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  factory ScriptDefinition.fromMap(Map<String, dynamic> map) {
    return ScriptDefinition(
      consonants: Map<String, String>.from(map['consonants'] as Map),
      vowels: Map<String, String>.from(map['vowels'] as Map),
      matras: Map<String, String>.from(map['matras'] as Map),
      modifiers: Map<String, String>.from(map['modifiers'] as Map),
    );
  }
}

/// Standalone, zero-dependency phonetic matrix engine for high-speed lyrics transliteration.
class AksharaEngine {
  AksharaEngine._();
  static final AksharaEngine instance = AksharaEngine._();

  final Map<String, ScriptDefinition> _scripts = {};
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    canonicalScriptMatrix.forEach((scriptName, data) {
      _scripts[scriptName.toLowerCase()] = ScriptDefinition.fromMap(data);
    });
    _initialized = true;
  }

  bool supports(String script) {
    _ensureInitialized();
    return _scripts.containsKey(script.toLowerCase().trim());
  }

  List<PhoneticToken> tokenize(String text, String sourceScript) {
    _ensureInitialized();
    final key = sourceScript.toLowerCase().trim();
    final def = _scripts[key];
    if (def == null) {
      return [PhoneticToken(text, TokenType.literal)];
    }

    final tokens = <PhoneticToken>[];
    int i = 0;
    final int n = text.length;

    while (i < n) {
      bool matched = false;
      for (final matchKey in def.sortedKeys) {
        if (text.startsWith(matchKey, i)) {
          tokens.add(def.allMatches[matchKey]!);
          i += matchKey.length;
          matched = true;
          break;
        }
      }
      if (!matched) {
        tokens.add(PhoneticToken(text[i], TokenType.literal));
        i++;
      }
    }
    return tokens;
  }

  String synthesize(List<PhoneticToken> tokens, String targetScript) {
    _ensureInitialized();
    final target = targetScript.toLowerCase().trim();
    final def = _scripts[target];
    if (def == null) {
      return tokens.map((t) => t.key).join();
    }

    final buffer = StringBuffer();
    final virama = def.modifiers['virama'] ?? '';

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      switch (token.type) {
        case TokenType.vowel:
          buffer.write(def.vowels[token.key] ?? token.key);
          break;

        case TokenType.matra:
          if (target == "urdu" &&
              (token.key == "e" || token.key == "ē" || token.key == "ai")) {
            final isFinal = (i + 1 == tokens.length) ||
                tokens[i + 1].type == TokenType.literal;
            buffer.write(isFinal ? "ے" : "ی");
          } else {
            buffer.write(def.matras[token.key] ?? token.key);
          }
          break;

        case TokenType.modifier:
          buffer.write(def.modifiers[token.key] ?? token.key);
          break;

        case TokenType.consonant:
          final rawConsonant = def.consonants[token.key] ?? token.key;
          final nextToken = (i + 1 < tokens.length) ? tokens[i + 1] : null;

          if (target == "iast") {
            buffer.write(rawConsonant);
            if (nextToken == null ||
                (nextToken.type != TokenType.matra &&
                    nextToken.key != "virama")) {
              final isWordEnd =
                  nextToken == null || nextToken.type == TokenType.literal;
              if (!isWordEnd) {
                buffer.write("a");
              }
            }
          } else if (target == "urdu") {
            buffer.write(rawConsonant.replaceAll(virama, ''));
          } else {
            if (nextToken != null && nextToken.type == TokenType.matra) {
              buffer.write(rawConsonant.replaceAll(virama, ''));
            } else if (nextToken != null && nextToken.key == "virama") {
              buffer.write(rawConsonant);
              i++;
            } else {
              buffer.write(rawConsonant.replaceAll(virama, ''));
            }
          }
          break;

        case TokenType.literal:
          buffer.write(token.key);
          break;
      }
    }

    return buffer.toString();
  }

  String convert(String text, {required String from, required String to}) {
    if (text.trim().isEmpty || from.toLowerCase() == to.toLowerCase()) {
      return text;
    }
    final intermediate = tokenize(text, from);
    return synthesize(intermediate, to);
  }
}
