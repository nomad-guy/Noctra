import 'dart:convert';

/// Manages the Hindustani -> Devanagari word lexicon at runtime.
///
/// Three layers, checked in this priority order (highest first):
///   1. `_userOverrides`   — words the user/app has taught it (e.g. manual
///                           corrections in the UI). Always wins.
///   2. `_runtimeAdditions` — words merged in from a JSON source (server,
///                           local file, CDN) after the app has started, so
///                           the dictionary can grow without a release.
///   3. `_builtIn`          — the shipped default lexicon. Always available,
///                           works fully offline.
///
/// This class does no I/O itself — the host app decides *how* loading and
/// persistence happen (asset bundle, HTTP, SharedPreferences, Hive, a
/// backend...) via `loadFromJson` / `exportUserOverrides` / `onWordLearned`.
/// That keeps this file pure Dart with zero Flutter/platform dependencies,
/// so it's easy to unit test.
class DynamicLexicon {
  DynamicLexicon({Map<String, String>? seed})
      : _builtIn = Map.unmodifiable(seed ?? defaultBuiltIn);

  final Map<String, String> _builtIn;
  final Map<String, String> _runtimeAdditions = {};
  final Map<String, String> _userOverrides = {};

  /// Fired whenever a word is learned (added or overridden), so the host app
  /// can persist it — e.g. write-through to disk, or sync to a backend so
  /// corrections benefit every user.
  void Function(String key, String devanagari)? onWordLearned;

  String? lookup(String romanWord) {
    final key = romanWord.toLowerCase();
    return _userOverrides[key] ?? _runtimeAdditions[key] ?? _builtIn[key];
  }

  bool contains(String romanWord) => lookup(romanWord) != null;

