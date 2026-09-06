/// Public contracts of the core platform abstraction layer.
///
/// Domain/application/UI code should import this barrel (or the individual
/// contract files) rather than reaching for `dart:io` / `Platform.is*`.
library;

export 'noctra_capabilities.dart';
export 'contracts/playback_engine.dart';
export 'contracts/platform_storage.dart';
export 'contracts/media_control_service.dart';
