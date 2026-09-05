import 'dart:async';
import 'package:flutter/services.dart';
import '../../../core/utils/noctra_logger.dart';
import '../application/assistant_command_router.dart';
import '../domain/assistant_command.dart';

/// Listens for Android assistant voice search intents forwarded by MainActivity
/// and dispatches them to AssistantCommandRouter.
class AssistantIntentChannel {
  static const MethodChannel _channel =
      MethodChannel('com.nomadguy.noctra/assistant_intent');

  final AssistantCommandRouter _router;
  bool _initialized = false;

  AssistantIntentChannel({required AssistantCommandRouter router})
      : _router = router;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      NoctraLogger.d('AssistantIntentChannel: received method=${call.method}');
      try {
        if (call.method == 'onMediaPlayFromSearch') {
          final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
          final query = args['query']?.toString() ?? '';
          final extras = Map<String, dynamic>.from(args['extras'] as Map? ?? {});
          
          await _router.execute(SearchAndPlayCommand(query, extras));
          return true;
        }
      } catch (e, stack) {
        NoctraLogger.e('AssistantIntentChannel dispatch error', e, stack);
      }
      return false;
    });

    // Check if app was cold-started with a pending assistant intent
    _fetchInitialIntent();
  }

  Future<void> _fetchInitialIntent() async {
    try {
      final initial = await _channel.invokeMethod<Map>('getInitialIntent');
      if (initial != null) {
        final query = initial['query']?.toString() ?? '';
        final extras = Map<String, dynamic>.from(initial['extras'] as Map? ?? {});
        if (query.isNotEmpty || extras.isNotEmpty) {
          NoctraLogger.d('AssistantIntentChannel: processing initial voice intent "$query"');
          await _router.execute(SearchAndPlayCommand(query, extras));
        }
      }
    } catch (e) {
      NoctraLogger.w('Failed to check initial assistant intent: $e');
    }
  }
}
