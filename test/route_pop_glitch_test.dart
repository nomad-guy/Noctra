import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/ui/screens/artist_screen.dart';
import 'package:noctra/ui/widgets/library/ai_collection_detail_view.dart';

void main() {
  testWidgets('Push and pop ArtistScreen without transition glitch or freeze', (tester) async {

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ArtistScreen(
                        artistName: 'Arijit Singh',
                      ),
                    ),
                  );
                },
                child: const Text('Open Artist'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap to open ArtistScreen
    await tester.tap(find.text('Open Artist'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify ArtistScreen is opened
    expect(find.byType(ArtistScreen), findsOneWidget);

    // Find the back button
    final backButtonFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
    expect(backButtonFinder, findsOneWidget);
    await tester.tap(backButtonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify ArtistScreen is popped and home is interactive
    expect(find.byType(ArtistScreen), findsNothing);
    expect(find.text('Open Artist'), findsOneWidget);
  });

  testWidgets('Push and pop AiCollectionDetailView without transition glitch or freeze', (tester) async {
    final repo = MusicRepository();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiCollectionDetailView(
                        isDark: true,
                        repo: repo,
                        title: 'Chill Vibes',
                        vibeKey: 'chill',
                        initialTracks: [
                          Song(id: '1', title: 'Song 1', artist: 'Artist 1', duration: const Duration(seconds: 200)),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Playlist'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap to open playlist
    await tester.tap(find.text('Open Playlist'));
    await tester.pumpAndSettle();

    expect(find.byType(AiCollectionDetailView), findsOneWidget);

    // Find back button
    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(AiCollectionDetailView), findsNothing);
    expect(find.text('Open Playlist'), findsOneWidget);
  });
}
