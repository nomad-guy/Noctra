import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/resolvers/stream_resolver.dart';

void main() {
  group('AudioStreamInfo & AudioQualityTier', () {
    test('Hi-Res Lossless stream info formats correctly', () {
      final info = AudioStreamInfo.hiResFlac(
        url: 'https://audio-qobuz.com/track/123.flac',
        bitDepth: 24,
        sampleRate: 96000,
        bitrateKbps: 2304,
      );

      expect(info.isLossless, isTrue);
      expect(info.isSpatial, isFalse);
      expect(info.badgeLabel, 'HI-RES 24-BIT');
      expect(info.shortLabel, 'HI-RES');
      expect(info.detailsLabel, contains('FLAC'));
      expect(info.detailsLabel, contains('24-bit / 96 kHz'));
    });

    test('16-bit Lossless FLAC stream info formats correctly', () {
      final info = AudioStreamInfo.losslessFlac(
        url: 'https://sp-linear.tidal.com/track/456.flac',
        bitDepth: 16,
        sampleRate: 44100,
        bitrateKbps: 1411,
      );

      expect(info.isLossless, isTrue);
      expect(info.isSpatial, isFalse);
      expect(info.badgeLabel, 'LOSSLESS 16-BIT');
      expect(info.shortLabel, 'FLAC');
      expect(info.detailsLabel, contains('16-bit / 44.1 kHz'));
    });

    test('Dolby Atmos spatial stream info formats correctly', () {
      final info = AudioStreamInfo.dolbyAtmos(
        url: 'https://sp-linear.tidal.com/track/789_atmos.m4a',
        bitrateKbps: 768,
      );

      expect(info.isLossless, isFalse);
      expect(info.isSpatial, isTrue);
      expect(info.badgeLabel, 'DOLBY ATMOS');
      expect(info.shortLabel, 'ATMOS');
    });

    test('fromUrl parses FLAC and Atmos correctly', () {
      final flacInfo = AudioStreamInfo.fromUrl(
        'https://sp-linear.tidal.com/stream.flac?token=abc',
        sourceId: 'tidal_lossless',
      );
      expect(flacInfo.isLossless, isTrue);
      expect(flacInfo.shortLabel, 'FLAC');

      final hiResInfo = AudioStreamInfo.fromUrl(
        'https://audio-qobuz.com/stream.flac',
        sourceId: 'qobuz_hires',
        bitDepth: 24,
        sampleRate: 96000,
      );
      expect(hiResInfo.isLossless, isTrue);
      expect(hiResInfo.badgeLabel, 'HI-RES 24-BIT');

      final atmosInfo = AudioStreamInfo.fromUrl(
        'https://sp-linear.tidal.com/track_atmos.eac3',
        sourceId: 'tidal_atmos',
      );
      expect(atmosInfo.isSpatial, isTrue);
      expect(atmosInfo.badgeLabel, 'DOLBY ATMOS');
    });
  });

  group('OdesliSongLinkResolver', () {
    test('extractTidalId and extractQobuzId parse IDs properly', () {
      expect(
        OdesliSongLinkResolver.extractTidalId('https://tidal.com/browse/track/12345678'),
        '12345678',
      );
      expect(
        OdesliSongLinkResolver.extractQobuzId('https://open.qobuz.com/track/12345678'),
        '12345678',
      );
    });
  });

  group('TidalStreamResolver & QobuzStreamResolver', () {
    test('Resolvers instantiate with proper source priorities', () {
      final tidal = TidalStreamResolver();
      final qobuz = QobuzStreamResolver();

      expect(tidal.sourceId, 'tidal_flac');
      expect(qobuz.sourceId, 'qobuz_flac');
    });

    test('resolvers reject song with empty metadata without throwing', () async {
      final emptySong = Song(
        id: 'test_empty',
        title: '',
        artist: '',
        duration: Duration.zero,
      );

      final tidal = TidalStreamResolver();
      final qobuz = QobuzStreamResolver();

      final tidalRes = await tidal.resolveStreamUrl(emptySong);
      final qobuzRes = await qobuz.resolveStreamUrl(emptySong);

      expect(tidalRes, isNull);
      expect(qobuzRes, isNull);
    });
  });

  group('CompositeStreamResolver stream info caching', () {
    test('clearing cache removes stored audio stream info', () {
      CompositeStreamResolver.invalidateCache('song_abc');
      expect(CompositeStreamResolver.getAudioStreamInfo('song_abc'), isNull);
    });
  });
}
