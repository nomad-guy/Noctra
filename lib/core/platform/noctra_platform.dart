import 'contracts/media_control_service.dart';
import 'contracts/notification_service.dart';
import 'contracts/platform_storage.dart';
import 'media/desktop_media_controls.dart';
import 'media/ios_media_controls.dart';
import 'media/no_op_media_controls.dart';
import 'noctra_capabilities.dart';
import 'notifications/platform_notification_service.dart';
import 'storage/platform_storage_resolver.dart';

/// Single unified global platform interface for Noctra.
///
/// Gives the entire application clean, singleton-backed access to platform services
/// without leaking OS-specific classes or scattering platform checks.
class NoctraPlatformContext {
  NoctraPlatformContext._();

  static final NoctraPlatformContext instance = NoctraPlatformContext._();

  PlatformStorage _storage = const PlatformStorageResolver();
  PlatformNotificationService _notifications = PlatformNotificationServiceImpl();
  late MediaControlService _mediaControls = _createDefaultMediaControls();

  static MediaControlService _createDefaultMediaControls() {
    switch (NoctraCapabilities.platform) {
      case NoctraPlatform.iOS:
        return IOSMediaControlService();
      case NoctraPlatform.windows:
      case NoctraPlatform.linux:
      case NoctraPlatform.macOS:
        return DesktopMediaControlService();
      case NoctraPlatform.android:
      case NoctraPlatform.web:
      case NoctraPlatform.other:
        return NoOpMediaControlService();
    }
  }

  /// Global filesystem and logical directory resolver.
  PlatformStorage get storage => _storage;

  /// Global notification service.
  PlatformNotificationService get notifications => _notifications;

  /// Global media notifications & lockscreen command service.
  MediaControlService get mediaControls => _mediaControls;

  /// Direct platform identity query.
  NoctraPlatform get platform => NoctraCapabilities.platform;

  /// Whether active OS is desktop.
  bool get isDesktop => NoctraCapabilities.isDesktop;

  /// Whether active OS is mobile.
  bool get isMobile => NoctraCapabilities.isMobile;

  /// Seams for automated unit and contract testing.
  void setStorageForTesting(PlatformStorage customStorage) =>
      _storage = customStorage;

  void setMediaControlsForTesting(MediaControlService customControls) =>
      _mediaControls = customControls;

  void setNotificationsForTesting(PlatformNotificationService customNotifications) =>
      _notifications = customNotifications;
}
