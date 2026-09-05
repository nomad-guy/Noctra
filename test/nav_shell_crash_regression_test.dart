import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/data/models/catalog_topic.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/providers/app_providers.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';
import 'package:noctra/ui/widgets/fade_indexed_stack.dart';
import 'package:noctra/ui/widgets/main_navigation_shell.dart';

/// Phase 22 P0 regression tests — IndexedStack tab-index crash.
///
/// The Phase 19 lazy-tab change fed the tab *id* (0..3) into
/// `IndexedStack.index` while building a SPARSE children list (only visited
/// tabs). Once Home was the only visited tab, selecting or restoring tab 2
/// (Library) or 3 (AI Studio) made `index >= children.length`, tripping the
/// IndexedStack range assertion:
///
///   'index >= 0 && index < children.length': The index must be null or
///   within the range of children.
///
/// Fix: the children list stays tab-aligned (fixed length 4; unvisited slots
/// are trivial placeholders), so any tab id is always a valid list index
/// while the lazy guarantee (only visited tabs are real screens) is kept.
///
/// This file lives in its own isolate: it mounts the full shell whose
/// app-wide ChangeNotifier singletons are disposed by ProviderScope teardown,
/// which would poison later tests in the same file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderScope shellScope() {
    // ProviderScope teardown disposes the global MusicRepository singleton
    // (ChangeNotifierProvider disposes its notifier); recreate it so each
    // test mounts a fresh, usable repository.
    MusicRepository.debugResetSingleton();
    return ProviderScope(
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
        p2pSyncServiceProvider
            .overrideWith((ref) => P2PSyncService.newForTest()),
      ],
      child: const MaterialApp(home: MainNavigationShell()),
    );
  }

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(shellScope());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> selectTab(WidgetTester tester, int index) async {
    // Tabs render their OUTLINED icon while unselected, so tap that variant.
    final icons = [
      Icons.home_outlined,
      Icons.search_rounded,
      Icons.library_music_outlined,
      Icons.auto_awesome_outlined,
    ];
    await tester.tap(find.byIcon(icons[index]).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  /// Unmount the shell and flush leftover timers (e.g. the AI Studio
  /// default-feed 8s timeout) so the test ends without pending timers.
  Future<void> teardownShell(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 9));
  }

  testWidgets(
      'jumping straight to Library (tab 2) with only Home visited does not crash',
      (tester) async {
    await pumpShell(tester);

    // Pre-fix this threw the IndexedStack range assertion because the
    // children list was sparse ([Home]) and index=2 was out of range.
    await selectTab(tester, 2);
    expect(tester.takeException(), isNull);

    // Library must be the active tab, inside a tab-aligned list of 4.
    final stack = tester.widget<FadeIndexedStack>(find.byType(FadeIndexedStack).first);
    expect(stack.index, 2);
    expect(stack.children, hasLength(4));

    await teardownShell(tester);
  });

  testWidgets(
      'jumping straight to AI Studio (tab 3) with only Home visited does not crash',
      (tester) async {
    await pumpShell(tester);

    await selectTab(tester, 3);
    expect(tester.takeException(), isNull);

    final stack = tester.widget<FadeIndexedStack>(find.byType(FadeIndexedStack).first);
    expect(stack.index, 3);
    expect(stack.children, hasLength(4));

    await teardownShell(tester);
  });

  testWidgets(
      'out-of-order visits (3 → 2) stay crash-free and keep real screens alive',
      (tester) async {
    await pumpShell(tester);

    await selectTab(tester, 3);
    expect(tester.takeException(), isNull);
    await selectTab(tester, 2);
    expect(tester.takeException(), isNull);
    await selectTab(tester, 0);
    expect(tester.takeException(), isNull);

    int realScreens() => tester
        .widget<FadeIndexedStack>(find.byType(FadeIndexedStack).first)
        .children
        .where((w) => w is! SizedBox)
        .length;
    // Only visited tabs are real screens; the list stays tab-aligned and all
    // indices valid.
    expect(realScreens(), 3);

    await teardownShell(tester);
  });

  testWidgets('rapid double-tap on the same tab stays in range and stable',
      (tester) async {
    await pumpShell(tester);

    await selectTab(tester, 2);
    // The tab is now SELECTED, so it renders the filled icon; tapping the
    // label exercises the same InkWell while staying findable on both taps.
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);

    final stack = tester.widget<FadeIndexedStack>(find.byType(FadeIndexedStack).first);
    expect(stack.index, 2);
    expect(find.byType(FadeIndexedStack), findsOneWidget);

    await teardownShell(tester);
  });
}
