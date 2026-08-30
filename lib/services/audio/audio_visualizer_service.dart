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

  List<double> _latestFft = List.filled(32, 0.0);
  List<double> get latestFft => List.unmodifiable(_latestFft);

  AudioVisualizerService._internal() {
    _init();
  }

  void _init() {
    if (kIsWeb) return;
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
    } catch (e) {
      if (kDebugMode) print('Noctra AudioVisualizer initialization error: $e');
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
        onError: (e) {
          if (kDebugMode) print('Noctra Visualizer FFT stream error: $e');
        },
      );
    } catch (e) {
      if (kDebugMode) print('Noctra Visualizer startListening error: $e');
    }
  }

  void _startFallbackLoop() {
    _fallbackTicker?.cancel();
    _fallbackTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // If hardware capture is idle for > 200ms while audio is playing
      if (now - _lastHardwarePacketMs > 200) {
        final player = AudioPlayerService().player;
        if (player.playing) {
          final posSec = player.position.inMilliseconds / 1000.0;
          final List<double> bins = List.filled(32, 0.0);
          for (int i = 0; i < 32; i++) {
            final freq = (i + 1) * 1.8;
            final wave = (sin(posSec * freq + (i * 0.4)) * 0.4 + 0.5) * (cos(posSec * 3.2) * 0.3 + 0.7);
            bins[i] = wave.clamp(0.05, 0.95);
          }
          _latestFft = bins;
          _fftController.add(_latestFft);
        }
      }
    });
  }

  void dispose() {
    _fallbackTicker?.cancel();
    _subscription?.cancel();
    _fftController.close();
  }
}
