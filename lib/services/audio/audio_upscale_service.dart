import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/noctra_logger.dart';
import 'parts/upscale_dsp_engine.dart';

export 'parts/upscale_dsp_engine.dart' show UpscaleResult;

class UpscaleProgress {
  final String stage;
  final double progress;
  final String message;

  const UpscaleProgress(this.stage, this.progress, this.message);
}

/// Message payload sent to the isolate. Isolates cannot send closures,
/// so the DSP work is triggered by this record.
class _IsolateRequest {
  final String inputPath;
  final String outputPath;
  final double strength;
  final int sampleRate;
  final int channels;
  final Float64List pcm;

  const _IsolateRequest({
    required this.inputPath,
    required this.outputPath,
    required this.strength,
    required this.sampleRate,
    required this.channels,
    required this.pcm,
  });
}

/// On-device audio upscaler service.
///
/// Pipeline: any input format → native decode (audio_decoder, all platforms)
/// → pure-Dart DSP enhancement in a background isolate (harmonic
/// reconstruction + band extension + soft limiting) → true lossless
/// 24-bit WAV output.
///
/// Honest scoping: this restores perceived brightness/air lost to lossy
/// compression; it cannot literally recreate information that was never
/// encoded. Output is lossless 24-bit WAV, not FLAC (no viable pure-Dart
/// FLAC encoder exists yet — intentional per no-fake-features rule).
class AudioUpscaleService {
  static final AudioUpscaleService _instance =
      AudioUpscaleService._internal();
  factory AudioUpscaleService() => _instance;
  AudioUpscaleService._internal();

  final _progressController =
      StreamController<UpscaleProgress>.broadcast();
  Stream<UpscaleProgress> get progressStream =>
      _progressController.stream;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Cache directory for upscaled outputs.
  Future<Directory> upscaleDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/NoctraUpscaled');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Returns true if a lossless upscaled file already exists for [songId].
  Future<String?> getCachedUpscalePath(String songId) async {
    final dir = await upscaleDirectory();
    final f = File('${dir.path}/${_safe(songId)}.wav');
    return f.existsSync() ? f.path : null;
  }

  /// Upscale [inputPath] (any format) to a lossless 24-bit WAV.
  Future<UpscaleResult?> upscale({
    required String inputPath,
    required String songId,
    double strength = 0.6,
  }) async {
    if (_isProcessing) {
      NoctraLogger.w('Upscale already in progress', null);
      return null;
    }
    if (inputPath.startsWith('http')) {
      NoctraLogger.w('Upscale requires a local file, got URL', null);
      return null;
    }
    final input = File(inputPath);
    if (!input.existsSync() || input.lengthSync() < 128) {
      NoctraLogger.w('Upscale input missing or too small', null);
      return null;
    }

    _isProcessing = true;
    try {
      _emit('decoding', 0.05, 'Decoding audio...');
      final wavPath = '${Directory.systemTemp.path}/'
          'noctra_upscale_${DateTime.now().millisecondsSinceEpoch}.wav';
      final info = await AudioDecoder.getAudioInfo(inputPath);
      // Decode to 24-bit WAV at native rate — extra bits preserve the
      // reconstruction headroom before the DSP stage.
      await AudioDecoder.convertToWav(
        inputPath,
        wavPath,
        sampleRate: info.sampleRate,
        channels: info.channels,
        bitDepth: 24,
      );

      _emit('analyzing', 0.25, 'Analyzing waveform...');
      final pcm = await _readWavPcm(File(wavPath));
      final sampleRate = await _readWavSampleRate(File(wavPath));
      final channels = await _readWavChannels(File(wavPath));
      File(wavPath).deleteSync();

      if (pcm.isEmpty) {
        NoctraLogger.w('Upscale: decoded PCM was empty', null);
        return null;
      }

      _emit('enhancing', 0.45, 'Reconstructing harmonics...');
      final dir = await upscaleDirectory();
      final outPath = '${dir.path}/${_safe(songId)}.wav';
      final result = await Isolate.run(() async {
        final req = _IsolateRequest(
          inputPath: inputPath,
          outputPath: outPath,
          strength: strength,
          sampleRate: sampleRate,
          channels: channels,
          pcm: pcm,
        );
        return _isolateEntryPoint(req);
      });

      _emit('done', 1.0, 'Upscaled file ready');
      return result;
    } catch (e) {
      NoctraLogger.e('Upscale failed', e);
      _emit('error', 1.0, 'Upscale failed: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Deletes all cached upscaled files (Settings maintenance action).
  Future<void> clearCache() async {
    final dir = await upscaleDirectory();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  void _emit(String stage, double p, String msg) {
    _progressController.add(UpscaleProgress(stage, p, msg));
  }

  void dispose() {
    _progressController.close();
  }
}

String _safe(String id) {
  final sb = StringBuffer();
  for (final c in id.codeUnits) {
    if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122)) {
      sb.writeCharCode(c);
    } else {
      sb.write('_');
    }
  }
  final s = sb.toString();
  return s.length > 80 ? s.substring(0, 80) : s;
}

/// Runs inside the spawned isolate.
Future<UpscaleResult> _isolateEntryPoint(_IsolateRequest req) async {
  return UpscaleDspEngine.process(
    pcm: req.pcm,
    sampleRate: req.sampleRate,
    channels: req.channels,
    outputFile: File(req.outputPath),
    strength: req.strength,
  );
}

/// Reads interleaved PCM from a 16/24-bit WAV into Float64List (-1.0 .. 1.0).
Future<Float64List> _readWavPcm(File f) async {
  final bytes = await f.readAsBytes();
  if (bytes.length < 44) return Float64List(0);
  final bd = ByteData.sublistView(bytes);
  final bitsPerSample = bd.getUint16(34, Endian.little);

  int dataOffset = 12;
  Uint8List data = bytes;
  while (dataOffset < bytes.length - 8) {
    final chunkId = String.fromCharCodes(
      bytes.sublist(dataOffset, dataOffset + 4),
    );
    final chunkSize = bd.getUint32(dataOffset + 4, Endian.little);
    if (chunkId == 'data') {
      data = bytes.sublist(
        dataOffset + 8,
        bytes.length < dataOffset + 8 + chunkSize
            ? bytes.length
            : dataOffset + 8 + chunkSize,
      );
      break;
    }
    dataOffset += 8 + chunkSize;
  }

  if (bitsPerSample == 24) {
    // 24-bit PCM: preserve full 24-bit dynamic range normalized to -1.0 .. 1.0.
    final n = data.length ~/ 3;
    final out = Float64List(n);
    for (int i = 0; i < n; i++) {
      int v = data[i * 3] | (data[i * 3 + 1] << 8) | (data[i * 3 + 2] << 16);
      if ((v & 0x800000) != 0) v |= 0xFF000000; // sign extend 24-bit signed int
      out[i] = v / 8388608.0;
    }
    return out;
  }
  // Default 16-bit path normalized to -1.0 .. 1.0.
  final n = data.length ~/ 2;
  final out = Float64List(n);
  final dbd = ByteData.sublistView(data);
  for (int i = 0; i < n; i++) {
    out[i] = dbd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

Future<int> _readWavSampleRate(File f) async {
  final b = await f.readAsBytes();
  if (b.length < 28) return 44100;
  final r = ByteData.sublistView(b).getUint32(24, Endian.little);
  return r > 0 ? r : 44100;
}

Future<int> _readWavChannels(File f) async {
  final b = await f.readAsBytes();
  if (b.length < 24) return 2;
  final c = ByteData.sublistView(b).getUint16(22, Endian.little);
  return c >= 1 && c <= 2 ? c : 2;
}
