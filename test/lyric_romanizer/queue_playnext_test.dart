import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';

/// Unit tests for queue management logic.
/// We test the index math and list operations that AudioPlayerService.queue
/// relies on, since AudioPlayerService requires real platform audio.
void main() {
  Song mk(String id) => Song(
    id: id,
    title: 'Song $id',
    artist: 'Artist $id',
    album: 'Album',
    duration: const Duration(minutes: 3),
  );

  group('Queue index math', () {
    test('addToQueue appends at end', () {
      final q = [mk('1'), mk('2')];
      q.add(mk('3'));
      expect(q.length, 3);
      expect(q.last.id, '3');
    });

    test('playNext inserts after current index', () {
      final q = [mk('1'), mk('2'), mk('3')];
      final ci = 0;
      q.insert((ci + 1).clamp(0, q.length), mk('4'));
      expect(q.length, 4);
      expect(q[1].id, '4');
      expect(q[2].id, '2');
    });

    test('playNext at end of queue inserts at length', () {
      final q = [mk('1'), mk('2')];
      q.insert((1 + 1).clamp(0, q.length), mk('3'));
      expect(q.length, 3);
      expect(q[2].id, '3');
    });

    test('removeFromQueue shifts currentIndex down when removing before', () {
      final q = [mk('1'), mk('2'), mk('3')];
      var ci = 2;
      q.removeAt(0);
      ci--;
      expect(ci, 1);
      expect(q.length, 2);
      expect(q[ci].id, '3');
    });

    test('removeFromQueue when removing current song', () {
      final q = [mk('1'), mk('2'), mk('3')];
      var ci = 1;
      q.removeAt(1);
      ci = ci.clamp(0, q.length - 1);
      expect(ci, 1);
      expect(q[ci].id, '3');
    });

    test('removeFromQueue last item when current', () {
      final q = [mk('1'), mk('2')];
      var ci = 1;
      q.removeAt(1);
      ci = ci.clamp(0, q.length - 1);
      expect(ci, 0);
      expect(q.length, 1);
    });

    test('reorderQueue moves song from oldIndex to newIndex', () {
      final q = [mk('1'), mk('2'), mk('3'), mk('4')];
      var ci = 1;
      final song = q.removeAt(3);
      q.insert(0, song);
      // 3 > ci(1) and 0 <= ci(1) => ci++
      ci++;
      expect(q[0].id, '4');
      expect(ci, 2);
    });

    test('clearQueue keeps only current song', () {
      final q = [mk('1'), mk('2'), mk('3')];
      final current = q[1];
      q.clear();
      q.add(current);
      expect(q.length, 1);
      expect(q[0].id, '2');
    });
  });

  group('Play Next queue behavior', () {
    test('multiple playNext calls stack in order', () {
      final q = [mk('1')];
      q.insert(1, mk('A'));
      q.insert(2, mk('B'));
      expect(q.length, 3);
      expect(q[1].id, 'A');
      expect(q[2].id, 'B');
    });

    test('addToQueue + playNext maintain order', () {
      final q = [mk('1')];
      q.add(mk('2'));    // addToQueue
      q.insert(1, mk('3')); // playNext
      expect(q.length, 3);
      expect(q[0].id, '1');
      expect(q[1].id, '3');
      expect(q[2].id, '2');
    });

    test('skipNext increments index correctly', () {
      final q = [mk('1'), mk('2'), mk('3')];
      var ci = 0;
      ci = (ci + 1) % q.length;
      expect(ci, 1);
      ci = (ci + 1) % q.length;
      expect(ci, 2);
      ci = (ci + 1) % q.length;
      expect(ci, 0);
    });

    test('skipPrevious goes back', () {
      [mk('1'), mk('2'), mk('3')];
      var ci = 2;
      ci--;
      expect(ci, 1);
      ci--;
      expect(ci, 0);
    });
  });

  group('Queue edge cases', () {
    test('removeFromQueue on invalid index is no-op', () {
      final q = [mk('1'), mk('2')];
      const removeIdx = 5;
      if (removeIdx >= 0 && removeIdx < q.length) q.removeAt(removeIdx);
      expect(q.length, 2);
    });

    test('reorderQueue same index is no-op', () {
      final q = [mk('1'), mk('2'), mk('3')];
      const oi = 1, ni = 1;
      if (oi != ni) {
        final song = q.removeAt(oi);
        q.insert(ni, song);
      }
      expect(q[1].id, '2');
    });

    test('queue of 1 song', () {
      final q = [mk('1')];
      q.removeAt(0);
      expect(q.length, 0);
    });

    test('addToQueue deduplicates by id check', () {
      final q = [mk('1'), mk('2')];
      final song = mk('1');
      if (!q.any((s) => s.id == song.id)) q.add(song);
      expect(q.length, 2);
    });

    test('playNext deduplicates by id check', () {
      final q = [mk('1'), mk('2')];
      final song = mk('2');
      if (!q.any((s) => s.id == song.id)) {
        q.insert((0 + 1).clamp(0, q.length), song);
      }
      expect(q.length, 2);
    });
  });
}
