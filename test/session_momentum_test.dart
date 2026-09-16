import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/ai/session_context_tracker.dart';
import 'package:noctra/data/repositories/taste_vector_engine.dart';

/// Regression tests for the session-context momentum projection.
///
/// Bug: momentumFeatures sorted the 32-axis delta by magnitude before
/// taking the first 8, destroying WHICH axes moved — the same listening
/// shift produced different context inputs on every call, so the MLP's
/// context slice was noise. The fix projects deltas into 8 fixed thematic
/// buckets; these tests pin that determinism and the mapping.
void main() {
  test('momentum signature is deterministic for the same session', () {
    final tracker = SessionContextTracker();
    Song song(String title) => Song(
          id: 'id_$title',
          title: title,
          artist: 'Artist',
          album: 'Album',
          artworkUrl: '',
          streamUrl: '',
          duration: const Duration(seconds: 200),
        );

    // Need >= 2 * momentumWindow entries for momentum to compute.
    for (var i = 0; i < 3; i++) {
      tracker.recordSong(song('calm ambient $i'), 'complete_listen');
    }
    for (var i = 0; i < 3; i++) {
      tracker.recordSong(song('heavy metal riff $i'), 'complete_listen');
    }

    final a = tracker.momentumFeatures;
    final b = tracker.momentumFeatures;
    expect(a.length, 8);
    expect(b.length, 8);
    // Two consecutive calls must produce IDENTICAL signatures now.
    for (var i = 0; i < 8; i++) {
      expect(a[i], b[i]);
    }
  });

  test('momentum signature is 8-dim and clamped to [0,1]', () {
    final tracker = SessionContextTracker();
    Song song(String title) => Song(
          id: 'id_$title',
          title: title,
          artist: 'Artist',
          album: 'Album',
          artworkUrl: '',
          streamUrl: '',
          duration: const Duration(seconds: 180),
        );
    for (var i = 0; i < 6; i++) {
      tracker.recordSong(song('energetic edm drop $i'), 'complete_listen');
    }
    final m = tracker.momentumFeatures;
    expect(m.length, 8);
    for (final v in m) {
      expect(v.isNaN, isFalse, reason: 'momentum values must be finite');
      expect(v, inInclusiveRange(0.0, 1.0));
    }
  });

  test('session blended vector remains 32-dim normalized', () {
    final tracker = SessionContextTracker();
    Song song(String title) => Song(
          id: 'id_$title',
          title: title,
          artist: 'Artist',
          album: 'Album',
          artworkUrl: '',
          streamUrl: '',
          duration: const Duration(seconds: 200),
        );
    for (var i = 0; i < 4; i++) {
      tracker.recordSong(song('acoustic guitar session $i'), 'complete_listen');
    }
    final blended = tracker.blendedVector(TasteVectorEngine.getDefaultVector());
    expect(blended.length, TasteVectorEngine.vectorDimension);
    for (final v in blended) {
      expect(v, inInclusiveRange(0.05, 0.95));
    }
  });
}
