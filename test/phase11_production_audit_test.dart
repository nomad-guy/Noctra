import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/services/audio/audio_player_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    await NoctraLocalDatabase().init();
    MusicRepository.instance.debugResetForTest();
    await MusicRepository.instance.init();
  });

  group('Phase 11 Audit: Data Integrity & Cross-Collection Synchronization', () {
    test('addDownloadedSong stamps favorites and custom folders', () async {
      final repo = MusicRepository.instance;
      final song = Song(
        id: 'track_phase11_sync',
        title: 'Sync Anthem',
        artist: 'Noctra Crew',
        album: 'Audit Album',
        duration: const Duration(seconds: 180),
      );

      // 1. Add song to favorites
      repo.toggleFavorite(song);
      expect(repo.favorites.any((s) => s.id == song.id), isTrue);
      expect(repo.favorites.firstWhere((s) => s.id == song.id).isDownloaded, isFalse);

      // 2. Add song to custom folder
      repo.createFolder('Audit Folder');
      repo.addSongToFolder('Audit Folder', song);
      expect(repo.customFolders['Audit Folder']!.first.isDownloaded, isFalse);

      // 3. Mark song as downloaded with local path
      final downloadedSong = song.copyWith(
        isDownloaded: true,
        localFilePath: '/mock/storage/sync_anthem.mp3',
      );
      repo.addDownloadedSong(downloadedSong);

      // 4. Verify downloads list has it
      expect(repo.isDownloaded(song.id), isTrue);
      expect(repo.downloads.firstWhere((s) => s.id == song.id).localFilePath,
          '/mock/storage/sync_anthem.mp3');

      // 5. Verify favorites entry was stamped with download path
      final fav = repo.favorites.firstWhere((s) => s.id == song.id);
      expect(fav.isDownloaded, isTrue);
      expect(fav.localFilePath, '/mock/storage/sync_anthem.mp3');

      // 6. Verify custom folder entry was stamped with download path
      final folderSong = repo.customFolders['Audit Folder']!.first;
      expect(folderSong.isDownloaded, isTrue);
      expect(folderSong.localFilePath, '/mock/storage/sync_anthem.mp3');
    });

    test('removeDownloadedSong un-stamps favorites and custom folders', () async {
      final repo = MusicRepository.instance;
      final song = Song(
        id: 'track_phase11_remove',
        title: 'Removal Track',
        artist: 'Noctra Artist',
        album: 'Removal Album',
        duration: const Duration(seconds: 210),
      );

      // Add to favorites and custom folder
      repo.toggleFavorite(song);
      repo.createFolder('Removal Folder');
      repo.addSongToFolder('Removal Folder', song);

      // Add downloaded
      final downloadedSong = song.copyWith(
        isDownloaded: true,
        localFilePath: '/mock/storage/removal.mp3',
      );
      repo.addDownloadedSong(downloadedSong);
      expect(repo.isDownloaded(song.id), isTrue);

      // Remove download
      await repo.removeDownloadedSong(song.id, deleteFile: false);

      // Verify downloads list has removed it
      expect(repo.isDownloaded(song.id), isFalse);

      // Verify favorites entry is un-stamped
      final fav = repo.favorites.firstWhere((s) => s.id == song.id);
      expect(fav.isDownloaded, isFalse);
      expect(fav.localFilePath, isNull);

      // Verify custom folder entry is un-stamped
      final folderSong = repo.customFolders['Removal Folder']!.first;
      expect(folderSong.isDownloaded, isFalse);
      expect(folderSong.localFilePath, isNull);
    });

    test('pruneMissingDownloadedFiles cleans dead paths across favorites and folders', () async {
      final repo = MusicRepository.instance;
      final song = Song(
        id: 'track_phase11_ghost',
        title: 'Ghost File',
        artist: 'Phantom',
        album: 'Ether',
        duration: const Duration(seconds: 150),
      );

      repo.toggleFavorite(song);
      repo.createFolder('Ghost Folder');
      repo.addSongToFolder('Ghost Folder', song);

      // Non-existent path
      final downloadedSong = song.copyWith(
        isDownloaded: true,
        localFilePath: '/mock/storage/definitely_nonexistent_file_xyz123.mp3',
      );
      repo.addDownloadedSong(downloadedSong);

      // Run prune
      final pruned = await repo.pruneMissingDownloadedFiles();
      expect(pruned, 1);

      expect(repo.isDownloaded(song.id), isFalse);
      expect(repo.favorites.firstWhere((s) => s.id == song.id).isDownloaded, isFalse);
      expect(repo.customFolders['Ghost Folder']!.first.isDownloaded, isFalse);
    });
  });

  group('Phase 11 Audit: Audio Queue Duplicate Song ID Resolution', () {
    test('playSong with queueIndex selects exact duplicate instance in queue', () async {
      final player = AudioPlayerService.instance;
      final songA1 = Song(
        id: 'duplicate_id_x',
        title: 'Duplicate Track',
        artist: 'Clone Artist',
        album: 'Clone Album',
        duration: const Duration(seconds: 120),
      );
      final songB = Song(
        id: 'middle_track_y',
        title: 'Middle Track',
        artist: 'Middle Artist',
        album: 'Middle Album',
        duration: const Duration(seconds: 140),
      );
      final songA2 = Song(
        id: 'duplicate_id_x', // Same ID!
        title: 'Duplicate Track',
        artist: 'Clone Artist',
        album: 'Clone Album',
        duration: const Duration(seconds: 120),
      );

      // Initialize queue with [A1, B, A2]
      final queue = [songA1, songB, songA2];
      await player.playSong(songA1, newQueue: queue, queueIndex: 0);
      expect(player.currentIndex, 0);

      // Now request to play the duplicate at index 2
      await player.playSong(songA2, queueIndex: 2);
      expect(player.currentIndex, 2);
      expect(identical(player.currentSong, songA2) || player.currentSong?.id == 'duplicate_id_x', isTrue);
    });
  });
}
