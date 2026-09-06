import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/crypto/des_cipher.dart';

void main() {
  group('DesCipher', () {
    test('standard ECB block decryption vector', () {
      // Known DES vector:
      // Key: 0x0123456789ABCDEF
      // Plaintext: "Now is t" (0x4e6f772069732074)
      // Ciphertext: 0x3FA40E8A984D4815
      final key = Uint8List.fromList([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]);
      final cipherBytes = Uint8List.fromList([
        0x3F, 0xA4, 0x0E, 0x8A, 0x98, 0x4D, 0x48, 0x15,
      ]);

      // When decrypting without padding check (we pass block + dummy pad block):
      // Let's test decryptBase64String or direct decryptEcb
      expect(() => DesCipher.decryptEcb(cipherBytes, key), returnsNormally);
      final rawDecrypted = DesCipher.decryptEcb(cipherBytes, key);
      // Since pad check on the last byte occurs, if last byte is not 1..8, it returns full 8 bytes:
      expect(rawDecrypted, equals(utf8.encode('Now is t')));
    });

    test('decryptBase64String handles invalid input gracefully', () {
      expect(DesCipher.decryptBase64String('', '38346591'), isNull);
      expect(DesCipher.decryptBase64String('not-base64!!!', '38346591'), isNull);
    });
  });
}
