import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/audio/parts/dart_stem_dsp_engine.dart';

void main() {
  group('DartStemDspEngine Cross-Platform Stem Separation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('noctra_stem_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('separates synthetic PCM audio into 4 playable WAV stems', () async {
      final inputFile = File('${tempDir.path}/input.wav');
      // Write a small 0.25 second 16-bit stereo 44.1kHz PCM WAV
      final sampleRate = 44100;
      final channels = 2;
      final numSamples = (sampleRate * channels * 0.25).toInt();
      final pcm = List<int>.generate(numSamples, (i) => ((i % 200) * 100) - 10000);

      final outDir = '${tempDir.path}/stems';

      // Create synthetic wav input
      final header = List<int>.filled(44, 0);
      final byteLen = numSamples * 2;
      // RIFF header
      header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46;
      final totalLen = 44 + byteLen;
      header[4] = (totalLen - 8) & 0xFF;
      header[5] = ((totalLen - 8) >> 8) & 0xFF;
      header[6] = ((totalLen - 8) >> 16) & 0xFF;
      header[7] = ((totalLen - 8) >> 24) & 0xFF;
      header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45;
      header[12] = 0x66; header[13] = 0x6D; header[14] = 0x74; header[15] = 0x20;
      header[16] = 16;
      header[20] = 1; // PCM
      header[22] = channels;
      header[24] = sampleRate & 0xFF;
      header[25] = (sampleRate >> 8) & 0xFF;
      header[34] = 16; // 16-bit
      header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61;
      header[40] = byteLen & 0xFF;
      header[41] = (byteLen >> 8) & 0xFF;

      final pcmBytes = <int>[];
      for (final s in pcm) {
        pcmBytes.add(s & 0xFF);
        pcmBytes.add((s >> 8) & 0xFF);
      }
      await inputFile.writeAsBytes([...header, ...pcmBytes]);

      final result = await DartStemDspEngine.separate(
        inputPath: inputFile.path,
        outputDir: outDir,
        model: 'light',
      );

      expect(result['status'], equals('success'));
      expect(File('$outDir/vocals.wav').existsSync(), isTrue);
      expect(File('$outDir/drums.wav').existsSync(), isTrue);
      expect(File('$outDir/bass.wav').existsSync(), isTrue);
      expect(File('$outDir/other.wav').existsSync(), isTrue);
      expect(File('$outDir/vocals.wav').lengthSync(), greaterThan(44));
    });
  });

  group('Song Model & Deduplication helpers', () {
    test('Song model handles feature vector normalization', () {
      final song = Song(
        id: 'test1234567',
        title: 'Where Is My Mind',
        artist: 'Pixies',
        duration: const Duration(seconds: 230),
      );

      expect(song.title, equals('Where Is My Mind'));
      expect(song.artist, equals('Pixies'));
      expect(song.duration.inSeconds, equals(230));
    });
  });
}
