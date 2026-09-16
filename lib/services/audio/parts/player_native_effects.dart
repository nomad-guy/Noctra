part of '../audio_player_service.dart';

/// Audio-effects mixin: native equalizer, bass boost, virtualizer,
/// Studio Master sessions, and engine status.
///
/// Split from player_effects_and_settings.dart to keep both files under the
/// 300-LOC architecture gate. All state lives on [AudioPlayerServiceBase].
mixin PlayerNativeEffectsMixin on AudioPlayerServiceBase {
  static const _effectsChannel =
      MethodChannel('com.nomadguy.noctra/audio_effects');

  List<double>? _lastEqualizerBands;
  double? _lastBassBoost;
  double? _lastVirtualizer;

  @override
  Future<bool> attachNativeEffectsSession() async {
    if (!NoctraCapabilities.supportsNativeAudioEffects) {
      return false;
    }
    try {
      int? sid = _player.androidAudioSessionId;
      if (sid == null || sid <= 0) {
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          sid = _player.androidAudioSessionId;
          if (sid != null && sid > 0) break;
        }
      }
      if (sid == null || sid <= 0) {
        return false;
      }
      final attached = (await _effectsChannel
              .invokeMethod<bool>('attachSession', {'sessionId': sid})) ??
          false;
      if (attached) {
        if (_studioMasterMode.isNotEmpty && _studioMasterMode != 'off') {
          _effectsChannel.invokeMethod('applyStudioMode', {
            'sessionId': sid,
            'mode': _studioMasterMode,
          }).catchError((_) => false);
        }
        if (_lastEqualizerBands != null) {
          _effectsChannel.invokeMethod('applyEqualizer', {
            'sessionId': sid,
            'bands': _lastEqualizerBands,
            'bassBoost': _lastBassBoost ?? 0.0,
            'virtualizer': _lastVirtualizer ?? 0.0,
          }).catchError((_) => false);
        }
      }
      return attached;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> applyStudioMasterMode(String mode) async {
    try {
      final sid = _player.androidAudioSessionId ?? 0;
      final applied = (await _effectsChannel.invokeMethod<bool>('applyStudioMode', {
            'sessionId': sid,
            'mode': mode,
          })) ??
          false;
      if (applied) {
        _studioMasterMode = mode;
      }
      return applied;
    } catch (e) {
      NoctraLogger.w('applyStudioMasterMode failed (mode=$mode)', e);
      return false;
    }
  }

  void applyEqualizer(
      {List<double>? bands, double? bassBoost, double? virtualizer}) {
    try {
      if (bands != null) _lastEqualizerBands = List<double>.from(bands);
      if (bassBoost != null) _lastBassBoost = bassBoost;
      if (virtualizer != null) _lastVirtualizer = virtualizer;

      final sid = _player.androidAudioSessionId ?? 0;
      _effectsChannel.invokeMethod('applyEqualizer', {
        'sessionId': sid,
        'bands': bands ?? [0.0, 0.0, 0.0, 0.0, 0.0],
        'bassBoost': bassBoost ?? 0.0,
        'virtualizer': virtualizer ?? 0.0,
      }).then<void>((_) {}, onError: (Object e) {
        NoctraLogger.w('applyEqualizer failed', e);
      });
    } catch (e) {
      NoctraLogger.w('applyEqualizer failed', e);
    }
  }

  @override
  Future<Map<String, dynamic>> getAudioEngineStatus() async {
    if (!NoctraCapabilities.supportsNativeAudioEffects) {
      return {'engine': 'none', 'isDynamics': false};
    }
    try {
      final res = await _effectsChannel
          .invokeMapMethod<String, dynamic>('getEngineStatus');
      return res ?? {'engine': 'none', 'isDynamics': false};
    } catch (_) {
      return {'engine': 'none', 'isDynamics': false};
    }
  }
}
