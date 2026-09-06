import 'dart:convert';
import 'dart:typed_data';

/// Minimal, bit-accurate, zero-dependency pure Dart DES (Data Encryption Standard)
/// cipher for Electronic Codebook (ECB) mode with PKCS5/PKCS7 padding.
class DesCipher {
  static const List<int> _ip = [
    58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
    62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
    57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
    61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7,
  ];

  static const List<int> _fp = [
    40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
    38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
    36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
    34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25,
  ];

  static const List<int> _pc1 = [
    57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18,
    10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
    63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22,
    14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4,
  ];

  static const List<int> _pc2 = [
    14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10,
    23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2,
    41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48,
    44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32,
  ];

  static const List<int> _shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

  static const List<int> _e = [
    32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9,
    8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17,
    16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25,
    24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1,
  ];

  static const List<int> _p = [
    16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10,
    2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25,
  ];

  static const List<List<int>> _sboxes = [
    [14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7, 0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8, 4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0, 15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13],
    [15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10, 3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5, 0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15, 13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9],
    [10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8, 13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1, 13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7, 1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12],
    [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15, 13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9, 10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4, 3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14],
    [2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9, 14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6, 4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14, 11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3],
    [12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11, 10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8, 9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6, 4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13],
    [4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1, 13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6, 1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2, 6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12],
    [13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7, 1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2, 7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8, 2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11],
  ];

  static List<List<int>> _generateSubkeys(Uint8List key) {
    final keyBits = _bytesToBits(key);
    var c = List<int>.generate(28, (i) => keyBits[_pc1[i] - 1]);
    var d = List<int>.generate(28, (i) => keyBits[_pc1[i + 28] - 1]);
    final subkeys = <List<int>>[];

    for (var round = 0; round < 16; round++) {
      final s = _shifts[round];
      c = [...c.sublist(s), ...c.sublist(0, s)];
      d = [...d.sublist(s), ...d.sublist(0, s)];
      final cd = [...c, ...d];
      subkeys.add(List<int>.generate(48, (i) => cd[_pc2[i] - 1]));
    }
    return subkeys;
  }

  static Uint8List _feistel(Uint8List block, List<List<int>> subkeys) {
    final bits = _bytesToBits(block);
    final ipBits = List<int>.generate(64, (i) => bits[_ip[i] - 1]);
    var l = ipBits.sublist(0, 32);
    var r = ipBits.sublist(32, 64);

    for (final k in subkeys) {
      final eR = List<int>.generate(48, (i) => r[_e[i] - 1]);
      final xorK = List<int>.generate(48, (i) => eR[i] ^ k[i]);
      final sOut = <int>[];
      for (var b = 0; b < 8; b++) {
        final chunk = xorK.sublist(b * 6, (b + 1) * 6);
        final row = (chunk[0] << 1) | chunk[5];
        final col = (chunk[1] << 3) | (chunk[2] << 2) | (chunk[3] << 1) | chunk[4];
        final val = _sboxes[b][row * 16 + col];
        for (var bit = 3; bit >= 0; bit--) {
          sOut.add((val >> bit) & 1);
        }
      }
      final pOut = List<int>.generate(32, (i) => sOut[_p[i] - 1]);
      final nextL = r;
      r = List<int>.generate(32, (i) => l[i] ^ pOut[i]);
      l = nextL;
    }

    final preFp = [...r, ...l];
    final outBits = List<int>.generate(64, (i) => preFp[_fp[i] - 1]);
    return _bitsToBytes(outBits);
  }

  static List<int> _bytesToBits(Uint8List bytes) {
    final bits = List<int>.filled(bytes.length * 8, 0);
    var idx = 0;
    for (final b in bytes) {
      for (var i = 7; i >= 0; i--) {
        bits[idx++] = (b >> i) & 1;
      }
    }
    return bits;
  }

  static Uint8List _bitsToBytes(List<int> bits) {
    final bytes = Uint8List(bits.length ~/ 8);
    for (var i = 0; i < bytes.length; i++) {
      var val = 0;
      for (var bit = 0; bit < 8; bit++) {
        val = (val << 1) | bits[i * 8 + bit];
      }
      bytes[i] = val;
    }
    return bytes;
  }

  /// Decrypts [cipherBytes] in DES ECB mode using [key] (8 bytes) with PKCS5/7 unpadding.
  static Uint8List decryptEcb(Uint8List cipherBytes, Uint8List key) {
    if (key.length != 8) throw ArgumentError('DES key must be exactly 8 bytes');
    if (cipherBytes.isEmpty || cipherBytes.length % 8 != 0) {
      throw ArgumentError('Cipher text must be a non-empty multiple of 8 bytes');
    }
    final subkeys = _generateSubkeys(key).reversed.toList();
    final decrypted = Uint8List(cipherBytes.length);

    for (var offset = 0; offset < cipherBytes.length; offset += 8) {
      final block = cipherBytes.sublist(offset, offset + 8);
      final decBlock = _feistel(block, subkeys);
      decrypted.setRange(offset, offset + 8, decBlock);
    }

    // PKCS5/PKCS7 unpad
    final padLen = decrypted.last;
    if (padLen < 1 || padLen > 8 || padLen > decrypted.length) return decrypted;
    for (var i = decrypted.length - padLen; i < decrypted.length; i++) {
      if (decrypted[i] != padLen) return decrypted;
    }
    return decrypted.sublist(0, decrypted.length - padLen);
  }

  /// Decrypts base64-encoded encrypted text into a UTF-8 string.
  static String? decryptBase64String(String base64Text, String keyString) {
    try {
      final cipherBytes = base64.decode(base64Text.trim());
      final keyBytes = Uint8List.fromList(utf8.encode(keyString));
      final decBytes = decryptEcb(cipherBytes, keyBytes);
      return utf8.decode(decBytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }
}
