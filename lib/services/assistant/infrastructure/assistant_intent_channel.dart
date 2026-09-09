import 'package:flutter/services.dart';
import '../../../core/utils/noctra_logger.dart';
import '../application/assistant_command_router.dart';
import '../domain/assistant_command.dart';

/// Listens for Android assistant voice search intents and deep links
/// forwarded by MainActivity and dispatches them to AssistantCommandRouter.
class AssistantIntentChannel {
  static const MethodChannel _channel =
      MethodChannel('com.nomadguy.noctra/assistant_intent');

  final AssistantCommandRouter _router;
  bool _initialized = false;

  /// Bounded set of processed intentIds to prevent duplicate dispatch when
  /// both the native MethodChannel AND _fetchInitialIntent deliver the same
  /// cold-start intent. Capped at 64 entries to prevent unbounded growth.
  final Set<String> _processedIntentIds = {};

  AssistantIntentChannel({required AssistantCommandRouter router})
      : _router = router;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      NoctraLogger.d('AssistantIntentChannel: received method=${call.method}');
      try {
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
        await _dispatchIntent(args);
        return true;
      } catch (e, stack) {
        NoctraLogger.e('AssistantIntentChannel dispatch error', e, stack);
      }
      return false;
    });

    _fetchInitialIntent();
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _initialized = false;
  }

  Future<void> _fetchInitialIntent() async {
    try {
      final initial = await _channel.invokeMethod<Map>('getInitialIntent');
      if (initial != null) {
        final args = Map<String, dynamic>.from(initial);
        await _dispatchIntent(args);
      }
    } catch (e) {
      NoctraLogger.w('Failed to check initial assistant intent: $e');
    }
  }

  /// Exposed for unit-testing: dispatch an intent payload directly,
  /// bypassing the platform channel.
  Future<void> dispatchIntentForTest(Map<String, dynamic> args) =>
      _dispatchIntent(args);

  Future<void> _dispatchIntent(Map<String, dynamic> args) async {
    // Drop duplicate deliveries (e.g. cold-start replay race).
    final intentId = args['intentId']?.toString();
    if (intentId != null && intentId.isNotEmpty) {
      if (_processedIntentIds.contains(intentId)) {
        NoctraLogger.d(
            'AssistantIntentChannel: dropping duplicate intentId=$intentId');
        return;
      }
      _processedIntentIds.add(intentId);
      if (_processedIntentIds.length > 64) _processedIntentIds.clear();
    }

    final query = args['query']?.toString().trim() ?? '';
    final data = args['data']?.toString().trim() ?? '';
    final extras = Map<String, dynamic>.from(args['extras'] as Map? ?? {});

    // 1. Deep Link URI handling (noctra://...)
    if (data.startsWith('noctra://')) {
      final uri = Uri.tryParse(data);
      if (uri != null) {
        final host = uri.host;
        final segments = uri.pathSegments;

        if (host == 'track' && segments.isNotEmpty) {
          await _router.execute(PlayTrackCommand(segments.first));
          return;
        }
        if (host == 'search') {
          final q = uri.queryParameters['q'] ?? '';
          if (q.isNotEmpty) {
            await _router.execute(SearchAndPlayCommand(q, extras));
            return;
          }
        }
        if (host == 'playlist' && segments.isNotEmpty) {
          await _router.execute(
              PlayPlaylistCommand(Uri.decodeComponent(segments.first)));
          return;
        }
        if (host == 'artist' && segments.isNotEmpty) {
          await _router
              .execute(PlayArtistCommand(Uri.decodeComponent(segments.first)));
          return;
        }
        if (host == 'album' && segments.isNotEmpty) {
          await _router
              .execute(PlayAlbumCommand(Uri.decodeComponent(segments.first)));
          return;
        }
      }
    }

    // 2. Standard voice search query / extras handling
    if (query.isNotEmpty || extras.isNotEmpty) {
      NoctraLogger.d(
          'AssistantIntentChannel: processing voice query "$query"');
      await _router.execute(SearchAndPlayCommand(query, extras));
    }
  }
}
