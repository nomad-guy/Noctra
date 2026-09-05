import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/audio/audio_player_service.dart';

/// Regression tests for Noctra-level queue shuffling.
///
/// Contract:
///  * Enabling shuffle keeps the CURRENT song as the first playable
///    entry and shuffles only the others (never duplicates or drops
///    any entry).
///  * Disabling shuffle restores canonical order — songs removed while
///    shuffled stay removed, songs added while shuffled survive, and
///    canonical relative order + multiplicity are preserved exactly.
///  * Identity is queue-position based, so duplicate Song instances or
///    duplicate IDs cannot corrupt the permutation.
Song _song(String id) => Song(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      duration: const Duration(seconds: 30),
    );

List<String> _ids(List<Song> queue) => queue.map((s) => s.id).toList();

/// Resets the singleton service between tests: shuffle off, queue empty.
Future<void> _reset(AudioPlayerService svc) async {
  if (svc.isShuffleEnabled) {
    await svc.toggleShuffle();
  }
  while (svc.queue.isNotEmpty) {
    svc.removeFromQueue(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildShuffledPlaybackOrder (pure)', () {
    final rng = Random(42);

    test('keeps current song first with a deterministic seeded shuffle',
        () {
      final queue = ['A', 'B', 'C', 'D'].map(_song).toList();
      final out = AudioPlayerService.buildShuffledPlaybackOrder(queue, 0, rng);
      expect(out.length, 4);
      expect(out.first.id, 'A');
      expect(_ids(out).toSet(), {'A', 'B', 'C', 'D'});
    });

    test('preserves a middle current song as the first entry', () {
      final queue = ['A', 'B', 'C', 'D'].map(_song).toList();
      final out =
          AudioPlayerService.buildShuffledPlaybackOrder(queue, 2, Random(7));
      expect(out.first.id, 'C');
      expect(out.length, 4);
      expect(_ids(out).toSet(), {'A', 'B', 'C', 'D'});
      // No entry other than the current one was duplicated or dropped.
      expect(_ids(out).where((id) => id == 'C').length, 1);
    });

    test('handles duplicate Song object instances without losing copies', () {
      // The SAME instance is queued twice (a valid playlist state).
      final b = _song('B');
      final queue = [_song('A'), b, b, _song('C')];
      final out = AudioPlayerService.buildShuffledPlaybackOrder(queue, 1, rng);
      expect(out.length, 4);
      expect(out.first.id, 'B');
      // Two B copies must survive: the current one plus the other.
      expect(_ids(out).where((id) => id == 'B').length, 2);
      expect(_ids(out).toSet(), {'A', 'B', 'C'});
    });

    test('empty and one-item queues', () {
      expect(AudioPlayerService.buildShuffledPlaybackOrder([], 0, rng), isEmpty);
      final one = [_song('A')];
      final out =
          AudioPlayerService.buildShuffledPlaybackOrder(one, 0, rng);
      expect(out.length, 1);
      expect(out.first.id, 'A');
    });
  });

  group('restoreCanonicalOrder (pure)', () {
    test('unmodified shuffle restores exact canonical order', () {
      final canonical = ['A', 'B', 'C', 'D'].map(_song).toList();
      // Any live arrangement of the same songs (e.g. shuffle output).
      final live = ['C', 'A', 'D', 'B'].map(_song).toList();
      expect(_ids(AudioPlayerService.restoreCanonicalOrder(canonical, live)),
          ['A', 'B', 'C', 'D']);
    });

    test('songs removed while shuffled stay removed', () {
      final canonical = ['A', 'B', 'C', 'D'].map(_song).toList();
      final live = ['C', 'A', 'B'].map(_song).toList(); // D removed
      expect(_ids(AudioPlayerService.restoreCanonicalOrder(canonical, live)),
          ['A', 'B', 'C']);
    });

    test('songs added while shuffled are preserved (appended in live order)',
        () {
      final canonical = ['A', 'B', 'C', 'D'].map(_song).toList();
      final live = ['C', 'A', 'D', 'B', 'E'].map(_song).toList(); // E added
      expect(_ids(AudioPlayerService.restoreCanonicalOrder(canonical, live)),
          ['A', 'B', 'C', 'D', 'E']);
    });

    test('added + removed simultaneously', () {
      final canonical = ['A', 'B', 'C', 'D'].map(_song).toList();
      final live = ['D', 'A', 'E'].map(_song).toList(); // B,C removed, E added
      expect(_ids(AudioPlayerService.restoreCanonicalOrder(canonical, live)),
          ['A', 'D', 'E']);
    });

    test('duplicate IDs: multiplicity preserved on both sides', () {
      final canonical = ['A', 'B', 'B', 'C'].map(_song).toList();
      // One of the two B entries was removed while shuffled.
      final live = ['B', 'C', 'A'].map(_song).toList();
      expect(_ids(AudioPlayerService.restoreCanonicalOrder(canonical, live)),
          ['A', 'B', 'C']);
    });

    test('duplicate IDs: surplus copies added during shuffle append at end',
        () {
      final canonical = ['A', 'B', 'C'].map(_song).toList();
      final live = ['C', 'A', 'B', 'B'].map(_song).toList(); // extra B added
      expect(_ids(AudioPlayerService.restoreCanonicalOrder(canonical, live)),
          ['A', 'B', 'C', 'B']);
    });

    test('everything removed while shuffled restores to empty', () {
      final canonical = ['A', 'B', 'C'].map(_song).toList();
      expect(
          AudioPlayerService.restoreCanonicalOrder(canonical, []), isEmpty);
    });
  });

  group('AudioPlayerService integration', () {
    final svc = AudioPlayerService.instance;

    setUp(() => _reset(svc));
    tearDown(() => _reset(svc));

    test('enable keeps current first and disable restores canonical order',
        () async {
      for (final id in ['A', 'B', 'C', 'D']) {
        svc.addToQueue(_song(id));
      }
      await svc.toggleShuffle(); // on
      expect(svc.isShuffleEnabled, true);
      expect(svc.queue.length, 4);
      expect(svc.queue.first.id, 'A');
      expect(_ids(svc.queue).toSet(), {'A', 'B', 'C', 'D'});

      await svc.toggleShuffle(); // off
      expect(svc.isShuffleEnabled, false);
      expect(_ids(svc.queue), ['A', 'B', 'C', 'D']);
    });

    test('songs added while shuffled survive a disable', () async {
      for (final id in ['A', 'B', 'C', 'D']) {
        svc.addToQueue(_song(id));
      }
      await svc.toggleShuffle(); // on
      svc.addToQueue(_song('E')); // added mid-shuffle
      expect(svc.queue.length, 5);

      await svc.toggleShuffle(); // off
      expect(svc.queue.length, 5);
      expect(_ids(svc.queue), ['A', 'B', 'C', 'D', 'E']);
    });

    test('songs removed while shuffled stay removed after a disable',
        () async {
      for (final id in ['A', 'B', 'C', 'D']) {
        svc.addToQueue(_song(id));
      }
      await svc.toggleShuffle(); // on
      // Remove the last physical entry (whichever song it is).
      svc.removeFromQueue(svc.queue.length - 1);
      final removed = {'A', 'B', 'C', 'D'}
          .difference(_ids(svc.queue).toSet())
          .single;
      expect(svc.queue.length, 3);

      await svc.toggleShuffle(); // off
      expect(_ids(svc.queue).toSet(), {'A', 'B', 'C', 'D'}..remove(removed));
      expect(svc.queue.length, 3);
      // Canonical relative order of the survivors is preserved.
      expect(_ids(svc.queue), ['A', 'B', 'C', 'D']..remove(removed));
    });

    test('enable/disable/enable is stable and keeps entries intact', () async {
      for (final id in ['A', 'B', 'C', 'D']) {
        svc.addToQueue(_song(id));
      }
      await svc.toggleShuffle(); // on
      await svc.toggleShuffle(); // off
      expect(_ids(svc.queue), ['A', 'B', 'C', 'D']);
      await svc.toggleShuffle(); // on again — must not duplicate or drop
      expect(svc.queue.length, 4);
      expect(_ids(svc.queue).toSet(), {'A', 'B', 'C', 'D'});
    });
  });
}
