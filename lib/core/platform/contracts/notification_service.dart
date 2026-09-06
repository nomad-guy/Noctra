import 'dart:async';

/// Abstract contract for platform-neutral notifications.
///
/// Playback never depends strictly on notifications; if notifications are unavailable
/// or fail on desktop/mobile, playback continues without crashing.
abstract interface class PlatformNotificationService {
  /// Displays or updates a system notification.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Cancels a notification by its identifier.
  Future<void> cancel(int id);

  /// Cancels all active notifications created by this service.
  Future<void> cancelAll();

  /// Whether notification permission has been granted by the user.
  Future<bool> get isPermissionGranted;
}

/// Fallback / No-Op implementation for platforms without notification channels.
class NoOpNotificationService implements PlatformNotificationService {
  const NoOpNotificationService();

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> get isPermissionGranted async => true;
}
