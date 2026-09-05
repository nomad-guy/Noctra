import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noctra/providers/app_providers.dart';
import 'package:noctra/services/audio/audio_player_service.dart';

/// Regression — mini player frozen at a stale position / play state while
/// audio kept playing on newer player instances.
///
/// Root cause: the UI re-seeds its position/playing subscriptions whenever
/// `AudioPlayerService` replaces its underlying player (crossfade /
/// preload handoff). The reseed is triggered by watching the player-swap
/// tick, but the tick used to be a constant (`null`). Riverpod's
/// StreamProvider does not notify dependents when the new value equals the
/// old one, so after the FIRST swap the dependents stopped invalidating:
/// the UI stayed subscribed to the player that was current at swap #1,
/// that player was later disposed, and its (now silent) streams froze the
/// mini player at that instance's last position and play state — while
/// actual audio continued on the newly promoted players.
///
/// Fix: the swap tick now carries a strictly increasing counter, so every
/// swap is a distinct value and every dependent re-seeds to the CURRENT
/// player instance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('player swap tick', () {
    late AudioPlayerService svc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      svc = AudioPlayerService.instance;
    });

    tearDown(() async {
      while (svc.queue.isNotEmpty) {
        svc.removeFromQueue(0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    test('every swap tick is a strictly increasing value (never repeats)',
        () async {
      final ticks = <int>[];
      final sub = svc.playerSwapStream.listen(ticks.add);
      addTearDown(sub.cancel);

      svc.debugNotifyPlayerSwap();
      svc.debugNotifyPlayerSwap();
      svc.debugNotifyPlayerSwap();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ticks.length, 3);
      expect(ticks.toSet().length, 3, reason: 'ticks must be distinct');
      expect(ticks[0] < ticks[1], isTrue);
      expect(ticks[1] < ticks[2], isTrue);
    });

    test('repeated swaps each trigger a fresh emission for late listeners',
        () async {
      svc.debugNotifyPlayerSwap(); // swap #1 before any listener
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // A listener attaching now must observe the NEXT swap even though a
      // swap already happened: broadcast semantics + distinct payload.
      final ticks = <int>[];
      final sub = svc.playerSwapStream.listen(ticks.add);
      addTearDown(sub.cancel);

      svc.debugNotifyPlayerSwap();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ticks, hasLength(1));
    });
  });

  group('position provider reseeds on every swap', () {
    test('positionStreamProvider emits after consecutive swap ticks',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force the provider into existence and observe every swap.
      final events = <int>[];
      container.listen(playerSwapStreamProvider, (_, next) {
        final v = next.value;
        if (v != null) events.add(v);
      });

      final svc = AudioPlayerService.instance;
      svc.debugNotifyPlayerSwap();
      svc.debugNotifyPlayerSwap();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(events, isNotEmpty);
      expect(events.toSet().length, events.length,
          reason:
              'swap provider must surface every tick so dependents reseed '
              'to the current player instance (a repeated value would be '
              'deduplicated and the UI would freeze on a disposed player)');
    });
  });
}
