import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/data/models/catalog_topic.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/providers/app_providers.dart';
import 'package:noctra/services/p2p/p2p_sync_service.dart';
import 'package:noctra/ui/widgets/main_navigation_shell.dart';
import 'package:noctra/ui/widgets/library_folders_tab.dart';
import 'package:noctra/ui/widgets/library/folder_detail_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderScope shellScope() {
    MusicRepository.debugResetSingleton();
    final repo = MusicRepository.instance;
    repo.createFolder('Rock Classics');
    repo.toggleFavorite(
      Song(
        id: 'fav_1',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        duration: const Duration(seconds: 354),
      ),
    );
    repo.addSongToFolder(
      'Rock Classics',
      Song(
        id: 'rock_1',
        title: 'Stairway to Heaven',
        artist: 'Led Zeppelin',
        duration: const Duration(seconds: 482),
      ),
    );

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

  testWidgets('TEST A: Open folder -> folder back button -> switch tabs',
      (tester) async {
    await tester.pumpWidget(shellScope());
    await tester.pumpAndSettle();

    // 1. Switch to Library (tab 2)
    await tester.tap(find.byIcon(Icons.library_music_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsWidgets);

    // 2. Switch to Folders tab inside Library
    await tester.tap(find.widgetWithText(Tab, 'Folders'));
    await tester.pumpAndSettle();

    // 3. Tap on Favorites or Rock Classics folder
    expect(find.text('Rock Classics'), findsOneWidget);
    await tester.tap(find.text('Rock Classics'));
    await tester.pumpAndSettle();

    // Verify FolderDetailView is opened
    expect(find.byType(FolderDetailView), findsOneWidget);
    expect(find.text('Stairway to Heaven'), findsOneWidget);

    // 4. Tap Folder UI Back Button
    final backBtn = find.byIcon(Icons.arrow_back_rounded);
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Verify back in Library
    expect(find.byType(FolderDetailView), findsNothing);

    // 5. Switch to Home tab
    final homeIcon = find.byIcon(Icons.home_outlined);
    expect(homeIcon, findsOneWidget);
    await tester.tap(homeIcon);
    await tester.pumpAndSettle();

    // Verify Home tab is selected
    final currentIndex = tester
        .widget<IndexedStack>(find.byType(IndexedStack).first)
        .index;
    expect(currentIndex, 0, reason: 'Tapping Home after folder exit must switch to tab 0');
  });

  testWidgets('TEST B: Open folder -> system back -> switch tabs',
      (tester) async {
    await tester.pumpWidget(shellScope());
    await tester.pumpAndSettle();

    // 1. Switch to Library (tab 2)
    await tester.tap(find.byIcon(Icons.library_music_outlined).first);
    await tester.pumpAndSettle();

    // 2. Switch to Folders tab
    await tester.tap(find.widgetWithText(Tab, 'Folders'));
    await tester.pumpAndSettle();

    // 3. Open folder
    await tester.tap(find.text('Rock Classics'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderDetailView), findsOneWidget);

    // 4. Simulate Android system back
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // Verify FolderDetailView is popped
    expect(find.byType(FolderDetailView), findsNothing);

    // 5. Tap Search tab
    final searchIcon = find.byIcon(Icons.search_rounded);
    expect(searchIcon, findsWidgets);
    await tester.tap(searchIcon.first);
    await tester.pumpAndSettle();

    final currentIndex = tester
        .widget<IndexedStack>(find.byType(IndexedStack).first)
        .index;
    expect(currentIndex, 1, reason: 'Tapping Search after system back must switch to tab 1');
  });

  testWidgets('TEST C & E: Rapid back + immediate tab tap', (tester) async {
    await tester.pumpWidget(shellScope());
    await tester.pumpAndSettle();

    // Go to Library
    await tester.tap(find.byIcon(Icons.library_music_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Folders'));
    await tester.pumpAndSettle();

    // Open folder
    await tester.tap(find.text('Rock Classics'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderDetailView), findsOneWidget);

    // Rapid back + tab tap before settling
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(); // single frame, not pumpAndSettle
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(FolderDetailView), findsNothing);
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    final idx = tester.widget<IndexedStack>(find.byType(IndexedStack).first).index;
    expect(idx, 0);
  });

  testWidgets('TEST F: Folder scroll drag then back and switch tab', (tester) async {
    await tester.pumpWidget(shellScope());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.library_music_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Folders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rock Classics'));
    await tester.pumpAndSettle();

    // Fling scroll
    await tester.fling(find.byType(ListView), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();

    // Back
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Switch tab
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    final idx = tester.widget<IndexedStack>(find.byType(IndexedStack).first).index;
    expect(idx, 0);
  });

  testWidgets('TEST J: Stress test loop open folder -> back -> tab switch', (tester) async {
    LibraryFoldersTab.debugDisableDebounce = true;
    addTearDown(() => LibraryFoldersTab.debugDisableDebounce = false);

    await tester.pumpWidget(shellScope());
    await tester.pumpAndSettle();

    for (int i = 0; i < 10; i++) {
      // Library
      await tester.tap(find.byIcon(Icons.library_music_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Folders'));
      await tester.pumpAndSettle();

      // Folder
      await tester.tap(find.text('Rock Classics'));
      await tester.pumpAndSettle();

      // Back
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Home
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();

      final idx = tester.widget<IndexedStack>(find.byType(IndexedStack).first).index;
      expect(idx, 0);
    }
  });
}

