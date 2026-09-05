import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'audio_player_service.dart';

class AudioVisualizerService {
  static final AudioVisualizerService _instance =
      AudioVisualizerService._internal();
  factory AudioVisualizerService() => _instance;

  static const _eventChannel =
      EventChannel('com.nomadguy.noctra/audio_visualizer');
  // Same channel as `AudioChannelsDelegate` registers — the visualizer
  // forwards every session-id change here so the effect graph
  // (equalizer/bass boost/etc.) is rebuilt even when no visualizer
  // widget is currently mounted.
  static const _effectsChannel =
      MethodChannel('com.nomadguy.noctra/audio_effects');
  StreamSubscription? _subscription, _sessionSub;
  Timer? _fallbackTicker;
  int? _currentSessionId;
  int _lastHardwarePacketMs = 0;
  int _subscriberCount = 0;

  final _fftController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get fftStream => _fftController.stream;

  // Waveform stream added so the Dart side mirrors the native
  // envelope. The previous version silently dropped waveform
  // packets because it only inspected `data is List`.
  final _waveformController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get waveformStream => _waveformController.stream;

  List<double> _latestFft = List.filled(32, 0.2);
  List<double> get latestFft => List.unmodifiable(_latestFft);

  List<double> _latestWaveform = List.filled(32, 0.0);
  List<double> get latestWaveform => List.unmodifiable(_latestWaveform);

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
        _sessionSub?.cancel();
        _sessionSub = playerService.player.androidAudioSessionIdStream
            .listen((sessionId) {
          if (sessionId != null &&
              sessionId > 0 &&
              sessionId != _currentSessionId) {
            _startListening(sessionId);
          }
          // Forward every session change (even no-op) to the
          // effects engine so equalizer/bass/etc. follow the
          // player swap. The native side is idempotent so the
          // no-op duplicates are free.
          if (sessionId != null && sessionId > 0) {
            _notifyEffectsSessionChanged(sessionId);
          }
        });
      } catch (_) {}
    }
  }

  /// Fire-and-forget MethodChannel call to the native effects
  /// engine. Failures are logged at native side; Dart does not
  /// need the result.
  void _notifyEffectsSessionChanged(int sessionId) {
    if (kIsWeb) return;
    _effectsChannel.invokeMethod<bool>(
      'notifySessionChanged',
      {'sessionId': sessionId},
    ).catchError((Object e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AudioVisualizerService: notifySessionChanged failed — $e');
      }
      return false;
    });
  }

  void subscribe() {
    _subscriberCount++;
    if (_subscriberCount == 1) _startFallbackLoop();
  }

  void unsubscribe() {
    _subscriberCount = max(0, _subscriberCount - 1);
    if (_subscriberCount == 0) {
      _fallbackTicker?.cancel();
      _fallbackTicker = null;
    }
  }

  void _startListening(int sessionId) {
    _currentSessionId = sessionId;
    _subscription?.cancel();
    try {
      _subscription =
          _eventChannel.receiveBroadcastStream({'sessionId': sessionId}).listen(
        (data) => handleEnvelope(data),
        onError: (_) {},
      );
    } catch (_) {}
  }

  List<double> _resample32(List<double> input) {
    if (input.length == 32) return List<double>.from(input);
    final out = List<double>.filled(32, 0.0);
    for (int i = 0; i < 32; i++) {
      final idx = (i * input.length) ~/ 32;
      out[i] = input[idx.clamp(0, input.length - 1)];
    }
    return out;
  }

  final AudioPlayerService _audioPlayer = AudioPlayerService();

  void _startFallbackLoop() {
    _fallbackTicker?.cancel();
    _fallbackTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastHardwarePacketMs > 150) {
        final t = now / 1000.0;
        final isPlaying = _audioPlayer.player.playing;
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
        if (!_fftController.isClosed) {
          _fftController.add(_latestFft);
        }
      }
    });
  }

  void dispose() {
    _fallbackTicker?.cancel();
    _subscription?.cancel();
    _sessionSub?.cancel();
    _fftController.close();
    _waveformController.close();
  }

  /// Demultiplex a single envelope from the native visualizer.
  /// Exposed (not private) so the demux logic can be unit tested
  /// without a real audio session. Returns true if the envelope
  /// was recognised and dispatched to a stream; false otherwise.
  @visibleForTesting
  bool handleEnvelope(dynamic data) {
    if (data is! Map) return false;
    final type = data['type'];
    final raw = data['data'];
    if (raw is! List || raw.isEmpty) return false;
    final parsed = raw.map((e) {
      if (e is num) return e.toDouble();
      if (e is String) return double.tryParse(e) ?? 0.0;
      return 0.0;
    }).toList();

    _lastHardwarePacketMs = DateTime.now().millisecondsSinceEpoch;
    if (type == 'fft') {
      _latestFft = _resample32(parsed);
      if (!_fftController.isClosed) {
        _fftController.add(_latestFft);
      }
      return true;
    } else if (type == 'waveform') {
      _latestWaveform = _resample32(parsed);
      if (!_waveformController.isClosed) {
        _waveformController.add(_latestWaveform);
      }
      return true;
    }
    return false;
  }
}
