import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/utils/noctra_logger.dart';

class AudioDeviceEndpoint {
  final int id;
  final String name;
  final String type;
  final int typeCode;
  final bool isSink;
  final bool isActive;

  const AudioDeviceEndpoint({
    required this.id,
    required this.name,
    required this.type,
    required this.typeCode,
    required this.isSink,
    required this.isActive,
  });

  factory AudioDeviceEndpoint.fromMap(Map<dynamic, dynamic> map) {
    return AudioDeviceEndpoint(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] ?? 'Audio Device').toString(),
      type: (map['type'] ?? 'speaker').toString(),
      typeCode: (map['typeCode'] as num?)?.toInt() ?? 0,
      isSink: map['isSink'] == true,
      isActive: map['isActive'] == true,
    );
  }
}

class AudioRouterService {
  static final AudioRouterService _instance = AudioRouterService._internal();
  factory AudioRouterService() => _instance;

  static const _methodChannel = MethodChannel('com.nomadguy.noctra/audio_router');
  static const _eventChannel = EventChannel('com.nomadguy.noctra/audio_devices');

  final _deviceController = StreamController<List<AudioDeviceEndpoint>>.broadcast();
  Stream<List<AudioDeviceEndpoint>> get devicesStream => _deviceController.stream;

  StreamSubscription? _eventSub;

  AudioRouterService._internal() {
    _initListener();
  }

  void _initListener() {
    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
        if (event is List) {
          final list = event.map((e) => AudioDeviceEndpoint.fromMap(e as Map)).toList();
          _deviceController.add(list);
        }
      }, onError: (e) {
        NoctraLogger.w('AudioRouterService event stream error', e);
        Future.delayed(const Duration(seconds: 4), () {
          if (!_deviceController.isClosed) {
            _eventSub?.cancel();
            _initListener();
          }
        });
      });
    } catch (e) {
      NoctraLogger.w('AudioRouterService initListener failed', e);
    }
  }

  Future<List<AudioDeviceEndpoint>> getConnectedDevices() async {
    try {
      final List<dynamic>? raw = await _methodChannel.invokeListMethod('getConnectedDevices');
      if (raw != null) {
        return raw.map((e) => AudioDeviceEndpoint.fromMap(e as Map)).toList();
      }
    } catch (_) {}
    return [
      const AudioDeviceEndpoint(
        id: 1,
        name: 'Built-in Phone Speaker',
        type: 'Phone Speaker',
        typeCode: 2,
        isSink: true,
        isActive: true,
      ),
    ];
  }

  Future<bool> setOutputDevice(int deviceId) async {
    try {
      final dynamic res = await _methodChannel.invokeMethod('setOutputDevice', {'deviceId': deviceId});
      if (res is bool) return res;
      if (res is Map) return res['ok'] == true;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMultiOutputMode(bool enabled, List<int> deviceIds) async {
    try {
      final dynamic res = await _methodChannel.invokeMethod('setMultiOutput', {'enabled': enabled, 'deviceIds': deviceIds});
      if (res is bool) return res;
      if (res is Map) return res['ok'] == true;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openSystemMediaSwitcher() async {
    try {
      final dynamic res = await _methodChannel.invokeMethod('openSystemMediaSwitcher');
      if (res is bool) return res;
      if (res is Map) return res['ok'] == true;
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _eventSub?.cancel();
    _deviceController.close();
  }
}
