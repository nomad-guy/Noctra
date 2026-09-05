import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/ui/widgets/library/ai_collection_detail_view.dart';

/// Phase 23 regression tests — AI folders/mixes must OPEN into a detail view
/// (they previously only auto-played on tap) and support Remix.
Song _song(String id, String title) => Song(
      id: id,
      title: title,
      artist: 'Artist $id',
      duration: const Duration(seconds: 180),
      artworkUrl: 'https://example.com/$id.jpg',
    );

Future<void> _pumpView(
  WidgetTester tester, {
  required String vibeKey,
  AiTracksLoader? loader,
  String title = 'Late Night Moods',
  List<Song> initial = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: AiCollectionDetailView(
          isDark: true,
          repo: MusicRepository(),
          title: title,
          subtitle: 'Slow-burning night selections',
          vibeKey: vibeKey,
          initialTracks: initial,
          loader: loader,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generated folder opens and lists its resolved tracks',
      (tester) async {
    await _pumpView(
      tester,
      vibeKey: 'late_night',
      loader: (vk, {previousIds, epoch}) async =>
          [_song('n1', 'Noir One'), _song('n2', 'Noir Two')],
    );
    expect(find.text('Late Night Moods'), findsOneWidget);
    expect(find.text('Noir One'), findsOneWidget);
    expect(find.text('Noir Two'), findsOneWidget);
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Remix'), findsOneWidget);
  });

  testWidgets('Remix re-orders the resolved pool locally without re-resolving',
      (tester) async {
    var resolveCount = 0;
    await _pumpView(
      tester,
      vibeKey: 'late_night',
      loader: (vk, {previousIds, epoch}) async {
        resolveCount++;
        return [_song('a', 'Alpha'), _song('b', 'Beta')];
      },
    );
    expect(resolveCount, 1);

    await tester.tap(find.text('Remix'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(resolveCount, 1,
        reason: 'remix must re-order the already-resolved pool, never run a '
            'second network resolution');
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('favorites/downloads folders expose no Remix button',
      (tester) async {
    await _pumpView(
      tester,
      vibeKey: 'favorites',
      loader: (vk, {previousIds, epoch}) async => [_song('f1', 'Fav One')],
    );
    expect(find.text('Fav One'), findsOneWidget);
    expect(find.text('Remix'), findsNothing,
        reason: 'your actual favorites are not a remixable generated set');
    expect(find.text('Play All'), findsOneWidget);
  });

  testWidgets('mixes that already carry curated tracks open instantly',
      (tester) async {
    await _pumpView(
      tester,
      vibeKey: 'discovery',
      initial: [_song('c1', 'Curated One'), _song('c2', 'Curated Two')],
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Curated One'), findsOneWidget);
    expect(find.text('Curated Two'), findsOneWidget);
  });

  testWidgets('empty resolve shows the friendly empty state, not a spinner',
      (tester) async {
    await _pumpView(
      tester,
      vibeKey: 'retro_synth',
      loader: (vk, {previousIds, epoch}) async => <Song>[],
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('load failure shows a Retry action that can recover',
      (tester) async {
    var failing = true;
    await _pumpView(
      tester,
      vibeKey: 'late_night',
      loader: (vk, {previousIds, epoch}) async {
        if (failing) throw Exception('offline');
        return [_song('ok1', 'Recovered')];
      },
    );
    expect(find.textContaining('Could not load'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    failing = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Recovered'), findsOneWidget);
  });
}