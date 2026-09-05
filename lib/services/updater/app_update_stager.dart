import 'app_update_verifier.dart';

/// Holds the path to one fully verified APK until the user explicitly starts
/// Android's installer. It never downloads or installs by itself.
class AppUpdateStager {
  static Future<bool> Function(String filePath) verifyCandidate =
      AppUpdateVerifier.isVerifiedInstallCandidate;

  static String? _stagedPath;
  static String? get stagedPath => _stagedPath;
  static bool get hasStagedUpdate => _stagedPath != null;

  static Future<bool> stage(String filePath) async {
    if (filePath.isEmpty || !await verifyCandidate(filePath)) return false;
    _stagedPath = filePath;
    return true;
  }

  static String? takeStagedPath() {
    final path = _stagedPath;
    _stagedPath = null;
    return path;
  }

  static void clear() => _stagedPath = null;
}
