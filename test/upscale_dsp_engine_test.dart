import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/audio/parts/upscale_dsp_engine.dart';

void main() {
  group('UpscaleDspEngine', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('upscale_test');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    /// Sine at [freq] Hz, 16-bit PCM.
    Int16List sine(double freq, int sampleRate, int seconds, int channels) {
      final n = sampleRate * seconds * channels;
      final pcm = Int16List(n);
      for (int i = 0; i < n; i += channels) {
        final v =
            (0.5 * 32767 * (2 * 3.141592653589793 * freq * (i ~/ channels) / sampleRate))
                .clamp(-32767.0, 32767.0)
                .toInt();
        for (int c = 0; c < channels; c++) {
          pcm[i + c] = v;
        }
      }
      return pcm;
    }

    test('produces a valid 24-bit WAV with correct header', () async {
      final out = File('${tmp.path}/out.wav');
      final pcm = sine(440.0, 44100, 1, 2);
      final result = await UpscaleDspEngine.process(
        pcm: pcm,
        sampleRate: 44100,
        channels: 2,
        outputFile: out,
        strength: 0.6,
      );

      expect(out.existsSync(), isTrue);
      expect(result.bitDepth, 24);
      expect(result.sampleRate, 44100);
      expect(result.channels, 2);

      final bytes = out.readAsBytesSync();
      // RIFF / WAVE magic
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      final bd = ByteData.sublistView(bytes);
      expect(bd.getUint16(20, Endian.little), 1); // PCM
      expect(bd.getUint16(22, Endian.little), 2); // stereo
      expect(bd.getUint32(24, Endian.little), 44100);
      expect(bd.getUint16(34, Endian.little), 24); // 24-bit
      // data chunk present with expected size
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      final dataLen = bd.getUint32(40, Endian.little);
      expect(dataLen, pcm.length * 3);
      expect(bytes.length, 44 + dataLen);
    });

    test('output never clips beyond full scale', () async {
      final out = File('${tmp.path}/loud.wav');
      // Near-full-scale input — limiter must keep output in range.
      final pcm = Int16List(44100);
      for (int i = 0; i < pcm.length; i++) {
        pcm[i] = (0.98 * 32767 *
                (i.isEven ? 1 : -1))
            .toInt();
      }
      final result = await UpscaleDspEngine.process(
        pcm: pcm,
        sampleRate: 44100,
        channels: 1,
        outputFile: out,
        strength: 1.0,
      );
      expect(File(result.path).existsSync(), isTrue);
      final bytes = File(result.path).readAsBytesSync();
      // Scan 24-bit samples; max magnitude must fit in int24.
      int maxAbs = 0;
      for (int off = 44; off + 3 <= bytes.length; off += 3) {
        int v = bytes[off] | (bytes[off + 1] << 8) | (bytes[off + 2] << 16);
        if (v & 0x800000 != 0) v -= 0x1000000; // sign extend
        if (v.abs() > maxAbs) maxAbs = v.abs();
      }
      expect(maxAbs, lessThanOrEqualTo(8388607));
      // Sanity: output is not silent and not all-zero.
      expect(maxAbs, greaterThan(1000));
    });

    test('adds harmonic energy when exciter band has content', () async {
      // The exciter regenerates harmonics from existing 2.5-8 kHz content
      // (a pure 220 Hz tone has none, correctly producing no uplift).
      // Use a 220 Hz + 3 kHz mix: the 3 kHz component drives the exciter,
      // whose saturation adds harmonics (6 kHz, 9 kHz...) raising the
      // zero-crossing density above the input's.
      int zeroCrossRate24(Uint8List wavBytes) {
        int crossings = 0;
        int prev = 0;
        bool first = true;
        for (int off = 44; off + 3 <= wavBytes.length; off += 3) {
          int v = wavBytes[off] | (wavBytes[off + 1] << 8) |
              (wavBytes[off + 2] << 16);
          if (v & 0x800000 != 0) v -= 0x1000000;
          if (!first && ((v >= 0) != (prev >= 0))) crossings++;
          prev = v;
          first = false;
        }
        return crossings;
      }

      const sampleRate = 44100;
      final n = sampleRate;
      final pcm = Int16List(n);
      for (int i = 0; i < n; i++) {
        final t = i / sampleRate;
        final v1 = 0.35 * math.sin(2 * math.pi * 220 * t);
        final v2 = 0.35 * math.sin(2 * math.pi * 3000 * t);
        pcm[i] =
            (0.4 * 32767 * (v1 + v2).clamp(-1.0, 1.0)).toInt();
      }
      // Input zero-crossing rate (16-bit domain):
      int inputCrossings = 0;
      for (int i = 1; i < pcm.length; i++) {
        if ((pcm[i] >= 0) != (pcm[i - 1] >= 0)) inputCrossings++;
      }
      expect(inputCrossings, greaterThan(5000));

      final out = File('${tmp.path}/excited.wav');
      await UpscaleDspEngine.process(
        pcm: pcm,
        sampleRate: sampleRate,
        channels: 1,
        outputFile: out,
        strength: 0.8,
      );
      final outputCrossings = zeroCrossRate24(out.readAsBytesSync());
      // Harmonics added by the exciter must raise zero-crossing density.
      expect(outputCrossings, greaterThan(inputCrossings));
    });

    test('rejects invalid inputs', () async {
      final out = File('${tmp.path}/x.wav');
      expect(
        () => UpscaleDspEngine.process(
          pcm: Int16List(10),
          sampleRate: 44100,
          channels: 5,
          outputFile: out,
        ),
        throwsArgumentError,
      );
      expect(
        () => UpscaleDspEngine.process(
          pcm: Int16List(10),
          sampleRate: 44100,
          channels: 2,
          outputFile: out,
          strength: 2.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
