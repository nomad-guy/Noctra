import '../../../../core/platform/contracts/update_service.dart';
import '../../../../core/platform/noctra_capabilities.dart';
import 'android_update_provider.dart';
import 'desktop_update_provider.dart';
import 'ios_update_provider.dart';

/// Factory for obtaining the platform-specific [UpdateProvider].
class UpdateProviderFactory {
  UpdateProviderFactory._();

  /// Resolves the compliant [UpdateProvider] for the current operating system.
  static UpdateProvider getProvider() {
    switch (NoctraCapabilities.platform) {
      case NoctraPlatform.android:
        return AndroidUpdateProvider();
      case NoctraPlatform.iOS:
        return const IOSUpdateProvider();
      case NoctraPlatform.windows:
        return const DesktopUpdateProvider(platform: 'windows');
      case NoctraPlatform.linux:
        return const DesktopUpdateProvider(platform: 'linux');
      case NoctraPlatform.macOS:
        return const DesktopUpdateProvider(platform: 'macos');
      case NoctraPlatform.web:
      case NoctraPlatform.other:
        return const DesktopUpdateProvider(platform: 'web');
    }
  }
}