  /// Merge a batch of words fetched at runtime, e.g. a lexicon JSON hosted
  /// on a CDN that you refresh periodically so new slang/artists' spellings
  /// land without an app store release.
  ///
  /// Pass [asUserOverride]=true to instead treat the batch as corrections
  /// (highest priority) — useful when importing a curated fix-list.
  void loadFromJson(String json, {bool asUserOverride = false}) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final target = asUserOverride ? _userOverrides : _runtimeAdditions;
    decoded.forEach((k, v) => target[k.toString().toLowerCase()] = v.toString());
  }

  /// Teach the engine one word — e.g. the user tapped a suggested word in
  /// the lyric line, edited it, and you want the engine to get it right
  /// next time (this session and, once persisted, forever).
  void learnWord(String romanWord, String devanagari) {
    final key = romanWord.toLowerCase();
    _userOverrides[key] = devanagari;
    onWordLearned?.call(key, devanagari);
  }

  void forgetOverride(String romanWord) =>
      _userOverrides.remove(romanWord.toLowerCase());

  /// Persist just the user-taught corrections (small, cheap to save on
  /// every change) — restore with [restoreUserOverrides] on next launch.
  String exportUserOverrides() => jsonEncode(_userOverrides);

  void restoreUserOverrides(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    _userOverrides
      ..clear()
      ..addAll(decoded.map((k, v) => MapEntry(k.toString().toLowerCase(), v.toString())));
  }

  /// All known Roman keys across every layer — used by the engine for fuzzy
  /// (near-miss spelling) lookups.
  Iterable<String> get allKeys =>
      {..._builtIn.keys, ..._runtimeAdditions.keys, ..._userOverrides.keys};

  int get size => allKeys.length;

  // Shipped default lexicon — same word list the engine originally had
  // hardcoded, now just the seed for layer 3 instead of the only layer.
  static const Map<String, String> defaultBuiltIn = {
    // Pronouns & copula
    'tere': 'तेरे', 'tera': 'तेरा', 'teri': 'तेरी', 'mera': 'मेरा', 'meri': 'मेरी', 'mere': 'मेरे',
    'tum': 'तुम', 'hum': 'हम', 'aap': 'आप', 'main': 'मैं', 'mujhe': 'मुझे', 'mujhse': 'मुझसे',
    'tumhe': 'तुम्हें', 'tumhara': 'तुम्हारा', 'tumhari': 'तुम्हारी', 'tumhare': 'तुम्हारे',
    'unhe': 'उन्हें', 'usse': 'उससे', 'use': 'उसे', 'usne': 'उसने', 'humne': 'हमने', 'maine': 'मैंने',
    'tumne': 'तुमने', 'unhone': 'उन्होंने', 'apna': 'अपना', 'apni': 'अपनी', 'apne': 'अपने',
    'woh': 'वो', 'wo': 'वो', 'yeh': 'यह', 'ye': 'ये', 'jo': 'जो', 'koi': 'कोई', 'koyi': 'कोई',
    'tujhe': 'तुझे', 'tujhse': 'तुझसे', 'tujhko': 'तुझको', 'mujhko': 'मुझको', 'humko': 'हमको', 'unko': 'उनको',
    'kisko': 'किसको', 'jisko': 'जिसको', 'kise': 'किसे', 'jise': 'जिसे', 'sabko': 'सबको',
    'tu': 'तू', 'tuhi': 'तू ही', 'meraa': 'मेरा',
    // Verbs & conjugations
    'hai': 'है', 'hain': 'हैं', 'ho': 'हो', 'tha': 'था', 'the': 'थे', 'thi': 'थी',
    'hoga': 'होगा', 'hogi': 'होगी', 'honge': 'होंगे', 'kar': 'कर', 'karo': 'करो',
    'karna': 'करना', 'karta': 'करता', 'karti': 'करती', 'karte': 'करते', 'kiya': 'किया', 'kiye': 'किए',
    'aya': 'आया', 'aaya': 'आया', 'aayi': 'आई', 'aaye': 'आए', 'jana': 'जाना', 'jaana': 'जाना',
    'jao': 'जाओ', 'gaya': 'गया', 'gayi': 'गई', 'gaye': 'गए', 'raha': 'रहा', 'rahi': 'रही',
    'rahe': 'रहे', 'suno': 'सुनो', 'dekho': 'देखो', 'dekha': 'देखा', 'dekhi': 'देखी',
    'chahta': 'चाहता', 'chahti': 'चाहती', 'chahiye': 'चाहिए', 'chahun': 'चाहूँ', 'chaha': 'चाहा',
    'chhod': 'छोड़', 'chhodna': 'छोड़ना', 'maan': 'मान', 'bol': 'बोल', 'bolo': 'बोलो', 'bole': 'बोले',
    'sochta': 'सोचता', 'socho': 'सोचो', 'bhula': 'भुला', 'bhulana': 'भुलाना', 'bhulaa': 'भुला',
    // Emotions & feelings
    'dil': 'दिल', 'ishq': 'इश्क़', 'pyaar': 'प्यार', 'pyar': 'प्यार', 'mohabbat': 'मोहब्बत',
    'zindagi': 'ज़िंदगी', 'khuda': 'ख़ुदा', 'rabba': 'रब्बा', 'rab': 'रब', 'naina': 'नैना',
    'aankhen': 'आँखें', 'aankhein': 'आँखें', 'dard': 'दर्द', 'sukoon': 'सुकून',
    'khushi': 'ख़ुशी', 'gham': 'ग़म', 'aansu': 'आँसू', 'roona': 'रोना', 'rona': 'रोना',
    'hasna': 'हँसना', 'hans': 'हँस', 'muskurana': 'मुस्कुराना', 'tadap': 'तड़प',
    'intezaar': 'इंतेज़ार', 'armaan': 'अरमान', 'sapna': 'सपना', 'sapne': 'सपने',
    'khwab': 'ख़्वाब', 'khwaab': 'ख़्वाब', 'arzoo': 'आरज़ू', 'tamanna': 'तमन्ना',
    'chahat': 'चाहत', 'junoon': 'जूनून', 'dhadkan': 'धड़कन', 'saansein': 'साँसें', 'saans': 'साँस',
    'fitoor': 'फ़ितूर', 'kashish': 'कशिश', 'mehfil': 'महफ़िल', 'nazar': 'नज़र', 'nazrein': 'नज़रें',
    'bekhayali': 'बेख़याली', 'khairiyat': 'ख़ैरियत', 'hawayein': 'हवाएँ', 'kesariya': 'केसरिया',
    // Nature & time
    'raat': 'रात', 'raatein': 'रातें', 'din': 'दिन', 'shaam': 'शाम', 'subah': 'सुबह', 'kal': 'कल',
    'aaj': 'आज', 'pal': 'पल', 'waqt': 'वक़्त', 'samay': 'समय', 'zamana': 'ज़माना',
    'baad': 'बाद', 'pehle': 'पहले', 'ab': 'अब', 'kabhi': 'कभी', 'hamesha': 'हमेशा',
    'chand': 'चाँद', 'sitara': 'सितारा', 'sitare': 'सितारे', 'tara': 'तारा', 'suraj': 'सूरज',
    'aasman': 'आसमान', 'bijli': 'बिजली', 'baarish': 'बारिश', 'barsat': 'बरसात', 'hawa': 'हवा',
    'lamha': 'लम्हा', 'lamhe': 'लम्हे', 'khamoshi': 'ख़ामोशी', 'awaz': 'आवाज़', 'awaaz': 'आवाज़',
    // Relationship words & Punjabi/Sufi
    'sanam': 'सनम', 'yaar': 'यार', 'yaara': 'यारा', 'dost': 'दोस्त', 'dildar': 'दिलदार', 'jaaneman': 'जानेमन',
    'jaan': 'जान', 'priya': 'प्रिया', 'dilber': 'दिलबर', 'humsafar': 'हमसफ़र',
    'mehboob': 'महबूब', 'mehbooba': 'महबूबा', 'piya': 'पिया', 'sajan': 'साजन',
    'sajni': 'सजनी', 'mahi': 'माही', 'makhna': 'मखना', 'ranjha': 'रांझा', 'heer': 'हीर',
    'raanjhana': 'रांझणा', 'manwa': 'मनवा', 'jiyara': 'जियरा', 've': 'वे',
    // Common connectors & adverbs
    'aur': 'और', 'lekin': 'लेकिन', 'par': 'पर', 'magar': 'मगर', 'phir': 'फिर',
    'bhi': 'भी', 'hi': 'ही', 'toh': 'तो', 'to': 'तो', 'se': 'से', 'mein': 'में',
    'ne': 'ने', 'ko': 'को', 'ka': 'का', 'ki': 'की', 'ke': 'के',
    'na': 'ना', 'nahi': 'नहीं', 'nahin': 'नहीं', 'mat': 'मत', 'kuch': 'कुछ',
    'sab': 'सब', 'bahut': 'बहुत', 'thoda': 'थोड़ा', 'zyada': 'ज़्यादा', 'kam': 'कम',
    'aisa': 'ऐसा', 'aisi': 'ऐसी', 'aise': 'ऐसे', 'waisa': 'वैसा', 'kaisi': 'कैसी', 'kaise': 'कैसे',
    // Places & movement
    'saath': 'साथ', 'paas': 'पास', 'door': 'दूर', 'yaad': 'याद', 'yaadein': 'यादें', 'baat': 'बात', 'baatein': 'बातें',
    'duniya': 'दुनिया', 'kahan': 'कहाँ', 'jahan': 'जहाँ', 'yahan': 'यहाँ', 'wahan': 'वहाँ',
    'safar': 'सफ़र', 'raah': 'राह', 'raahein': 'राहें', 'manzil': 'मंज़िल', 'rasta': 'रास्ता',
    // Spiritual / Sufi
    'rooh': 'रूह', 'atma': 'आत्मा', 'allah': 'अल्लाह', 'ishwar': 'ईश्वर',
    'dua': 'दुआ', 'takdir': 'तक़दीर', 'naseeb': 'नसीब', 'kismat': 'क़िस्मत',
    // Questions
    'kya': 'क्या', 'kyun': 'क्यों', 'kaun': 'कौन', 'kitna': 'कितना', 'kitni': 'कितनी',
    // English loanwords commonly used in Indian songs
    'love': 'लव', 'baby': 'बेबी', 'night': 'नाइट', 'feel': 'फ़ील', 'never': 'नेवर',
    'forever': 'फ़ॉरएवर', 'heart': 'हार्ट', 'time': 'टाइम', 'dream': 'ड्रीम',
    'music': 'म्यूज़िक', 'life': 'लाइफ़', 'world': 'वर्ल्ड', 'fire': 'फ़ायर',
    'hold': 'होल्ड', 'breathe': 'ब्रीद', 'dance': 'डांस', 'song': 'सॉन्ग',
    'deewana': 'दीवाना',
    // Frequently occurring song words — verbs, adjectives, nouns
    'sunlo': 'सुनलो', 'sunle': 'सुनले', 'sunna': 'सुनना', 'sunte': 'सुनते',
    'sunke': 'सुनके', 'bolke': 'बोलके', 'dekhke': 'देखके',
    'bola': 'बोला', 'boli': 'बोली', 'dekhe': 'देखे',
    'aana': 'आना', 'jaye': 'जाए', 'jaao': 'जाओ',
    'lelo': 'ले लो', 'dede': 'दे दे', 'lado': 'लड़ो',
    'chahe': 'चाहे', 'chahton': 'चाहतों', 'chaahunga': 'चाहूँगा',
    'sang': 'संग', 'sanghi': 'संगी',
    'range': 'रंगे', 'rang': 'रंग', 'rangeen': 'रंगीन', 'rangla': 'रंगला',
    'hanste': 'हँसते', 'hansi': 'हँसी',
    'ro': 'रो', 'roye': 'रोए', 'rote': 'रोते',
    'gungroo': 'गुंग्रू', 'ghungroo': 'घुंघरू',
    'aaine': 'आईने', 'aaina': 'आईना', 'aaine mein': 'आईने में',
    'abhi': 'अभी', 'abhi tak': 'अभी तक', 'abhi to': 'अभी तो',
    'akele': 'अकेले', 'akela': 'अकेला',
    'ankhon': 'आँखों', 'ankhein': 'आँखें', 'aankhon mein': 'आँखों में',
    'aasmaan': 'आसमान',
    'baag': 'बाग', 'baagh': 'बाघ', 'baahon': 'बाहों', 'baahon mein': 'बाहों में',
    'tumhein': 'तुम्हें', 'tumse': 'तुमसे',
    // Note: mujhe, mujhse, mujhko already in original lexicon
    'unhein': 'उन्हें',
    'humse': 'हमसे',
    'marta': 'मारता', 'marti': 'मारती', 'maara': 'मारा',
    'chupke': 'चुपके', 'chupke se': 'चुपके से', 'khamosh': 'ख़ामोश',
    'ghamgeen': 'ग़मगीन',
    'jalta': 'जलता', 'jalti': 'जलती', 'jala': 'जला', 'jale': 'जले',
    'kab': 'कब', 'kabse': 'कब से',
    'aaj bhi': 'आज भी', 'aajkal': 'आजकल',
    'pal bhar': 'पल भर', 'pal pal': 'पल पल',
    'lamhon': 'लम्हों',
    'raaton': 'रातों', 'raat bhar': 'रात भर',
    'dinon': 'दिनों', 'dino': 'दिनों',
    'shaamon': 'शामों',
    'subah se': 'सुबह से',
    'chanda': 'चाँदा', 'chandni': 'चाँदनी',
    'taron': 'तारों', 'taare': 'तारे', 'taaron se': 'तारों से',
    'suraj ki': 'सूरज की',
    'baarishon': 'बारिशों', 'barsaat': 'बरसात',
    'hawaaon': 'हवाओं',
    'baadalon': 'बादलों', 'baadal': 'बादल',
    'dilbar': 'दिलबर', 'dil se': 'दिल से', 'dil mein': 'दिल में', 'dil ko': 'दिल को',
    'khwabon': 'ख़्वाबों', 'khwab sa': 'ख़्वाब सा',
    'inteha': 'इंतेहा', 'inteha se': 'इंतेहा से',
    'judai': 'जुदाई', 'judaa': 'जुदा', 'judaa hai': 'जुदा है',
    'firangi': 'फ़िरंगी',
    'tere liye': 'तेरे लिए',
    'mere liye': 'मेरे लिए',
    'uska': 'उसका', 'uski': 'उसकी', 'uske': 'उसके',
    'woh raat': 'वो रात',
    'yeh dil': 'यह दिल',
    'jo hai': 'जो है', 'jo tum': 'जो तुम',
    'jeena': 'जीना', 'jeene': 'जीने', 'jeeta': 'जीता', 'jeeti': 'जीती',
    'mar ja': 'मर जा', 'marne': 'मरने',
    'chahte': 'चाहते',
    'dhoondha': 'ढूँढा', 'dhoondhe': 'ढूँढे', 'dhoondho': 'ढूँढो',
    'loote': 'लूटे', 'loota': 'लूटा', 'looting': 'लूटिंग',
    'mita': 'मिटा', 'mite': 'मिटे', 'mita do': 'मिटा दो',
    'bheja': 'भेजा', 'bheje': 'भेजे', 'bhej do': 'भेज दो',
    'laya': 'लाया', 'layi': 'लाई', 'le aao': 'ले आओ',
    'bane': 'बने', 'bana': 'बना', 'ban jao': 'बन जाओ', 'banti': 'बनती',
    'sajne': 'सजने', 'sajta': 'सजता', 'sajti': 'सजती',
    'gaaye': 'गाए', 'gaata': 'गाता', 'gaati': 'गाती', 'gaana': 'गाना',
    'nache': 'नाचे', 'nachta': 'नाचता', 'nachti': 'नाचती', 'naach': 'नाच',
    'sui': 'सूई',
    // Common words that fuzzy matching was mangling
    'jaisa': 'जैसा', 'jaisi': 'जैसी', 'jaise': 'जैसे',
    'agar': 'अगर', 'shayad': 'शायद',
    'reh': 'रह',
    'sakte': 'सकते', 'sakti': 'सकती', 'sakta': 'सकता',
    'ghadi': 'घडी', 'badal': 'बदल',
  };
}
