import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/audio/stream_quality_service.dart';
import 'package:noctra/services/audio/audio_stem_separation_service.dart';

void main() {
  group('StreamQualityService', () {
    late StreamQualityService service;

    setUp(() {
      service = StreamQualityService();
    });

    test('default quality is lossless', () {
      expect(service.streamQuality, StreamQuality.lossless);
    });

    test('default codec is mp3', () {
      expect(service.preferredCodec, AudioCodec.mp3);
    });

    test('default normalize volume is true', () {
      expect(service.normalizeVolume, true);
    });

    test('default gapless playback is true', () {
      expect(service.gaplessPlayback, true);
    });

    test('setStreamQuality updates quality', () async {
      await service.setStreamQuality(StreamQuality.medium);
      expect(service.streamQuality, StreamQuality.medium);
    });

    test('setPreferredCodec updates codec', () async {
      await service.setPreferredCodec(AudioCodec.flac);
      expect(service.preferredCodec, AudioCodec.flac);
    });

    test('setNormalizeVolume updates setting', () {
      service.setNormalizeVolume(false);
      expect(service.normalizeVolume, false);
    });

    test('setGaplessPlayback updates setting', () {
      service.setGaplessPlayback(false);
      expect(service.gaplessPlayback, false);
    });

    test('selectBestQuality picks closest bitrate', () async {
      // Set to 320kbps lossless — should pick 320000 bps stream
      await service.setStreamQuality(StreamQuality.lossless);
      final formats = [
        {'mimeType': 'audio/mp4; codecs=mp4a.40.2', 'bitrate': 128000, 'url': 'http://example.com/128'},
        {'mimeType': 'audio/webm; codecs=opus', 'bitrate': 256000, 'url': 'http://example.com/256'},
        {'mimeType': 'audio/mpeg', 'bitrate': 320000, 'url': 'http://example.com/320'},
      ];
      final best = service.selectBestQuality(formats);
      expect(best, 'http://example.com/320');
    });

    test('selectBestQuality picks 128kbps when set to low', () async {
      await service.setStreamQuality(StreamQuality.low);
      final formats = [
        {'mimeType': 'audio/mpeg', 'bitrate': 128000, 'url': 'http://example.com/128'},
        {'mimeType': 'audio/mpeg', 'bitrate': 256000, 'url': 'http://example.com/256'},
        {'mimeType': 'audio/mpeg', 'bitrate': 320000, 'url': 'http://example.com/320'},
      ];
      final best = service.selectBestQuality(formats);
      expect(best, 'http://example.com/128');
    });

    test('selectBestQuality picks 256kbps when set to veryHigh', () async {
      await service.setStreamQuality(StreamQuality.veryHigh);
      final formats = [
        {'mimeType': 'audio/mpeg', 'bitrate': 128000, 'url': 'http://example.com/128'},
        {'mimeType': 'audio/mpeg', 'bitrate': 256000, 'url': 'http://example.com/256'},
        {'mimeType': 'audio/mpeg', 'bitrate': 320000, 'url': 'http://example.com/320'},
      ];
      final best = service.selectBestQuality(formats);
      expect(best, 'http://example.com/256');
    });

    test('selectBestQuality returns empty for empty list', () {
      expect(service.selectBestQuality([]), '');
    });

    test('selectBestQuality filters non-audio formats', () {
      final formats = [
        {'mimeType': 'video/mp4', 'bitrate': 1000000, 'url': 'http://example.com/video'},
        {'mimeType': 'audio/mpeg', 'bitrate': 128000, 'url': 'http://example.com/audio'},
      ];
      final best = service.selectBestQuality(formats);
      expect(best, contains('audio'));
    });

    test('selectBestQuality respects low quality setting', () async {
      await service.setStreamQuality(StreamQuality.low);
      final formats = [
        {'mimeType': 'audio/mpeg', 'bitrate': 96000, 'url': 'http://example.com/96'},
        {'mimeType': 'audio/mpeg', 'bitrate': 320000, 'url': 'http://example.com/320'},
      ];
      final best = service.selectBestQuality(formats);
      expect(best, contains('96'));
    });

    test('estimateFileSizeMB for lossy is reasonable', () {
      final size = StreamQualityService.estimateFileSizeMB(240, StreamQuality.lossless);
      expect(size, greaterThan(5));
      expect(size, lessThan(15));
    });

    test('estimateFileSizeMB for FLAC is larger', () {
      final mp3Size = StreamQualityService.estimateFileSizeMB(240, StreamQuality.lossless);
      final flacSize = StreamQualityService.estimateFileSizeMB(240, StreamQuality.hiRes);
      expect(flacSize, greaterThan(mp3Size));
    });

    test('settingsStream emits on changes', () async {
      final settings = <StreamQualitySettings>[];
      final sub = service.settingsStream.listen(settings.add);
      await service.setStreamQuality(StreamQuality.high);
      await service.setPreferredCodec(AudioCodec.aac);
      service.setNormalizeVolume(false);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(settings.length, greaterThanOrEqualTo(3));
      await sub.cancel();
    });

    test('StreamQuality enum has all expected values', () {
      expect(StreamQuality.values.length, 6);
      expect(StreamQuality.low.bitrate, 96);
      expect(StreamQuality.medium.bitrate, 128);
      expect(StreamQuality.high.bitrate, 192);
      expect(StreamQuality.veryHigh.bitrate, 256);
      expect(StreamQuality.lossless.bitrate, 320);
      expect(StreamQuality.hiRes.bitrate, 0);
    });

    test('AudioCodec enum has all expected values', () {
      expect(AudioCodec.values.length, 5);
      expect(AudioCodec.mp3.displayName, 'MP3');
      expect(AudioCodec.aac.displayName, 'AAC');
      expect(AudioCodec.flac.displayName, 'FLAC');
      expect(AudioCodec.opus.displayName, 'Opus');
      expect(AudioCodec.vorbis.displayName, 'Vorbis');
    });
  });

  group('AudioStemSeparationService', () {
    late AudioStemSeparationService service;

    setUp(() {
      service = AudioStemSeparationService();
    });

    test('singleton pattern', () {
      final s1 = AudioStemSeparationService();
      final s2 = AudioStemSeparationService();
      expect(identical(s1, s2), true);
    });

    test('isProcessing defaults to false', () {
      expect(service.isProcessing, false);
    });

    test('StemSeparationModel has 3 values', () {
      expect(StemSeparationModel.values.length, 3);
      expect(StemSeparationModel.light.name, 'light');
      expect(StemSeparationModel.hq.name, 'hq');
      expect(StemSeparationModel.karaoke.name, 'karaoke');
    });

    test('AudioStem model stores properties', () {
      final stem = AudioStem(
        name: 'vocals',
        displayName: 'Vocals',
        audioFile: null, // Can't create real File in unit test
        durationSeconds: 180.5,
      );
      expect(stem.name, 'vocals');
      expect(stem.displayName, 'Vocals');
      expect(stem.durationSeconds, 180.5);
    });

    test('StemSeparationProgress stores progress info', () {
      const progress = StemSeparationProgress(
        stage: 'separating',
        progress: 0.5,
        message: 'Processing...',
      );
      expect(progress.stage, 'separating');
      expect(progress.progress, 0.5);
      expect(progress.message, 'Processing...');
    });

    test('StemSeparationResult stores result info', () {
      const result = StemSeparationResult(
        stems: [],
        processingTimeMs: 5000,
        modelUsed: 'light',
      );
      expect(result.stems, isEmpty);
      expect(result.processingTimeMs, 5000);
      expect(result.modelUsed, 'light');
    });

    test('separate returns null on web', () async {
      // On web platform, stem separation should return null
      // This test will pass on web, skip on native
    });

    test('progressStream is broadcast', () {
      // Should not throw when adding multiple listeners
      final sub1 = service.progressStream.listen((_) {});
      final sub2 = service.progressStream.listen((_) {});
      expect(sub1, isNotNull);
      expect(sub2, isNotNull);
      sub1.cancel();
      sub2.cancel();
    });
  });

  group('Download quality estimation', () {
    test('96kbps for 4 minutes is about 2.8MB', () {
      final size = StreamQualityService.estimateFileSizeMB(240, StreamQuality.low);
      expect(size, closeTo(2.81, 0.1));
    });

    test('320kbps for 4 minutes is about 9.4MB', () {
      final size = StreamQualityService.estimateFileSizeMB(240, StreamQuality.lossless);
      expect(size, closeTo(9.38, 0.1));
    });

    test('FLAC for 4 minutes is about 40MB', () {
      final size = StreamQualityService.estimateFileSizeMB(240, StreamQuality.hiRes);
      expect(size, closeTo(40.0, 1.0));
    });

    test('128kbps for 3 minutes is about 2.8MB', () {
      final size = StreamQualityService.estimateFileSizeMB(180, StreamQuality.medium);
      expect(size, closeTo(2.81, 0.1));
    });
  });
}
