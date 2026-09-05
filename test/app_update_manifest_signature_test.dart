import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/updater/app_update_manifest_signature.dart';

void main() {
  tearDown(() => AppUpdateManifestSignature.publicKeyBase64 = '');

  test('accepts a valid Ed25519 detached manifest signature', () async {
    const manifest = '{"version":"1.2.0"}';
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final signature =
        await algorithm.sign(utf8.encode(manifest), keyPair: keyPair);
    AppUpdateManifestSignature.publicKeyBase64 = base64Encode(publicKey.bytes);

    expect(
      await AppUpdateManifestSignature.verify(
        manifest: manifest,
        detachedSignature: base64Encode(signature.bytes),
      ),
      isTrue,
    );
  });

  test('refuses a signature for altered manifest content', () async {
    const manifest = '{"version":"1.2.0"}';
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final signature =
        await algorithm.sign(utf8.encode(manifest), keyPair: keyPair);
    AppUpdateManifestSignature.publicKeyBase64 = base64Encode(publicKey.bytes);

    expect(
      await AppUpdateManifestSignature.verify(
        manifest: '{"version":"1.2.1"}',
        detachedSignature: base64Encode(signature.bytes),
      ),
      isFalse,
    );
  });
}
