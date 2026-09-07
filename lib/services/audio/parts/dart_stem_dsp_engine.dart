import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Cross-platform pure Dart DSP engine for audio stem separation.
/// Generates standard 16-bit stereo PCM WAV files for vocals, bass, drums, and other.
class DartStemDspEngine {
  DartStemDspEngine._();

  static Future<Map<String, dynamic>> separate({
    required String inputPath,
    required String outputDir,
    String model = 'light',
  }) async {
    final inputFile = File(inputPath);
    if (!inputFile.existsSync() || inputFile.lengthSync() < 128) {
      throw Exception('Input audio file does not exist or is too small');
    }

    final outDir = Directory(outputDir);
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final bytes = await inputFile.readAsBytes();
    final pcmData = _extractPcm(bytes);

    final pcm = pcmData.pcm;
    final sampleRate = pcmData.sampleRate;
    final channels = pcmData.channels;

    final separated = _processBands(pcm, sampleRate, channels, model);

    final stems = <String, dynamic>{};
    final durationSec = pcm.length / (sampleRate * channels);

    for (final entry in separated.entries) {
      final outFile = File('${outDir.path}/${entry.key}.wav');
      await _writeWav(outFile, entry.value, sampleRate, channels);
      stems[entry.key] = {
        'path': outFile.path,
        'size': outFile.lengthSync(),
      };
    }

    stems['duration'] = durationSec;
    stems['model'] = model;
    stems['sampleRate'] = sampleRate;
    stems['status'] = 'success';

    return stems;
  }

  static _ExtractedPcm _extractPcm(Uint8List bytes) {
    // Check for RIFF WAVE header
    if (bytes.length > 44 &&
        bytes[0] == 0x52 && // 'R'
        bytes[1] == 0x49 && // 'I'
        bytes[2] == 0x46 && // 'F'
        bytes[3] == 0x46) {
      try {
        final byteData = ByteData.sublistView(bytes);
        final channels = byteData.getUint16(22, Endian.little);
        final sampleRate = byteData.getUint32(24, Endian.little);
        final bitsPerSample = byteData.getUint16(34, Endian.little);

        // Find 'data' chunk
        int dataOffset = 12;
        while (dataOffset < bytes.length - 8) {
          final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
          final chunkSize = byteData.getUint32(dataOffset + 4, Endian.little);
          if (chunkId == 'data') {
            final pcmBytes = bytes.sublist(dataOffset + 8, min(bytes.length, dataOffset + 8 + chunkSize));
            return _ExtractedPcm(
              pcm: _bytesToShorts(pcmBytes, bitsPerSample),
              sampleRate: sampleRate > 0 ? sampleRate : 44100,
              channels: channels > 0 ? channels : 2,
            );
          }
          dataOffset += 8 + chunkSize;
        }
      } catch (_) {}
    }

    // Fallback: treat byte stream as interleaved 16-bit audio or synthesize PCM
    final pcm = _bytesToShorts(bytes, 16);
    return _ExtractedPcm(
      pcm: pcm,
      sampleRate: 44100,
      channels: 2,
    );
  }

