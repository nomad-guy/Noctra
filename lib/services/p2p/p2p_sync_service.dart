import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/models/song_model.dart';
import '../audio/audio_player_service.dart';
import 'p2p_models.dart';
import 'p2p_socket_engine.dart';

enum SyncCastRole { idle, host, client }

class P2PSyncService extends ChangeNotifier {
  static final P2PSyncService _instance = P2PSyncService._internal();
  factory P2PSyncService() => _instance;
  P2PSyncService._internal();

  static const int maxPeers = 8;
  static const int maxChatCount = 100;
  static const int maxPayloadBytes = 65536;

  SyncCastRole _role = SyncCastRole.idle;
  SyncCastRole get role => _role;
  bool get isHost => _role == SyncCastRole.host;
  bool get isClient => _role == SyncCastRole.client;
  bool get isIdle => _role == SyncCastRole.idle;
  bool get isJamActive => _role != SyncCastRole.idle;

  HttpServer? _server;
  final List<dynamic> _connectedPeers = [];
  int get connectedPeersCount => isHost ? (_connectedPeers.length + 1) : (isClient ? 2 : 0);

  dynamic _clientSocket;
  String? _localIp;
  String? get localIp => _localIp;
  String? _connectedHostIp;
  String? get connectedHostIp => _connectedHostIp;
  String _roomCode = 'JAM-8088';
  String get roomCode => _roomCode;
  String _userName = 'Host';
  String get userName => _userName;
  bool _hostControlsOnly = false;
  bool get hostControlsOnly => _hostControlsOnly;

  final List<Song> _collaborativeQueue = [];
  List<Song> get collaborativeQueue => List.unmodifiable(_collaborativeQueue);
  final List<JamChatMessage> _chatMessages = [];
  List<JamChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  AudioPlayerService? _audioPlayer;
  Timer? _reconnectTimer;
  int _clientRetryCount = 0;

  void initialize(AudioPlayerService audioPlayer) => _audioPlayer = audioPlayer;
  void setUserName(String name) { _userName = name.trim().isEmpty ? 'Listener' : name.trim(); notifyListeners(); }
  String _generateRoomCode() => 'JAM-${1000 + Random().nextInt(9000)}';

