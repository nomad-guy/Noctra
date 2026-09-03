part of '../devanagari_transliteration_service.dart';

/// Static phonetic mapping tables and distance metric for Devanagari transliteration.
class DevanagariPhoneticTables {
  DevanagariPhoneticTables._();

  static final List<List<String>> digraphs = [
    ['ksh', 'क्ष'],
    ['tr', 'त्र'],
    ['gyn', 'ज्ञ'],
    ['shr', 'श्र'],
    ['chh', 'छ'],
    ['kh', 'ख'],
    ['gh', 'घ'],
    ['ch', 'च'],
    ['jh', 'झ'],
    ['th', 'थ'],
    ['dh', 'ध'],
    ['ph', 'फ'],
    ['bh', 'भ'],
    ['sh', 'श'],
    ['ny', 'ञ'],
  ];

  static final List<List<String>> simpleConsonants = [
    ['k', 'क'],
    ['g', 'ग'],
    ['j', 'ज'],
    ['t', 'त'],
    ['d', 'द'],
    ['n', 'न'],
    ['p', 'प'],
    ['f', 'फ़'],
    ['b', 'ब'],
    ['m', 'म'],
    ['y', 'य'],
    ['r', 'र'],
    ['l', 'ल'],
    ['v', 'व'],
    ['w', 'व'],
    ['s', 'स'],
    ['h', 'ह'],
    ['z', 'ज़'],
    ['q', 'क़'],
  ];

  static final List<List<String>> retroflexCapitals = [
    ['Ksh', 'क्ष'],
    ['Tr', 'ट्र'],
    ['Th', 'ठ'],
    ['Dh', 'ढ'],
    ['Sh', 'ष'],
    ['T', 'ट'],
    ['D', 'ड'],
    ['N', 'ण'],
    ['R', 'ड़'],
  ];

  static final List<List<String>> vowelMatras = [
    ['aan', 'ां'],
    ['oon', 'ूं'],
    ['een', 'ीं'],
    ['ain', 'ैं'],
    ['aun', 'ौं'],
    ['aa', 'ा'],
    ['ii', 'ी'],
    ['ee', 'ी'],
    ['oo', 'ू'],
    ['uu', 'ू'],
    ['ai', 'ै'],
    ['au', 'ौ'],
    ['ei', 'ै'],
    ['a', ''],
    ['i', 'ि'],
    ['u', 'ु'],
    ['e', 'े'],
    ['o', 'ो'],
  ];

  static final List<List<String>> initialVowels = [
    ['aan', 'आं'],
    ['oon', 'ऊं'],
    ['een', 'ईं'],
    ['ain', 'ऐं'],
    ['aun', 'औं'],
    ['aa', 'आ'],
    ['ii', 'ई'],
    ['ee', 'ई'],
    ['oo', 'ऊ'],
    ['uu', 'ऊ'],
    ['ai', 'ऐ'],
    ['au', 'औ'],
    ['a', 'अ'],
    ['i', 'इ'],
    ['u', 'उ'],
    ['e', 'ए'],
    ['o', 'ओ'],
  ];

  /// Bounded Levenshtein distance metric.
  static int levenshtein(String a, String b, int maxDist) {
    if ((a.length - b.length).abs() > maxDist) return maxDist + 1;
    final la = a.length, lb = b.length;
    var prev = List<int>.generate(lb + 1, (j) => j);
    for (int i = 1; i <= la; i++) {
      final curr = List<int>.filled(lb + 1, 0);
      curr[0] = i;
      int rowMin = curr[0];
      for (int j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
        if (curr[j] < rowMin) rowMin = curr[j];
      }
      if (rowMin > maxDist) return maxDist + 1;
      prev = curr;
    }
    return prev[lb];
  }
}