  static Int16List _bytesToShorts(Uint8List bytes, int bitsPerSample) {
    final numSamples = bytes.length ~/ 2;
    if (numSamples == 0) {
      return Int16List(0);
    }
    final byteData = ByteData.sublistView(bytes);
    final shorts = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      shorts[i] = byteData.getInt16(i * 2, Endian.little);
    }
    return shorts;
  }

  static Map<String, Int16List> _processBands(
    Int16List pcm,
    int sampleRate,
    int channels,
    String model,
  ) {
    final len = pcm.length;
    final vocals = Int16List(len);
    final drums = Int16List(len);
    final bass = Int16List(len);
    final other = Int16List(len);

    if (len == 0) {
      return {'vocals': vocals, 'drums': drums, 'bass': bass, 'other': other};
    }

    final ch = max(1, channels);

    for (int c = 0; c < ch; c++) {
      final bLp = _BiquadFilter.lowPass(220.0, sampleRate.toDouble());
      final vBp = _BiquadFilter.bandPass(1850.0, 3100.0, sampleRate.toDouble());
      final dHp = _BiquadFilter.highPass(5500.0, sampleRate.toDouble());
      final dKp = _BiquadFilter.bandPass(110.0, 100.0, sampleRate.toDouble());

      for (int i = c; i < len; i += ch) {
        final sample = pcm[i].toDouble();

        final bVal = bLp.process(sample);
        final vVal = vBp.process(sample);
        final dVal = dHp.process(sample) * 0.75 + dKp.process(sample) * 0.55;

        final vClamped = vVal.clamp(-32768.0, 32767.0).toInt();
        final bClamped = bVal.clamp(-32768.0, 32767.0).toInt();
        final dClamped = dVal.clamp(-32768.0, 32767.0).toInt();

        vocals[i] = vClamped;
        bass[i] = bClamped;
        drums[i] = dClamped;

        final oVal = sample - (vClamped * 0.7 + bClamped * 0.8 + dClamped * 0.7);
        other[i] = oVal.clamp(-32768.0, 32767.0).toInt();
      }
    }

    if (model == 'karaoke') {
      final accompaniment = Int16List(len);
      for (int i = 0; i < len; i++) {
        final acc = pcm[i] - vocals[i];
        accompaniment[i] = acc.clamp(-32768, 32767);
      }
      return {
        'vocals': vocals,
        'accompaniment': accompaniment,
        'drums': drums,
        'bass': bass,
      };
    }

    return {
      'vocals': vocals,
      'drums': drums,
      'bass': bass,
      'other': other,
    };
  }

  static Future<void> _writeWav(
    File file,
    Int16List samples,
    int sampleRate,
    int channels,
  ) async {
    final byteLength = samples.length * 2;
    final totalLength = 44 + byteLength;
    final header = Uint8List(44);
    final bd = ByteData.sublistView(header);

    // RIFF chunk descriptor
    header[0] = 0x52; // 'R'
    header[1] = 0x49; // 'I'
    header[2] = 0x46; // 'F'
    header[3] = 0x46; // 'F'
    bd.setUint32(4, totalLength - 8, Endian.little);
    header[8] = 0x57; // 'W'
    header[9] = 0x41; // 'A'
    header[10] = 0x56; // 'V'
    header[11] = 0x45; // 'E'

    // fmt sub-chunk
    header[12] = 0x66; // 'f'
    header[13] = 0x6D; // 'm'
    header[14] = 0x74; // 't'
    header[15] = 0x20; // ' '
    bd.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    bd.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * channels * 2, Endian.little); // ByteRate
    bd.setUint16(32, channels * 2, Endian.little); // BlockAlign
    bd.setUint16(34, 16, Endian.little); // BitsPerSample

    // data sub-chunk
    header[36] = 0x64; // 'd'
    header[37] = 0x61; // 'a'
    header[38] = 0x74; // 't'
    header[39] = 0x61; // 'a'
    bd.setUint32(40, byteLength, Endian.little);

    final rawPcm = Uint8List(byteLength);
    final pcmBd = ByteData.sublistView(rawPcm);
    for (int i = 0; i < samples.length; i++) {
      pcmBd.setInt16(i * 2, samples[i], Endian.little);
    }

    final sink = file.openWrite();
    sink.add(header);
    sink.add(rawPcm);
    await sink.flush();
    await sink.close();
  }
}

class _ExtractedPcm {
  final Int16List pcm;
  final int sampleRate;
  final int channels;

  _ExtractedPcm({
    required this.pcm,
    required this.sampleRate,
    required this.channels,
  });
}

class _BiquadFilter {
  double a0 = 1.0, a1 = 0.0, a2 = 0.0, b0 = 1.0, b1 = 0.0, b2 = 0.0;
  double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;

  _BiquadFilter();

  factory _BiquadFilter.lowPass(double cutoff, double sampleRate) {
    final f = _BiquadFilter();
    final w0 = 2 * pi * (cutoff / sampleRate);
    final cosW0 = cos(w0);
    final alpha = sin(w0) / (2 * 0.7071);

    f.b0 = (1 - cosW0) / 2;
    f.b1 = 1 - cosW0;
    f.b2 = (1 - cosW0) / 2;
    f.a0 = 1 + alpha;
    f.a1 = -2 * cosW0;
    f.a2 = 1 - alpha;
    return f;
  }

  factory _BiquadFilter.highPass(double cutoff, double sampleRate) {
    final f = _BiquadFilter();
    final w0 = 2 * pi * (cutoff / sampleRate);
    final cosW0 = cos(w0);
    final alpha = sin(w0) / (2 * 0.7071);

    f.b0 = (1 + cosW0) / 2;
    f.b1 = -(1 + cosW0);
    f.b2 = (1 + cosW0) / 2;
    f.a0 = 1 + alpha;
    f.a1 = -2 * cosW0;
    f.a2 = 1 - alpha;
    return f;
  }

  factory _BiquadFilter.bandPass(double centerFreq, double bandwidth, double sampleRate) {
    final f = _BiquadFilter();
    final w0 = 2 * pi * (centerFreq / sampleRate);
    final q = centerFreq / max(10.0, bandwidth);
    final alpha = sin(w0) / (2 * max(0.1, q));

    f.b0 = alpha;
    f.b1 = 0;
    f.b2 = -alpha;
    f.a0 = 1 + alpha;
    f.a1 = -2 * cos(w0);
    f.a2 = 1 - alpha;
    return f;
  }

  double process(double input) {
    final y = (b0 / a0) * input + (b1 / a0) * x1 + (b2 / a0) * x2 - (a1 / a0) * y1 - (a2 / a0) * y2;
    x2 = x1;
    x1 = input;
    y2 = y1;
    y1 = y;
    return y;
  }
}
