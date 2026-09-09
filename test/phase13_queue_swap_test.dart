import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/audio/audio_player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
      'PlayerQueueMixin.onSongDownloaded — Hot Swapping & Queue In-Place Update',
      () {
    test(
        'Updates currentSong and queue with localFilePath and isDownloaded = true',
        () {
      final svc = AudioPlayerService.instance;

      final songOnline = Song(
        id: 'song-dl-1',
        title: 'Downloading Track',
        artist: 'Artist One',
        duration: const Duration(seconds: 210),
        streamUrl: 'https://aac.saavncdn.com/test.mp4',
        isDownloaded: false,
      );

      final otherSong = Song(
        id: 'song-dl-2',
        title: 'Queued Track',
        artist: 'Artist Two',
        duration: const Duration(seconds: 190),
      );

      svc.debugSetPlaybackPosition(
          queue: [songOnline, otherSong], index: 0, currentSong: songOnline);
      expect(svc.currentSong?.isDownloaded, isFalse);
      expect(svc.currentSong?.localFilePath, isNull);

      final downloadedSong = songOnline.copyWith(
        isDownloaded: true,
        localFilePath: '/storage/emulated/0/Music/Noctra/song-dl-1.m4a',
      );

      svc.onSongDownloaded(downloadedSong);

      expect(svc.currentSong?.isDownloaded, isTrue);
      expect(svc.currentSong?.localFilePath,
          '/storage/emulated/0/Music/Noctra/song-dl-1.m4a');
      expect(svc.queue[0].isDownloaded, isTrue);
      expect(svc.queue[0].localFilePath,
          '/storage/emulated/0/Music/Noctra/song-dl-1.m4a');
      expect(svc.queue[1].isDownloaded, isFalse);
    });
  });
}
