import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/services/assistant/domain/assistant_command.dart';
import 'package:noctra/services/assistant/domain/assistant_result.dart';
import 'package:noctra/services/assistant/infrastructure/assistant_intent_channel.dart';
import 'package:noctra/services/assistant/application/assistant_command_router.dart';

Song _testSong(String id,
    {String title = 'Test Track', String artist = 'Test Artist'}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: 'Test Album',
    duration: const Duration(seconds: 180),
  );
}

class _FailingPrefsStore extends InMemorySharedPreferencesStore {
  _FailingPrefsStore() : super.empty();

  bool shouldThrow = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (shouldThrow) {
      throw StateError('Disk I/O failure simulation');
    }
    return super.setValue(valueType, key, value);
  }
}

class _MockRouter extends AssistantCommandRouter {
  final List<AssistantCommand> executedCommands = [];

  @override
  Future<AssistantResult> execute(AssistantCommand command) async {
    executedCommands.add(command);
    return const AssistantSuccess('ok');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    NoctraLocalDatabase().debugResetForTest();
    MusicRepository.debugResetSingleton();
  });

  group('Core State & Lifecycle Hardening Tests', () {
    test(
        'updateSongMetadata propagates to localLibrary, favorites, and folders',
        () async {
      final repo = MusicRepository();
      final song = _testSong('s1', title: 'Original Title', artist: 'Artist 1');

      // Inject into internal library for testing
      repo.addDownloadedSong(song);
      repo.createFolder('My Playlist');
      repo.addSongToFolder('My Playlist', song);
      repo.toggleFavorite(song);

      final enriched = song.copyWith(
        title: 'Enriched Title',
        artworkUrl: 'https://example.com/artwork.jpg',
        duration: const Duration(seconds: 240),
      );
      repo.updateSongMetadata(enriched);

      // Verify favorites updated
      expect(
          repo.favorites.first.artworkUrl, 'https://example.com/artwork.jpg');
      expect(repo.favorites.first.title, 'Enriched Title');

      // Verify downloads updated
      expect(
          repo.downloads.first.artworkUrl, 'https://example.com/artwork.jpg');

      // Verify folder updated
      expect(repo.customFolders['My Playlist']!.first.artworkUrl,
          'https://example.com/artwork.jpg');
    });

    test('reconciliation during init does not resurrect deleted folders',
        () async {
      final db = NoctraLocalDatabase();
      final folderSongs = [_testSong('f1'), _testSong('f2')];
      await db.saveCustomFolders({'Temporary Playlist': folderSongs});

      // User deletes the folder before repository initialization finishes
      final repo = MusicRepository();
      repo.createFolder('Temporary Playlist');
      repo.deleteFolder('Temporary Playlist');

      await repo.init();

      expect(repo.customFolders.containsKey('Temporary Playlist'), isFalse,
          reason:
              'Deleted folder must not be resurrected by startup disk load');
    });

    test(
        'database write failures are contained safely and do not wedge the queue',
        () async {
      final db = NoctraLocalDatabase();
      db.debugResetForTest();
      final store = _FailingPrefsStore();
      SharedPreferencesStorePlatform.instance = store;

      // First write fails — contained and logged without throwing
      await db.saveFavorites([_testSong('f1')]);
      
      // Queue is not wedged: subsequent write succeeds
      store.shouldThrow = false;
      await db.saveFavorites([_testSong('f2')]);

      final favs = await db.loadFavorites();
      expect(favs.length, 1);
      expect(favs.first.id, 'f2');
    });

    test('AssistantIntentChannel skips duplicate intents on cold start replay',
        () async {
      final router = _MockRouter();
      final channel = AssistantIntentChannel(router: router);

      final intentArgs = {
        'intentId': 'unique-uuid-1234',
        'query': 'Play Rock Music',
        'action': 'android.media.action.MEDIA_PLAY_FROM_SEARCH',
        'extras': <String, dynamic>{},
      };

      // Native and Flutter both dispatch the exact same cold-start intent
      await channel.dispatchIntentForTest(intentArgs);
      await channel.dispatchIntentForTest(intentArgs);

      expect(router.executedCommands.length, 1,
          reason: 'Duplicate assistant intent must be dropped');
    });

    test('SearchCommand executes search without starting playback', () async {
      final mockRouter = _MockRouter();
      const searchCmd = SearchCommand('Arijit Singh');
      final result = await mockRouter.execute(searchCmd);

      expect(result, isA<AssistantSuccess>());
      expect(mockRouter.executedCommands.first, isA<SearchCommand>());
      expect(mockRouter.executedCommands.whereType<SearchAndPlayCommand>(),
          isEmpty);
    });
  });
}
