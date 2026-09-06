import 'dart:async';
import 'package:flutter/foundation.dart';
import '../contracts/notification_service.dart';
import '../noctra_capabilities.dart';

/// Concrete [PlatformNotificationService] implementation for multi-platform operation.
class PlatformNotificationServiceImpl implements PlatformNotificationService {
  final Map<int, String> _activeNotifications = {};

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      _activeNotifications[id] = '$title: $body';
      if (kDebugMode) {
        debugPrint('[PlatformNotificationService] ($id) $title - $body');
      }
    } catch (e) {
      // Graceful degradation: playback must never crash due to notification issues
      debugPrint('[PlatformNotificationService] Failed to show notification: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    _activeNotifications.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    _activeNotifications.clear();
  }

  @override
  Future<bool> get isPermissionGranted async {
    if (NoctraCapabilities.isDesktop) return true;
    return true;
  }

  int get activeCount => _activeNotifications.length;
}
