import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Verifies the detached Ed25519 signature published beside a release
/// manifest. The public key is build-time configuration so it cannot be
/// replaced by GitHub release metadata.
class AppUpdateManifestSignature {
  static String publicKeyBase64 = const String.fromEnvironment(
    'NOCTRA_UPDATE_MANIFEST_PUBLIC_KEY',
  );

  static bool get isConfigured => publicKeyBase64.trim().isNotEmpty;

  static Future<bool> verify({
    required String manifest,
    required String detachedSignature,
  }) async {
    try {
      final publicKeyBytes = base64Decode(publicKeyBase64);
      final signatureBytes = base64Decode(detachedSignature.trim());
      if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
        return false;
      }
      final signature = Signature(
        signatureBytes,
        publicKey: SimplePublicKey(
          publicKeyBytes,
          type: KeyPairType.ed25519,
        ),
      );
      return await Ed25519().verify(
        utf8.encode(manifest),
        signature: signature,
      );
    } catch (_) {
      return false;
    }
  }
}
