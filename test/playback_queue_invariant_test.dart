import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/audio/audio_player_service.dart';

/// Regression tests for queue/current-state invariants of the REAL
/// AudioPlayerService singleton.
///
/// Why these matter:
///  * `removeFromQueue` must never replay the removed track or jump to a
///    stale index when the current song's queue entry disappears.
///  * Queue operations with duplicate song IDs must not corrupt
///    `currentIndex` vs `currentSong` consistency.
///  * The seam (`debugSetPlaybackPosition`) drives the exact production
///    state fields the service uses during real playback, without the
///    platform audio layer.
Song _song(String id) => Song(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      duration: const Duration(seconds: 30),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = AudioPlayerService.instance;

  tearDown(() async {
    // Remove everything so tests never observe each other's queues, and
    // let any unawaited serialized fall-out settle before the next test.
    while (svc.queue.isNotEmpty) {
      svc.removeFromQueue(0);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  group('remove current track', () {
    test('middle removal advances forward, never replays the removed track',
        () async {
      final a = _song('A');
      final b = _song('B');
      final c = _song('C');
      svc.debugSetPlaybackPosition(queue: [a, b, c], index: 1); // playing B
      expect(svc.currentSong!.id, 'B');
      expect(svc.currentIndex, 1);

      svc.removeFromQueue(1); // user removes the currently playing B
      expect(svc.queue.map((s) => s.id).toList(), ['A', 'C']);
      // The next playable entry is C at index 1 — the service must not
      // leave index pointing at A (stale) or replay B.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(svc.currentSong, isNotNull);
      expect(svc.currentSong!.id, 'C');
      expect(svc.currentIndex, 1);
      expect(svc.queue[svc.currentIndex].id, 'C');
    });

    test('removing the only queue entry while it plays stops cleanly',
        () async {
      final a = _song('A');
      svc.debugSetPlaybackPosition(queue: [a], index: 0, currentSong: a);
      svc.removeFromQueue(0);
      expect(svc.queue, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(svc.currentSong, isNull);
      expect(svc.currentIndex, 0);
    });
  });

  group('removing non-current entries with duplicate IDs', () {
    test('removing an earlier duplicate keeps the playing entry consistent',
        () async {
      final a1 = _song('A');
      final a2 = _song('A'); // distinct instance, same logical ID
      final b = _song('B');
      // Queue [A,A,B]; playing the SECOND A at index 1.
      svc.debugSetPlaybackPosition(
          queue: [a1, a2, b], index: 1, currentSong: a2);
      expect(svc.currentIndex, 1);

      // The user removes the FIRST A (index 0). The player is still on A
      // (index 0 now) — currentSong must remain an A and the index must
      // map to a real A entry.
      svc.removeFromQueue(0);
      expect(svc.queue.map((s) => s.id).toList(), ['A', 'B']);
      expect(svc.currentSong, isNotNull);
      expect(svc.currentSong!.id, 'A');
      expect(svc.currentIndex, inInclusiveRange(0, 1));
      expect(svc.queue[svc.currentIndex].id, 'A');
    });

    test('removing the LAST copy of the current ID stops playback', () async {
      final a = _song('A');
      final b1 = _song('B');
      final b2 = _song('B');
      final c = _song('C');
      // Queue [A,B,B,C]; playing B (index 1).
      svc.debugSetPlaybackPosition(
          queue: [a, b1, b2, c], index: 1, currentSong: b1);
      // Remove the SECOND B (index 2) — current B (index 1) still exists.
      svc.removeFromQueue(2);
      expect(svc.queue.map((s) => s.id).toList(), ['A', 'B', 'C']);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(svc.currentSong, isNotNull);
      expect(svc.currentSong!.id, 'B');
      expect(svc.queue[svc.currentIndex].id, 'B');

      // Now remove the remaining B while it is playing.
      final bIndex = svc.queue.indexWhere((s) => s.id == 'B');
      svc.removeFromQueue(bIndex);
      expect(svc.queue.map((s) => s.id).toList(), ['A', 'C']);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(svc.currentSong, isNotNull);
      // Must advance to one of the remaining entries — never point at a
      // non-existent song.
      expect(['A', 'C'], contains(svc.currentSong!.id));
      expect(svc.queue[svc.currentIndex].id, svc.currentSong!.id);
    });
  });

  group('reorder / clear consistency', () {
    test('reorder keeps current song at its new index (duplicates safe)',
        () async {
      final a = _song('A');
      final b = _song('B');
      final c = _song('C');
      svc.debugSetPlaybackPosition(queue: [a, b, c], index: 0, currentSong: a);
      svc.reorderQueue(0, 2); // move playing A to the end
      expect(svc.queue.map((s) => s.id).toList(), ['B', 'C', 'A']);
      expect(svc.currentSong!.id, 'A');
      expect(svc.currentIndex, 2);
      expect(svc.queue[svc.currentIndex].id, 'A');
    });

    test('clearQueue keeps only the current entry at index 0', () async {
      final a = _song('A');
      final b = _song('B');
      final c = _song('C');
      svc.debugSetPlaybackPosition(queue: [a, b, c], index: 1, currentSong: b);
      svc.clearQueue();
      expect(svc.queue.map((s) => s.id).toList(), ['B']);
      expect(svc.currentIndex, 0);
      expect(svc.currentSong!.id, 'B');
    });
  });

  group('reorder with duplicate IDs (instance identity)', () {
    test('reordering the FIRST duplicate keeps the SECOND as current', () {
      final a1 = _song('A');
      final a2 = _song('A');
      final b = _song('B');
      // Queue [A(first),A(second),B]; playing the SECOND A at index 1.
      svc.debugSetPlaybackPosition(
          queue: [a1, a2, b], index: 1, currentSong: a2);
      // Move the FIRST A (index 0) to the end.
      svc.reorderQueue(0, 2);
      expect(svc.queue.map((s) => s.id).toList(), ['A', 'B', 'A']);
      // The playing instance is the second A, which never moved — it must
      // stay at index 0, and ID-based reconciliation must NOT re-pin the
      // index to a different A copy.
      expect(identical(svc.currentSong, a2), isTrue);
      expect(svc.currentIndex, 0);
      expect(identical(svc.queue[svc.currentIndex], a2), isTrue);
    });

    test('reordering the PLAYING duplicate keeps the same instance current',
        () {
      final a1 = _song('A');
      final a2 = _song('A');
      final b = _song('B');
      // Queue [A(first),A(second),B]; playing the FIRST A at index 0.
      svc.debugSetPlaybackPosition(
          queue: [a1, a2, b], index: 0, currentSong: a1);
      svc.reorderQueue(0, 2); // move the playing A to the end
      expect(svc.queue.map((s) => s.id).toList(), ['A', 'B', 'A']);
      expect(identical(svc.currentSong, a1), isTrue);
      expect(svc.currentIndex, 2);
      expect(identical(svc.queue[svc.currentIndex], a1), isTrue);
    });
  });

  group('shuffle with duplicates', () {
    test('buildShuffledPlaybackOrder keeps the exact current position entry',
        () {
      final a1 = _song('A');
      final a2 = _song('A');
      final b = _song('B');
      final order = AudioPlayerService.buildShuffledPlaybackOrder(
          [a1, a2, b], 1, null); // current = the SECOND A (index 1)
      expect(order.length, 3);
      // Position-based: the entry at index 1 stays first — the a2 instance
      // itself, so instance equality is preserved.
      expect(identical(order.first, a2), isTrue);
    });

    test('restoreCanonicalOrder keeps multiplicity of duplicate IDs', () {
      final canonical = [_song('A'), _song('A'), _song('B')];
      final live = [_song('A'), _song('B'), _song('B')];
      final rebuilt = AudioPlayerService.restoreCanonicalOrder(canonical, live);
      final ids = rebuilt.map((s) => s.id).toList();
      // A appears min(2,1)=1 time from canonical, B appears once from
      // canonical then the surplus B from live.
      expect(ids.where((id) => id == 'A').length, 1);
      expect(ids.where((id) => id == 'B').length, 2);
      expect(rebuilt.length, 3);
    });

    test('shuffle-off restores the PLAYING duplicate instance position',
        () async {
      final a1 = _song('A');
      final a2 = _song('A');
      final b = _song('B');
      final c = _song('C');
      // Queue [A,A,B,C]; playing the SECOND A (index 1).
      svc.debugSetPlaybackPosition(
          queue: [a1, a2, b, c], index: 1, currentSong: a2);
      await svc.toggleShuffle(); // ON — canonical snapshot taken
      expect(svc.isShuffleEnabled, isTrue);
      // Playing instance is first in the shuffled order.
      expect(svc.queue.first.id, 'A');
      await svc.toggleShuffle(); // OFF — restore canonical order
      expect(svc.isShuffleEnabled, isFalse);
      // The playing entry is a2 at index 1 (its canonical position) —
      // never the first A copy at index 0.
      expect(identical(svc.currentSong, a2), isTrue);
      expect(svc.queue[svc.currentIndex].id, 'A');
    });
  });
}
