import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/resolvers/track_matching_guard.dart';
import 'package:noctra/services/resolvers/stream_resolver.dart';
import 'package:noctra/services/audio/audio_player_service.dart';

class _MockThrowingResolver implements StreamResolver {
  final Object errorToThrow;
  int callCount = 0;
  _MockThrowingResolver(this.errorToThrow);

  @override
  String get sourceId => 'mock_throwing';

  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    callCount++;
    throw errorToThrow;
  }
}

class _MockNeverReachedResolver implements StreamResolver {
  int callCount = 0;

  @override
  String get sourceId => 'mock_never_reached';

  @override
  Future<bool> canResolve(Song song, {Duration? timeBudget}) async => true;

  @override
  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget}) async {
    callCount++;
    return 'https://aac.saavncdn.com/stream.mp4';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CompositeStreamResolver.setResolversForTesting(null);
    CompositeStreamResolver.clearCacheForTesting();
  });

  group('TrackMatchingGuard — Dangerous Cases & Precision Verification', () {
    const targetTitle = 'Starboy';
    const targetArtist = 'The Weeknd';
    const targetDuration = Duration(seconds: 230);

    test('Studio target vs Remix candidate -> REJECTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'Starboy (Kygo Remix)',
        candidateArtist: 'Kygo, The Weeknd',
        candidateDuration: const Duration(seconds: 235),
      );
      expect(safe, isFalse);
    });

    test('Studio target vs Live candidate -> REJECTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'Starboy (Live from Paris)',
        candidateArtist: 'The Weeknd',
        candidateDuration: const Duration(seconds: 240),
      );
      expect(safe, isFalse);
    });

    test('Studio target vs Instrumental candidate -> REJECTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'Starboy [Instrumental]',
        candidateArtist: 'Karaoke Beats',
        candidateDuration: targetDuration,
      );
      expect(safe, isFalse);
    });

    test('Studio target vs Slowed / Sped up candidate -> REJECTED', () {
      final slowedSafe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'Starboy (Slowed + Reverb)',
        candidateArtist: 'VibeStation',
        candidateDuration: const Duration(seconds: 270),
      );
      expect(slowedSafe, isFalse);

      final spedUpSafe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'Starboy (Sped Up)',
        candidateArtist: 'SpeedAudios',
        candidateDuration: const Duration(seconds: 190),
      );
      expect(spedUpSafe, isFalse);
    });

    test('Studio target vs Cover candidate -> REJECTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'Starboy - Acoustic Cover',
        candidateArtist: 'GuitarGuy',
        candidateDuration: targetDuration,
      );
      expect(safe, isFalse);
    });

    test('Target Remix vs Candidate Remix -> ACCEPTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: 'Starboy (Kygo Remix)',
        targetArtist: 'The Weeknd',
        targetDuration: const Duration(seconds: 235),
        candidateTitle: 'Starboy - Kygo Remix (Audio)',
        candidateArtist: 'The Weeknd',
        candidateDuration: const Duration(seconds: 235),
      );
      expect(safe, isTrue);
    });

    test('Official Audio / Music Video suffix does NOT reject matching song',
        () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle:
            'The Weeknd - Starboy (Official Music Video) ft. Daft Punk',
        candidateArtist: 'TheWeekndVEVO',
        candidateDuration: targetDuration,
      );
      expect(safe, isTrue);
    });

    test('Same title, completely different artist -> REJECTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: 'Hello',
        targetArtist: 'Adele',
        targetDuration: const Duration(seconds: 295),
        candidateTitle: 'Lionel Richie - Hello (Official Music Video)',
        candidateArtist: 'Lionel Richie',
        candidateDuration: const Duration(seconds: 290),
      );
      expect(safe, isFalse);
    });

    test('Primary artist matches even with guest features', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: 'Starboy',
        targetArtist: 'The Weeknd ft. Daft Punk',
        targetDuration: targetDuration,
        candidateTitle: 'Starboy (Official Audio)',
        candidateArtist: 'The Weeknd',
        candidateDuration: targetDuration,
      );
      expect(safe, isTrue);
    });

    test('Short preview clip (< 45s) -> REJECTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'Starboy',
        candidateArtist: 'The Weeknd',
        candidateDuration: const Duration(seconds: 30),
      );
      expect(safe, isFalse);
    });

    test('Duration deviation (> 60s / 35%) -> REJECTED', () {
      final safe = TrackMatchingGuard.isSafeMatch(
        targetTitle: targetTitle,
        targetArtist: targetArtist,
        targetDuration: targetDuration,
        candidateTitle: 'The Weeknd - Starboy Extended 10 Hour Loop',
        candidateArtist: 'The Weeknd',
        candidateDuration: const Duration(seconds: 1200),
      );
      expect(safe, isFalse);
    });
  });

  group('CompositeStreamResolver — Offline Fast-Fail & Host Security', () {
    test(
        'Offline SocketException immediately terminates resolver traversal without waiting for subsequent tiers',
        () async {
      final throwing =
          _MockThrowingResolver(const SocketException('Failed host lookup'));
      final neverReached = _MockNeverReachedResolver();

      CompositeStreamResolver.setResolversForTesting([throwing, neverReached]);

      final song = Song(
        id: 'offline-test',
        title: 'Offline Song',
        artist: 'Offline Artist',
        duration: const Duration(seconds: 200),
      );

      final result = await CompositeStreamResolver.resolve(song);
      expect(result, isNull);
      expect(throwing.callCount, 1);
      expect(neverReached.callCount, 0,
          reason: 'Must not attempt further tiers when offline');
    });

    test('DirectOpenStreamResolver accepts Jamendo hosts', () async {
      final directResolver = DirectOpenStreamResolver();
      final jamendoSong = Song(
        id: 'jam-1',
        title: 'Free Music',
        artist: 'Creative Commons',
        duration: const Duration(seconds: 180),
        streamUrl: 'https://mp3d.jamendo.com/download/track/12345/mp32/',
      );
      expect(await directResolver.canResolve(jamendoSong), isTrue);

      final jamendoCdnSong = Song(
        id: 'jam-2',
        title: 'Free Music 2',
        artist: 'Creative Commons',
        duration: const Duration(seconds: 180),
        streamUrl:
            'https://prod-1.storage.jamendocdn.com/stream/track/12345.mp3',
      );
      expect(await directResolver.canResolve(jamendoCdnSong), isTrue);
    });

    test('Cache invalidation removes cached resolution', () async {
      CompositeStreamResolver.invalidateCache('song-xyz');
      // Invalidation succeeds without exception
    });
  });

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
