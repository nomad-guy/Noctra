import 'lyrics_service.dart';

class DevanagariTransliterationService {
  static final Map<String, String> _lexicon = {
    'tere': 'तेरे', 'mera': 'मेरा', 'meri': 'मेरी', 'mere': 'मेरे', 'tum': 'तुम',
    'hum': 'हम', 'aap': 'आप', 'hai': 'है', 'hain': 'हैं', 'ho': 'हो', 'tha': 'था',
    'the': 'थे', 'thi': 'थी', 'dil': 'दिल', 'ishq': 'इश्क़', 'pyaar': 'प्यार',
    'mohabbat': 'मोहब्बत', 'zindagi': 'ज़िंदगी', 'khuda': 'ख़ुदा', 'rabba': 'रब्बा',
    'naina': 'नैना', 'aankhen': 'आँखें', 'raat': 'रात', 'din': 'दिन', 'sanam': 'सनम',
    'jaana': 'जाना', 'deewana': 'दीवाना', 'sukoon': 'सुकून', 'dard': 'दर्द',
    'duniya': 'दुनिया', 'kahan': 'कहाँ', 'jahan': 'जहाँ', 'tu': 'तू', 'kya': 'क्या',
    'kyun': 'क्यों', 'kaise': 'कैसे', 'nahi': 'नहीं', 'nahin': 'नहीं', 'mat': 'मत',
    'saath': 'साथ', 'paas': 'पास', 'door': 'दूर', 'yaad': 'याद', 'baat': 'बात',
    'khwab': 'ख़्वाब', 'rooh': 'रूह', 'safar': 'सफ़र', 'humsafar': 'हमसफ़र',
    'love': 'लव', 'baby': 'बेबी', 'night': 'नाइट', 'starboy': 'स्टारबॉय',
    'feel': 'फ़ील', 'coming': 'कमिंग', 'never': 'नेवर', 'forever': 'फ़ॉरएवर',
    'heart': 'हार्ट', 'time': 'टाइम', 'dream': 'ड्रीम', 'music': 'म्यूज़िक',
  };

  static final List<List<String>> _consonants = [
    ['kh', 'ख़'], ['gh', 'ग़'], ['ch', 'च'], ['chh', 'छ'], ['jh', 'झ'],
    ['th', 'थ'], ['dh', 'ध'], ['ph', 'फ़'], ['bh', 'भ'], ['sh', 'श'],
    ['k', 'क'], ['g', 'ग'], ['j', 'ज'], ['t', 'त'], ['d', 'द'],
    ['n', 'न'], ['p', 'प'], ['f', 'फ़'], ['b', 'ब'], ['m', 'म'],
    ['y', 'य'], ['r', 'र'], ['l', 'ल'], ['v', 'व'], ['w', 'व'],
    ['s', 'स'], ['h', 'ह'], ['z', 'ज़'], ['q', 'क़'],
  ];

  static final List<List<String>> _matras = [
    ['aa', 'ा'], ['ee', 'ी'], ['oo', 'ू'], ['ai', 'ै'], ['au', 'ौ'],
    ['a', ''], ['i', 'ि'], ['u', 'ु'], ['e', 'े'], ['o', 'ो'],
  ];

  static final List<List<String>> _initialVowels = [
    ['aa', 'आ'], ['ee', 'ई'], ['oo', 'ऊ'], ['ai', 'ऐ'], ['au', 'औ'],
    ['a', 'अ'], ['i', 'इ'], ['u', 'उ'], ['e', 'ए'], ['o', 'ओ'],
  ];

  static String toDevanagari(String text) {
    if (text.trim().isEmpty) return text;
    final words = text.split(' ');
    final converted = words.map((w) => _convertWordToDevanagari(w)).toList();
    return converted.join(' ');
  }

  static String _convertWordToDevanagari(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    if (clean.isEmpty) return word;
    if (_lexicon.containsKey(clean)) {
      final dev = _lexicon[clean]!;
      return word.replaceAll(RegExp(clean, caseSensitive: false), dev);
    }
    String s = clean;
    final buf = StringBuffer();
    int idx = 0;
    while (idx < s.length) {
      if (idx == 0) {
        bool matchedVowel = false;
        for (final v in _initialVowels) {
          if (s.startsWith(v[0], idx)) {
            buf.write(v[1]);
            idx += v[0].length;
            matchedVowel = true;
            break;
          }
        }
        if (matchedVowel) continue;
      }
      bool matchedConsonant = false;
      for (final c in _consonants) {
        if (s.startsWith(c[0], idx)) {
          buf.write(c[1]);
          idx += c[0].length;
          bool matchedMatra = false;
          for (final m in _matras) {
            if (s.startsWith(m[0], idx)) {
              buf.write(m[1]);
              idx += m[0].length;
              matchedMatra = true;
              break;
            }
          }
          if (!matchedMatra && idx < s.length && !_isVowel(s[idx])) {
            buf.write('्');
          }
          matchedConsonant = true;
          break;
        }
      }
      if (!matchedConsonant) {
        buf.write(s[idx]);
        idx++;
      }
    }
    return buf.toString();
  }

  static bool _isVowel(String ch) => 'aeiou'.contains(ch.toLowerCase());

  static LyricsData transliterateLyrics(LyricsData data, String targetScript) {
    if (targetScript == 'devanagari') {
      final newLines = data.lines.map((l) => LyricLine(timestamp: l.timestamp, text: toDevanagari(l.text))).toList();
      final newPlain = data.lines.isNotEmpty ? newLines.map((l) => l.text).join('\n') : toDevanagari(data.plainText);
      return LyricsData(isSynced: data.isSynced, lines: newLines, plainText: newPlain);
    }
    return data;
  }
}
