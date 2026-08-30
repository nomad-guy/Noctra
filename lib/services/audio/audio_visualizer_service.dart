import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'audio_player_service.dart';

class AudioVisualizerService {
  static final AudioVisualizerService _instance = AudioVisualizerService._internal();
  factory AudioVisualizerService() => _instance;

  static const _eventChannel = EventChannel('com.noctra.app/audio_visualizer');
  StreamSubscription? _subscription;
  Timer? _fallbackTicker;
  int? _currentSessionId;
  int _lastHardwarePacketMs = 0;

  final _fftController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get fftStream => _fftController.stream;

  List<double> _latestFft = List.filled(32, 0.2);
  List<double> get latestFft => List.unmodifiable(_latestFft);

  AudioVisualizerService._internal() {
    _init();
  }

  void _init() {
    if (!kIsWeb) {
      try {
        final playerService = AudioPlayerService();
        final initialSessionId = playerService.player.androidAudioSessionId;
        if (initialSessionId != null && initialSessionId > 0) {
          _startListening(initialSessionId);
        }
        playerService.player.androidAudioSessionIdStream.listen((sessionId) {
          if (sessionId != null && sessionId > 0 && sessionId != _currentSessionId) {
            _startListening(sessionId);
          }
        });
      } catch (_) {}
    }
    _startFallbackLoop();
  }

  void _startListening(int sessionId) {
    _currentSessionId = sessionId;
    _subscription?.cancel();
    try {
      _subscription = _eventChannel.receiveBroadcastStream({'sessionId': sessionId}).listen(
        (data) {
          if (data is List && data.isNotEmpty) {
            _lastHardwarePacketMs = DateTime.now().millisecondsSinceEpoch;
            final parsed = data.map((e) => (e as num).toDouble()).toList();
            final List<double> bins = List.filled(32, 0.0);
            for (int i = 0; i < 32; i++) {
              final idx = (i * parsed.length) ~/ 32;
              bins[i] = parsed[idx.clamp(0, parsed.length - 1)];
            }
            _latestFft = bins;
            _fftController.add(_latestFft);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _startFallbackLoop() {
    _fallbackTicker?.cancel();
    _fallbackTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastHardwarePacketMs > 150) {
        final t = now / 1000.0;
        final isPlaying = AudioPlayerService().player.playing;
        final List<double> bins = List.filled(32, 0.0);
        for (int i = 0; i < 32; i++) {
          if (isPlaying) {
            final freq1 = (i + 1) * 1.85;
            final freq2 = (i + 1) * 0.95;
            final w1 = sin(t * freq1 + (i * 0.45)) * 0.40 + 0.50;
            final w2 = cos(t * freq2 + (i * 0.25)) * 0.30 + 0.50;
            final sub = (sin(t * 8.0) * 0.25 + 0.75);
            bins[i] = ((w1 * 0.6 + w2 * 0.4) * sub).clamp(0.10, 0.98);
          } else {
            bins[i] = max(0.04, _latestFft[i] * 0.90);
          }
        }
        _latestFft = bins;
        _fftController.add(_latestFft);
      }
    });
  }

  void dispose() {
    _fallbackTicker?.cancel();
    _subscription?.cancel();
    _fftController.close();
  }
}
