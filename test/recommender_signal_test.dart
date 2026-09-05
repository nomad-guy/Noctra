import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/data/repositories/music_repository.dart';
import 'package:noctra/data/sources/noctra_local_database.dart';
import 'package:noctra/services/ai/candidate_retrieval_service.dart';
import 'package:noctra/services/ai/implicit_signal_tracker.dart';
import 'package:noctra/services/audio/audio_player_service.dart';
import 'package:noctra/services/metadata/deezer_audio_features_service.dart';

/// Phase 23 regression tests.
///
/// 1. End-of-song implicit signals must fire ONCE per track. Natural
///    completion recorded the signal and then called the skip path, which
///    re-read the never-cleared song-start timestamp and recorded the SAME
///    finished track a second time (double taste-vector update, double
///    neural train, double knowledge-graph reinforcement).
/// 2. Taste-vector updates must move for songs WITHOUT a real embedding
///    (they used to feed the neutral 0.5 fill → silent no-op learning).
/// 3. The AI feed's audio-feature lookup must be bounded so a large pool
///    cannot starve the caller's time budget.
Song _song(String id, String title, {int seconds = 180}) => Song(
      id: id,
      title: title,
      artist: 'Artist',
      duration: Duration(seconds: seconds),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NoctraLocalDatabase().debugResetForTest();
    await NoctraLocalDatabase().init();
    MusicRepository.debugResetSingleton();
    MusicRepository().debugResetForTest();
    await MusicRepository().init();
    ImplicitSignalTracker.debugResetSignalCounters();
    AudioPlayerService.instance.clearQueue();
  });

  group('end-of-song implicit signal fires once per track', () {
    test('natural completion + internal skip records exactly one signal',
        () async {
      final player = AudioPlayerService.instance;
      final a = _song('sig_a', 'Track A', seconds: 200);
      final b = _song('sig_b', 'Track B');

      player.debugSetPlaybackPosition(queue: [a, b], index: 0, currentSong: a);
      // Simulate the track having played for 190 of 200 seconds.
      player.debugSetSongStartTimestamp(
          DateTime.now().subtract(const Duration(seconds: 190)));

      // Natural completion → records the signal, consumes the timestamp,
      // then auto-advances through the same skip path used by manual next.
      await player.debugSimulateNaturalSongCompletion();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Pre-fix this was 2: the completion handler AND the subsequent
      // _skipNextInternal both saw the stale start timestamp.
      expect(ImplicitSignalTracker.debugPlaybackEndSignals, 1,
          reason: 'a finished track must signal its end exactly once');
      expect(player.currentIndex, 1,
          reason: 'completion should still advance to the next track');
    });

    test('a manual mid-song skip records exactly one signal', () async {
      final player = AudioPlayerService.instance;
      final a = _song('sig_c', 'Track C', seconds: 200);
      final b = _song('sig_d', 'Track D');
      final c = _song('sig_e', 'Track E');

      // Three tracks, skipping twice stays mid-queue (no autoplay-radio
      // network path).
      player.debugSetPlaybackPosition(
          queue: [a, b, c], index: 0, currentSong: a);
      player.debugSetSongStartTimestamp(
          DateTime.now().subtract(const Duration(seconds: 100)));

      // User presses Next mid-song: one signal for the skipped track, and
      // the timestamp is consumed so nothing else can re-signal it.
      await player.skipNext();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ImplicitSignalTracker.debugPlaybackEndSignals, 1,
          reason: 'skipping a partially played track signals once, not twice');

      await player.skipNext();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ImplicitSignalTracker.debugPlaybackEndSignals, 2,
          reason: 'each skipped track signals exactly once as it is left');
    });
  });

  group('taste vector learning without real embeddings', () {
    test('updating from a plain song moves the vector (no silent no-op)',
        () async {
      final repo = MusicRepository();
      final before = List<double>.from(repo.userTasteVector);
      // Neutral default → expect a pure-neutral update to be a no-op.
      final neutral = _song('neu', 'Anything at all');
      repo.updateTasteVector(neutral, 'complete_listen');
      expect(repo.userTasteVector, before,
          reason: 'neutral embedding must not move the vector');

      // A song whose TEXT clearly implies a vibe ('night ... synth') must
      // move the matching axes even though it carries no real embedding.
      final texty = _song('texty', 'Midnight synth night drive');
      repo.updateTasteVector(texty, 'complete_listen');
      final after = repo.userTasteVector;
      final moved = List.generate(after.length,
          (i) => (after[i] - before[i]).abs()).reduce((x, y) => x + y);
      expect(moved, greaterThan(0.0001),
          reason: 'keyword-derived embedding must influence the vector');
    });
  });

  group('bounded audio-feature lookup in the AI feed', () {
    test('large pools trigger at most the lookup cap of network fetches',
        () async {
      var fetches = 0;
      final pool = [
        for (var i = 0; i < 80; i++)
          _song('pool_$i', 'Song Number $i', seconds: 200),
      ];
      final results = await CandidateRetrievalService.curatePersonalizedFeed(
        targetCount: 12,
        poolOverride: pool,
        featureFetcher: (title, artist) async {
          fetches++;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return AudioFeatures.defaults;
        },
      );
      expect(fetches,
          CandidateRetrievalService.audioFeatureLookupCap,
          reason: 'never fetch audio features for the whole ~100-item pool');
      expect(results, hasLength(12));
      expect(results.first['song'], isA<Song>());
    });

    test('slow audio-feature lookups cannot exceed the per-call budget',
        () async {
      var fetches = 0;
      final pool = [
        for (var i = 0; i < 12; i++)
          _song('slow_$i', 'Slow Song $i', seconds: 200),
      ];
      final sw = Stopwatch()..start();
      await CandidateRetrievalService.curatePersonalizedFeed(
        targetCount: 10,
        poolOverride: pool,
        featureFetcher: (title, artist) async {
          fetches++;
          // Far slower than the service's 600ms per-lookup timeout.
          await Future<void>.delayed(const Duration(seconds: 3));
          return AudioFeatures.defaults;
        },
      );
      sw.stop();
      expect(fetches, pool.length,
          reason: 'a small pool fetches for every member only');
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'the phase must degrade to defaults instead of waiting');
    });
  });
}
