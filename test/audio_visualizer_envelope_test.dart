import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/audio/audio_visualizer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioVisualizerService envelope demux', () {
    test('waveform envelope populates waveform stream', () async {
      final svc = AudioVisualizerService();
      final received = <List<double>>[];
      final sub = svc.waveformStream.listen(received.add);
      final ok = svc.handleEnvelope({
        'type': 'waveform',
        'data': List<double>.generate(64, (i) => i / 64.0),
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(ok, isTrue);
      expect(received, isNotEmpty);
      expect(received.first.length, 32);
    });

    test('fft envelope populates fft stream', () async {
      final svc = AudioVisualizerService();
      final received = <List<double>>[];
      final sub = svc.fftStream.listen(received.add);
      final ok = svc.handleEnvelope({
        'type': 'fft',
        'data': List<double>.generate(64, (i) => (i / 64.0).abs()),
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(ok, isTrue);
      expect(received, isNotEmpty);
      expect(received.first.length, 32);
    });

    test('non-envelope payload returns false', () {
      final svc = AudioVisualizerService();
      // Legacy flat list — used to be silently dropped, must still be.
      expect(svc.handleEnvelope([0.1, 0.2, 0.3]), isFalse);
      // Random object — must not crash.
      expect(svc.handleEnvelope('not a map'), isFalse);
      expect(svc.handleEnvelope(null), isFalse);
    });

    test('unknown envelope type returns false', () {
      final svc = AudioVisualizerService();
      expect(
        svc.handleEnvelope({
          'type': 'unknown',
          'data': [1.0, 2.0]
        }),
        isFalse,
      );
    });

    test('empty data array returns false', () {
      final svc = AudioVisualizerService();
      expect(svc.handleEnvelope({'type': 'fft', 'data': <double>[]}), isFalse);
    });

    test('latestFft accessor still exposed and length 32', () {
      final svc = AudioVisualizerService();
      expect(svc.latestFft, isNotNull);
      expect(svc.latestFft.length, 32);
      expect(svc.latestWaveform.length, 32);
    });
  });
}
