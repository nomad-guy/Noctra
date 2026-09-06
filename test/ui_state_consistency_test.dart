import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/data/models/catalog_topic.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/providers/app_providers.dart';
import 'package:noctra/services/audio/audio_player_service.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';
import 'package:noctra/ui/widgets/main_navigation_shell.dart';
import 'package:noctra/ui/widgets/queue_sheet.dart';

/// Phase 19 regression tests.
///
/// 1. Player-bound stream providers (`isPlayingStreamProvider`, etc.) bind to
///    `player.player.*Stream`, but AudioPlayerService replaces that player
///    instance on every crossfade/preload promotion. Broadcast streams do not
///    replay, so a provider that only forwards the raw stream stays empty
///    until the *next* event — or, after a player swap, listens to the
///    disposed instance forever. The providers now reseed from the live
///    synchronous getters on every listen.
/// 2. QueueSheet reads the queue snapshot once; mutations from autoplay/Jam/
///    crossfade while the sheet is open were invisible. It now re-renders on
///    queue/current-song/player-swap events, and its ListTiles sit under an
///    explicit Material (a decorated Container is not a Material ancestor).
/// 3. MainNavigationShell built all four tabs eagerly at startup via
///    IndexedStack. Tabs are now instantiated on first visit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Song makeSong(String id, String title) => Song(
        id: id,
        title: title,
        artist: 'Test Artist',
        duration: const Duration(seconds: 180),
        artworkUrl: 'https://example.com/art.jpg',
      );

  group('player-bound stream providers', () {
    test('reseed current state immediately instead of waiting on broadcast',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-fix these providers stayed AsyncLoading forever: a broadcast
      // stream without replay never emits in a quiet player, so UI values
      // remained null. The seed must arrive without any stream event.
      container.listen<AsyncValue<bool>>(isPlayingStreamProvider, (_, __) {});
      container.listen<AsyncValue<Duration>>(
          positionStreamProvider, (_, __) {});
      container.listen<AsyncValue<double>>(volumeStreamProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(isPlayingStreamProvider).value, isFalse);
      expect(container.read(positionStreamProvider).value, Duration.zero);
      expect(container.read(volumeStreamProvider).value, 1.0);
    });

    test('swap signal stream is exposed by the service', () {
      final service = AudioPlayerService.instance;
      expect(service.playerSwapStream, isNotNull);
    });
  });

  group('QueueSheet', () {
    testWidgets(
        're-renders on external queue mutations and owns a Material ancestor',
        (tester) async {
      final player = AudioPlayerService.instance;
      // Fresh process → empty queue; belt-and-braces reset.
      player.clearQueue();

      // Pumped WITHOUT a Scaffold: the sheet itself must provide the Material
      // ancestor ListTile requires (pre-fix this threw in debug builds).
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: QueueSheet())),
      );
      await tester.pump();
      expect(find.text('Queue is empty.\nTap + to add songs.'), findsOneWidget);

      // External mutation (e.g. autoplay/Jam adding tracks) while open.
      final events = <List<Song>>[];
      final probeSub = player.queueStream.listen(events.add);
      addTearDown(probeSub.cancel);
      player.addToQueue(makeSong('yt_a1', 'Alpha Song'));
      player.addToQueue(makeSong('yt_b2', 'Beta Song'));
      player.addToQueue(makeSong('yt_c3', 'Gamma Song'));
      // First pump delivers the stream event (setState marks dirty), the
      // second draws the rebuilt frame.
      await tester.pump();
      await tester.pump();
      expect(find.text('Alpha Song'), findsOneWidget);
      expect(find.text('Beta Song'), findsOneWidget);
      expect(find.text('Gamma Song'), findsOneWidget);

      // External removal while open. (The sheet hides single-entry queues
      // by design, so keep two entries for the visibility assertion.)
      player.removeFromQueue(0);
      await tester.pump();
      await tester.pump();
      expect(find.text('Alpha Song'), findsNothing);
      expect(find.text('Beta Song'), findsOneWidget);
      expect(find.text('Gamma Song'), findsOneWidget);

      // Cleanup for other tests in this file.
      player.removeFromQueue(0);
      player.removeFromQueue(0);
      await tester.pump();
      await tester.pump();
      // Let the service's 300 ms debounced queue-persistence timer fire so
      // the test ends without a pending timer.
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('MainNavigationShell lazy tabs', () {
    // NOTE: keep this the LAST test in this file. Mounting the shell
    // initializes app-wide ChangeNotifier singletons (MusicRepository,
    // P2PSyncService) whose providers dispose them on scope teardown;
    // any later test in this same file would then hit a disposed singleton.
    // The crash regression scenarios live in nav_shell_crash_regression_test.dart
    // (own file == fresh isolate).
    testWidgets('instantiates only the visited tab at startup', (tester) async {
      // Keep the shell hermetic: stub every network-backed feed so no HTTP
      // requests are made and no provider errors surface during the test.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dynamicTrendingFeedProvider
                .overrideWith((ref) => Future<List<Song>>.value(<Song>[])),
            dynamicVibeTracksProvider
                .overrideWith((ref) => Future<List<Song>>.value(<Song>[])),
            dynamicSpotifyChartsProvider
                .overrideWith((ref) => Future<List<Song>>.value(<Song>[])),
            dynamicCatalogTopicsProvider
                .overrideWith((ref) => Future.value(<CatalogTopic>[])),
            aiAgentMixProvider
                .overrideWith((ref) => Future.value(<Map<String, dynamic>>[])),
            // Fresh per-test instance: ProviderScope teardown disposes the
            // notifier, which would poison the app-wide P2P singleton for
            // the later tests in this file.
            p2pSyncServiceProvider
                .overrideWith((ref) => P2PSyncService.newForTest()),
          ],
          child: const MaterialApp(home: MainNavigationShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      IndexedStack stack() =>
          tester.widget<IndexedStack>(find.byType(IndexedStack).first);
      // Tab-aligned children (fixed length 4; unvisited slots are trivial
      // placeholders). The lazy guarantee is: only the visited tab is a real
      // screen. Pre-fix: all four screens existed from frame one.
      expect(stack().children, hasLength(4));
      int realScreens() => stack().children
          .where((w) => w is! SizedBox)
          .length;
      expect(realScreens(), 1);

      // Visit Search — the shell must add it while keeping Home alive.
      await tester.tap(find.byIcon(Icons.search_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(realScreens(), 2);

      // Unmount and let any timers cancel before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
