/// Public contracts of the core platform abstraction layer.
///
/// Domain/application/UI code should import this barrel (or the individual
/// contract files) rather than reaching for `dart:io` / `Platform.is*`.
library;

export 'noctra_capabilities.dart';
export 'contracts/playback_engine.dart';
export 'contracts/platform_storage.dart';
export 'contracts/media_control_service.dart';
export 'contracts/notification_service.dart';
export 'contracts/update_service.dart';
export 'storage/platform_storage_resolver.dart';
export 'media/no_op_media_controls.dart';
export 'media/desktop_media_controls.dart';
export 'media/ios_media_controls.dart';
export 'notifications/platform_notification_service.dart';
export 'noctra_platform.dart';
