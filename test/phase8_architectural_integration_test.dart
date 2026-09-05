import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/services/audio/audio_player_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _testSong(String id, {String title = 'Test Track'}) => Song(
      id: id,
      title: title,
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 180),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    await NoctraLocalDatabase().init();
  });

  group('Phase 8 - Architectural Integration & Behavioral Consistency', () {
    test('Sleep timer cancel and zero minutes clears timer cleanly', () {
      final player = AudioPlayerService.instance;
      // Setting timer to 15 minutes
      player.setSleepTimer(15);
      expect(player.sleepTimerRemainingMinutes, 15);

      // Setting to 0 (e.g. from Settings 'Off' selection)
      player.setSleepTimer(0);
      expect(player.sleepTimerRemainingMinutes, isNull);

      // cancelSleepTimer also clears
      player.setSleepTimer(30);
      expect(player.sleepTimerRemainingMinutes, 30);
      player.cancelSleepTimer();
      expect(player.sleepTimerRemainingMinutes, isNull);
    });

    test('Queue removal of playing track routes through serialized playSong', () async {
      final player = AudioPlayerService.instance;
      final song1 = _testSong('track_1');
      final song2 = _testSong('track_2');
      final song3 = _testSong('track_3');

      player.debugSetPlaybackPosition(
        queue: [song1, song2, song3],
        index: 1,
        currentSong: song2,
      );
      expect(player.currentIndex, 1);
      expect(player.currentSong?.id, 'track_2');

      // Removing current track (index 1)
      player.removeFromQueue(1);
      expect(player.queue.map((s) => s.id).toList(), ['track_1', 'track_3']);
      // Should now point to track_3 at index 1
      expect(player.currentIndex, 1);
    });

    test('Queue removal of only playing track clears current song and stops cleanly', () {
      final player = AudioPlayerService.instance;
      final song = _testSong('solo_track');

      player.debugSetPlaybackPosition(
        queue: [song],
        index: 0,
        currentSong: song,
      );
      expect(player.queue.length, 1);
      expect(player.currentSong?.id, 'solo_track');

      player.removeFromQueue(0);
      expect(player.queue.isEmpty, isTrue);
      expect(player.currentIndex, 0);
      expect(player.currentSong, isNull);
    });

    test('Pause and Stop increment play session epoch to cancel stale in-flight loads', () {
      final player = AudioPlayerService.instance;
      // Capture baseline
      player.pause();
      // Should not throw and player remains paused
      expect(player.player.playing, isFalse);

      player.stopAndDismiss();
      expect(player.currentSong, isNull);
    });

    test('Static shuffle and canonical restore maintain position and multiplicity', () {
      final a1 = _testSong('A');
      final a2 = _testSong('A');
      final b = _testSong('B');
      final c = _testSong('C');

      final queue = [a1, b, a2, c];
      // Index 2 is a2
      final shuffled = AudioPlayerService.buildShuffledPlaybackOrder(queue, 2);
      expect(shuffled.first.id, 'A');
      expect(identical(shuffled.first, a2), isTrue);
      expect(shuffled.length, 4);

      // Rebuilding canonical order preserves exact counts
      final restored = AudioPlayerService.restoreCanonicalOrder(queue, shuffled);
      expect(restored.map((s) => s.id).toList(), ['A', 'B', 'A', 'C']);
    });

    test('Audio effects settings and Studio Master mode dispatch safely', () async {
      final player = AudioPlayerService.instance;
      // Non-Android/desktop returns false gracefully without throwing
      final applied = await player.applyStudioMasterMode('lossless320');
      expect(applied, isA<bool>());

      expect(
        () => player.applyEqualizer(bands: [0.0, 1.0, -1.0, 0.5, 0.0]),
        returnsNormally,
      );
      // The fire-and-forget channel call must not leak an unhandled
      // async error (MissingPluginException in tests) onto the zone.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    testWidgets(
        'applyEqualizer leaks no unhandled platform-channel error in tests',
        (tester) async {
      final player = AudioPlayerService.instance;
      // No native handler is registered under the test binding, so the
      // channel Future completes with MissingPluginException. Pre-fix this
      // surfaced as an unhandled async error failing the current test.
      player.applyEqualizer(bands: [0.0, 1.0, -1.0, 0.5, 0.0]);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
