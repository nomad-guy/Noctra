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

  void initialize(AudioPlayerService audioPlayer) => _audioPlayer = audioPlayer;

  void setUserName(String name) {
    _userName = name.trim().isEmpty ? 'Listener' : name.trim();
    notifyListeners();
  }

  String _generateRoomCode() => 'JAM-${1000 + Random().nextInt(9000)}';

  Future<bool> startHost({int port = 8099, String? customRoomCode}) async {
    await stopParty();
    _roomCode = customRoomCode ?? _generateRoomCode();
    _userName = 'Host';
    _chatMessages.clear();
    _collaborativeQueue.clear();

    _chatMessages.add(JamChatMessage(
      id: 'system_init',
      senderName: 'System',
      text: 'Noctra Jam Room "$_roomCode" created. Serverless P2P mesh online.',
      timestamp: DateTime.now(),
    ));

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
    } catch (_) {
      return false;
    }
  }

  void _handleHostIncomingMessage(dynamic socket, dynamic rawData) {
    try {
      final str = rawData.toString();
      if (str.length > 65536) return;
      final data = jsonDecode(str) as Map<String, dynamic>;
      final type = data['type'];

      if (type == 'chat') {
        final msg = JamChatMessage.fromMap(data['message']);
        _chatMessages.add(msg);
        _broadcastToPeers(str);
        notifyListeners();
      } else if (type == 'add_to_queue') {
        addToCollaborativeQueue(Song.fromMap(data['song']));
      } else if (type == 'remove_from_queue') {
        removeFromCollaborativeQueue(data['songId']);
      }
    } catch (_) {}
  }

  Future<bool> joinParty(String hostIp, {int port = 8099}) async {
    final cleanIp = hostIp.trim();
    final ipRegex = RegExp(r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$');
    if (!ipRegex.hasMatch(cleanIp) && cleanIp != 'localhost') return false;

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
      int retryCount = 0;
      _clientSocket.listen(
        (data) => _handleClientIncomingMessage(data),
        onDone: () {
          if (_role == SyncCastRole.client && _connectedHostIp != null && retryCount < 3) {
            retryCount++;
            Future.delayed(Duration(milliseconds: 1200 * retryCount), () => joinParty(cleanIp, port: port));
          } else {
            stopParty();
          }
        },
        onError: (_) => stopParty(),
      );

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleClientIncomingMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData.toString()) as Map<String, dynamic>;
      final type = data['type'];

      if (type == 'chat') {
        _chatMessages.add(JamChatMessage.fromMap(data['message']));
        notifyListeners();
      } else if (type == 'sync' || type == 'jam_full_state') {
        if (data.containsKey('queue')) {
          _collaborativeQueue.clear();
          for (final item in data['queue']) {
            _collaborativeQueue.add(Song.fromMap(item));
          }
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
    final msg = JamChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderName: _userName,
      text: text,
      timestamp: DateTime.now(),
    );
    _chatMessages.add(msg);
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
      if (isClient && _clientSocket != null) {
        _clientSocket.add(jsonEncode({'type': 'add_to_queue', 'song': song.toMap()}));
      }
    }
  }

  void removeFromCollaborativeQueue(String songId) {
    _collaborativeQueue.removeWhere((s) => s.id == songId);
    notifyListeners();
    if (isHost) broadcastSync();
    if (isClient && _clientSocket != null) {
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
