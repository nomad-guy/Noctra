part of '../sanscript_engine.dart';

class SanscriptMappingTables {
  static const Map<String, int> base = {
    'devanagari': 0x0900,
    'bengali': 0x0980,
    'gurmukhi': 0x0A00,
    'gujarati': 0x0A80,
    'tamil': 0x0B80,
    'telugu': 0x0C00,
    'kannada': 0x0C80,
    'odia': 0x0B00,
    'malayalam': 0x0D00,
  };

  static const Map<String, String> devaNuktaCompose = {
    '\u0915\u093C': '\u0958',
    '\u0916\u093C': '\u0959',
    '\u0917\u093C': '\u095A',
    '\u091C\u093C': '\u095B',
    '\u0921\u093C': '\u095C',
    '\u0922\u093C': '\u095D',
    '\u092B\u093C': '\u095E',
    '\u092F\u093C': '\u095F',
  };

  static const Map<String, String> gurmukhiNuktaCompose = {
    '\u0A16\u0A3C': '\u0A59',
    '\u0A17\u0A3C': '\u0A5A',
    '\u0A1C\u0A3C': '\u0A5B',
    '\u0A21\u0A3C': '\u0A5C',
    '\u0A22\u0A3C': '\u0A5D',
    '\u0A25\u0A3C': '\u0A5E',
    '\u0A38\u0A3C': '\u0A36',
    '\u0A32\u0A3C': '\u0A33',
  };

  static const Map<String, Map<String, String>> consonantOverrides = {
    'bengali': {
      '\u0935': '\u09AC',
      '\u0933': '\u09B2',
      '\u0931': '\u09B0',
      '\u0958': '\u0995',
      '\u0959': '\u0996',
      '\u095A': '\u0997',
      '\u095B': '\u099C',
      '\u095C': '\u09A1',
      '\u095D': '\u09A2',
      '\u095E': '\u09AB',
    },
    'gurmukhi': {
      'ष': 'ਸ਼',
      'श': 'ਸ਼',
      'क़': 'ਕ',
      'ख़': 'ਖ਼',
      'ग़': 'ਗ਼',
      'ਜ਼': 'ਜ਼',
      'ੜ': 'ੜ',
      'ढ़': '੝',
      'फ़': 'ਫ਼',
    },
    'gujarati': {
      '\u0931': '\u0AB0',
      '\u0958': '\u0A95',
      '\u0959': '\u0A96',
      '\u095A': '\u0A97',
      '\u095B': '\u0A9C',
      '\u095C': '\u0AA1',
      '\u095D': '\u0AA2',
      '\u095E': '\u0AAB',
    },
    'odia': {
      '\u0935': '\u0B2C',
      '\u0931': '\u0B30',
      '\u0958': '\u0B15',
      '\u0959': '\u0B16',
      '\u095A': '\u0B17',
      '\u095B': '\u0B1C',
      '\u095C': '\u0B21',
      '\u095D': '\u0B22',
      '\u095E': '\u0B2B',
    },
    'telugu': {
      '\u0958': '\u0C15',
      '\u0959': '\u0C16',
      '\u095A': '\u0C17',
      '\u095B': '\u0C1C',
      '\u095C': '\u0C31',
      '\u095D': '\u0C31',
      '\u095E': '\u0C2B',
    },
    'kannada': {
      '\u0958': '\u0C95',
      '\u0959': '\u0C96',
      '\u095A': '\u0C97',
      '\u095B': '\u0C9C',
      '\u095C': '\u0CB1',
      '\u095D': '\u0CB1',
      '\u095E': '\u0CAB',
    },
    'malayalam': {
      '\u0958': '\u0D15',
      '\u0959': '\u0D16',
      '\u095A': '\u0D17',
      '\u095B': '\u0D1C',
      '\u095C': '\u0D31',
      '\u095D': '\u0D31',
      '\u095E': '\u0D2B',
    },
    'tamil': {
      '\u0916': '\u0B95',
      '\u0917': '\u0B95',
      '\u0918': '\u0B95',
      '\u091A': '\u0B9A',
      '\u091B': '\u0B9A',
      '\u091D': '\u0B9A',
      '\u091F': '\u0B9F',
      '\u0920': '\u0B9F',
      '\u0921': '\u0B9F',
      '\u0922': '\u0B9F',
      '\u0924': '\u0BA4',
      '\u0925': '\u0BA4',
      '\u0926': '\u0BA4',
      '\u0927': '\u0BA4',
      '\u092A': '\u0BAA',
      '\u092B': '\u0BAA',
      '\u092D': '\u0BAA',
      '\u0936': '\u0B9A',
      '\u0937': '\u0BB7',
      '\u0938': '\u0BB8',
      '\u0958': '\u0B95',
      '\u0959': '\u0B95',
      '\u095A': '\u0B95',
      '\u095B': '\u0B9C',
      '\u095C': '\u0BB1',
      '\u095D': '\u0BB1',
      '\u095E': '\u0BAA',
      '\u095F': '\u0BAF',
    },
  };

  static const Map<String, Map<String, String>> vowelOverrides = {
    'bengali': {
      '\u090D': '\u098F',
      '\u090E': '\u098F',
      '\u0911': '\u0993',
      '\u0912': '\u0993',
      '\u090B': '\u098B',
    },
    'gurmukhi': {
      '\u090B': '\u0A30\u0A3F',
      '\u0960': '\u0A30\u0A40',
      '\u090D': '\u0A0F',
      '\u0911': '\u0A06',
      '\u090E': '\u0A0F',
      '\u0912': '\u0A13',
    },
    'tamil': {
      '\u090B': '\u0BB0\u0BC1',
      '\u0960': '\u0BB0\u0BC2',
      '\u090C': '\u0BB2\u0BC1',
      '\u0961': '\u0BB2\u0BC2',
      '\u090D': '\u0B8E',
      '\u090E': '\u0B8E',
      '\u0911': '\u0B93',
      '\u0912': '\u0B92',
    },
    'odia': {
      '\u090D': '\u0B0F',
      '\u090E': '\u0B0F',
      '\u0911': '\u0B13',
      '\u0912': '\u0B13',
    },
  };

  static const Map<String, Map<String, String>> matraOverrides = {
    'gurmukhi': {
      '\u0943': '\u0A4D\u0A30\u0A3F',
      '\u0944': '\u0A4D\u0A30\u0A40',
    },
    'tamil': {
      '\u0943': '',
      '\u0944': '',
      '\u0945': '\u0BC6',
      '\u0949': '\u0BCA',
    },
    'bengali': {
      '\u0945': '\u09C7',
      '\u0949': '\u09CB',
    },
  };

  static const Map<String, Map<String, String>> markOverrides = {
    'tamil': {
      '\u0901': '\u0B82',
      '\u093D': '\u0B83',
    },
  };

  static const Map<int, String> gurmukhiNuktaBaseToDeva = {
    0x0A15: 'क़',
    0x0A16: 'ख़',
    0x0A17: 'ग़',
    0x0A1C: 'ज़',
    0x0A21: 'ੜ',
    0x0A22: 'ਢ',
    0x0A25: 'फ़',
    0x0A32: 'ळ',
    0x0A38: 'ष',
  };

  static const Map<int, String> gurmukhiComposedToDeva = {
    0x0A33: '\u0933',
    0x0A36: '\u0937',
    0x0A59: '\u0959',
    0x0A5A: '\u095A',
    0x0A5B: '\u095B',
    0x0A5C: '\u095C',
    0x0A5D: '\u095D',
    0x0A5E: '\u095E',
  };
}