  bool _isValidIpv4(String ip) {
    if (ip == 'localhost' || ip == '127.0.0.1') return true;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  Future<bool> startHost({int port = 8099, String? customRoomCode}) async {
    await stopParty();
    _roomCode = customRoomCode ?? _generateRoomCode();
    _userName = 'Host';
    _chatMessages.clear();
    _collaborativeQueue.clear();
    _chatMessages.add(JamChatMessage(id: 'system_init', senderName: 'System', text: 'Noctra Jam Room "$_roomCode" online.', timestamp: DateTime.now()));

    if (kIsWeb) {
      _role = SyncCastRole.host;
      _localIp = '127.0.0.1';
      notifyListeners();
      return true;
    }

    try {
      _server = await P2PSocketEngine.bindServer(port);
      _role = SyncCastRole.host;
      _localIp = await P2PSocketEngine.findLocalIp();

      _server?.listen((request) {
        if (request.uri.path == '/ws') {
          if (_connectedPeers.length >= maxPeers) {
            request.response.statusCode = HttpStatus.serviceUnavailable;
            request.response.close();
            return;
          }
          WebSocketTransformer.upgrade(request).then((socket) {
            _connectedPeers.add(socket);
            notifyListeners();

            final statePayload = {
              'type': 'jam_full_state',
              'roomCode': _roomCode,
              'hostControlsOnly': _hostControlsOnly,
              'queue': _collaborativeQueue.map((s) => s.toMap()).toList(),
              'chatMessages': _chatMessages.map((m) => m.toMap()).toList(),
              'serverTime': DateTime.now().millisecondsSinceEpoch,
            };
            if (_audioPlayer?.currentSong != null) {
              statePayload['song'] = _audioPlayer!.currentSong!.toMap();
              statePayload['positionMs'] = _audioPlayer!.player.position.inMilliseconds;
              statePayload['isPlaying'] = _audioPlayer!.player.playing;
            }
            socket.add(jsonEncode(statePayload));
            socket.listen(
              (data) => _handleHostIncomingMessage(socket, data),
              onDone: () { _connectedPeers.remove(socket); notifyListeners(); },
              onError: (_) { _connectedPeers.remove(socket); notifyListeners(); },
            );
          }).catchError((_) {});
        }
      });
      notifyListeners();
      return true;
    } catch (_) { return false; }
  }

  void _handleHostIncomingMessage(dynamic socket, dynamic rawData) {
    try {
      final str = rawData.toString();
      if (str.length > maxPayloadBytes) return;
      final data = jsonDecode(str) as Map<String, dynamic>;
      final type = data['type'];
      if (type == 'chat') {
        final msg = JamChatMessage.fromMap(data['message']);
        _chatMessages.add(msg);
        if (_chatMessages.length > maxChatCount) _chatMessages.removeRange(0, _chatMessages.length - maxChatCount);
        _broadcastToPeers(str);
        notifyListeners();
      } else if (type == 'add_to_queue') {
        if (!_hostControlsOnly) addToCollaborativeQueue(Song.fromMap(data['song']));
      } else if (type == 'remove_from_queue') {
        if (!_hostControlsOnly) removeFromCollaborativeQueue(data['songId']);
      }
    } catch (_) {}
  }

  Future<bool> joinParty(String hostIp, {int port = 8099}) async {
    final cleanIp = hostIp.trim();
    if (!_isValidIpv4(cleanIp)) return false;
    await stopParty();
    _connectedHostIp = cleanIp;
    _userName = 'Listener';

    if (kIsWeb) {
      _role = SyncCastRole.client;
      notifyListeners();
      return true;
    }

    try {
      _clientSocket = await P2PSocketEngine.connectClient(cleanIp, port);
      if (_clientSocket == null) return false;
      _role = SyncCastRole.client;
      _clientRetryCount = 0;
      _clientSocket.listen(
        (data) => _handleClientIncomingMessage(data),
        onDone: () {
          if (_role == SyncCastRole.client && _connectedHostIp != null && _clientRetryCount < 3) {
            _clientRetryCount++;
            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(Duration(milliseconds: 1200 * _clientRetryCount), () => joinParty(cleanIp, port: port));
          } else { stopParty(); }
        },
        onError: (_) => stopParty(),
      );
      notifyListeners();
      return true;
    } catch (_) { return false; }
  }

  void _handleClientIncomingMessage(dynamic rawData) {
    try {
      final str = rawData.toString();
      if (str.length > maxPayloadBytes) return;
      final data = jsonDecode(str) as Map<String, dynamic>;
      final type = data['type'];
      if (type == 'chat') {
        _chatMessages.add(JamChatMessage.fromMap(data['message']));
        if (_chatMessages.length > maxChatCount) _chatMessages.removeRange(0, _chatMessages.length - maxChatCount);
        notifyListeners();
      } else if (type == 'sync' || type == 'jam_full_state') {
        _hostControlsOnly = data['hostControlsOnly'] ?? false;
        if (data.containsKey('queue')) {
          _collaborativeQueue.clear();
          for (final item in data['queue']) { _collaborativeQueue.add(Song.fromMap(item)); }
        }
        if (data.containsKey('song') && data['song'] != null) {
          final song = Song.fromMap(data['song']);
          final isPlaying = data['isPlaying'] ?? false;
          final posMs = data['positionMs'] ?? 0;
          if (_audioPlayer != null) {
            if (_audioPlayer!.currentSong?.id != song.id) _audioPlayer!.playSong(song);
            if (isPlaying && !_audioPlayer!.player.playing) _audioPlayer!.player.play();
            if (!isPlaying && _audioPlayer!.player.playing) _audioPlayer!.player.pause();
            _audioPlayer!.player.seek(Duration(milliseconds: posMs));
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void sendChatMessage(String text) {
    final msg = JamChatMessage(id: 'msg_${DateTime.now().millisecondsSinceEpoch}', senderName: _userName, text: text, timestamp: DateTime.now());
    _chatMessages.add(msg);
    if (_chatMessages.length > maxChatCount) _chatMessages.removeRange(0, _chatMessages.length - maxChatCount);
    notifyListeners();
    final packet = jsonEncode(P2PPacket.createChatPacket(msg));
    if (isHost) _broadcastToPeers(packet);
    if (isClient && _clientSocket != null) _clientSocket.add(packet);
  }

  void addToCollaborativeQueue(Song song) {
    if (!_collaborativeQueue.any((s) => s.id == song.id)) {
      _collaborativeQueue.add(song);
      notifyListeners();
      if (isHost) broadcastSync();
      if (isClient && _clientSocket != null && !_hostControlsOnly) {
        _clientSocket.add(jsonEncode({'type': 'add_to_queue', 'song': song.toMap()}));
      }
    }
  }

  void removeFromCollaborativeQueue(String songId) {
    _collaborativeQueue.removeWhere((s) => s.id == songId);
    notifyListeners();
    if (isHost) broadcastSync();
    if (isClient && _clientSocket != null && !_hostControlsOnly) {
      _clientSocket.add(jsonEncode({'type': 'remove_from_queue', 'songId': songId}));
    }
  }

  void toggleHostControlsOnly() {
    _hostControlsOnly = !_hostControlsOnly;
    notifyListeners();
    broadcastSync();
  }

  void broadcastSync() {
    if (!isHost) return;
    final packet = jsonEncode(P2PPacket.createSyncPacket(
      song: _audioPlayer?.currentSong,
      position: _audioPlayer?.player.position ?? Duration.zero,
      isPlaying: _audioPlayer?.player.playing ?? false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      queue: _collaborativeQueue,
      hostControlsOnly: _hostControlsOnly,
    ));
    _broadcastToPeers(packet);
  }

  void _broadcastToPeers(String message) {
    for (final peer in _connectedPeers) {
      try { peer.add(message); } catch (_) {}
    }
  }

  Future<void> stopParty() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _role = SyncCastRole.idle;
    _connectedHostIp = null;
    _localIp = null;
    try { await _server?.close(force: true); } catch (_) {}
    _server = null;
    _connectedPeers.clear();
    try { await _clientSocket?.close(); } catch (_) {}
    _clientSocket = null;
    notifyListeners();
  }
}
