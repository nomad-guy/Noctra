import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/audio/audio_player_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 25 — Playback stress. Hammers the REAL AudioPlayerService singleton
/// with rapid/concurrent public controls (skip, previous, play/pause, seek,
/// queue removal) and asserts the state machine never corrupts its
/// invariants or surfaces unhandled errors.
///
/// The `debugSetPlaybackPosition` seam seeds state without the platform
/// audio layer; production control methods are then driven exactly as the
/// UI would drive them.
Song _song(String id) => Song(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      duration: const Duration(seconds: 45),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Persistence writes triggered by playback state changes need a live
  // (mock) shared_preferences store; without it, MissingPluginExceptions
  // escape from unguarded save futures and poison the async zone.
  SharedPreferences.setMockInitialValues({});
  final svc = AudioPlayerService.instance;

  tearDown(() async {
    while (svc.queue.isNotEmpty) {
      svc.removeFromQueue(0);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });

  group('rapid control bursts', () {
    test('50 concurrent skips stay in-bounds and settle on one track',
        () async {
      final queue = ['A', 'B', 'C', 'D', 'E'].map(_song).toList();
      svc.debugSetPlaybackPosition(queue: queue, index: 0);
      expect(svc.currentSong?.id, 'A');

      final errors = <Object>[];
      await Future.wait(List.generate(50, (_) async {
        try {
          await svc.skipNext();
        } catch (e) {
          errors.add(e);
        }
      }));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(errors, isEmpty);
      expect(svc.currentIndex, inInclusiveRange(0, queue.length - 1));
      // Whatever track won the burst, queue and index must agree.
      final i = svc.currentIndex;
      expect(svc.queue[i].id, isNotNull);
      if (svc.currentSong != null) {
        expect(svc.currentSong!.id, svc.queue[i].id);
      }
    });

    test('interleaved skip/previous/toggle/seek never throws or deadlocks',
        () async {
      final queue = ['A', 'B', 'C', 'D', 'E'].map(_song).toList();
      svc.debugSetPlaybackPosition(queue: queue, index: 2); // playing C

      final errors = <Object>[];
      await Future.wait(List.generate(40, (n) async {
        try {
          switch (n % 4) {
            case 0:
              await svc.skipNext();
              break;
            case 1:
              await svc.skipPrevious();
              break;
            case 2:
              await svc.togglePlayPause();
              break;
            case 3:
              await svc.seek(Duration(seconds: n % 30));
              break;
          }
        } catch (e) {
          errors.add(e);
        }
      }));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(errors, isEmpty);
      expect(svc.currentIndex, inInclusiveRange(0, queue.length - 1));
      expect(svc.queue[svc.currentIndex], isNotNull);
    });

    test('queue removal racing skips keeps index in a valid range', () async {
      final queue = List.generate(6, (n) => _song('S$n'));
      svc.debugSetPlaybackPosition(queue: queue, index: 0);

      final errors = <Object>[];
      await Future.wait(List.generate(30, (n) async {
        try {
          if (n.isEven && svc.queue.length > 1) {
            svc.removeFromQueue(0);
          } else {
            await svc.skipNext();
          }
        } catch (e) {
          errors.add(e);
        }
      }));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(errors, isEmpty);
      final q = svc.queue;
      expect(svc.currentIndex, inInclusiveRange(0, q.isEmpty ? 0 : q.length - 1));
      if (q.isNotEmpty && svc.currentSong != null) {
        expect(svc.currentSong!.id, q[svc.currentIndex].id);
      }
    });
  });
}
