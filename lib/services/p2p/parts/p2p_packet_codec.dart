part of '../p2p_sync_service.dart';

const int _maxIdLen = 128;
const int _maxTitleLen = 300;
const int _maxArtistLen = 200;
const int _maxAlbumLen = 200;
const int _maxGenreLen = 100;
const int _maxMoodLen = 100;
const int _maxNameLen = 40;
const int _maxChatLen = 500;
const int _maxUrlLen = 2048;

String _stripControlChars(String s) =>
    s.replaceAll(RegExp(r'[\x00-\x1F\x7F\u202A-\u202E]'), '');

String _cap(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  var cut = s.substring(0, maxLen);
  final last = cut.codeUnitAt(cut.length - 1);
  if (last >= 0xD800 && last <= 0xDBFF) {
    cut = cut.substring(0, cut.length - 1);
  }
  return cut;
}

double? _readNum(dynamic v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) {
    final n = num.tryParse(v.trim());
    if (n == null || !n.isFinite) return null;
    return n.toDouble();
  }
  return null;
}

int _jsonNestingDepth(String s) {
  var depth = 0;
  var maxDepth = 0;
  var inString = false;
  var escaped = false;
  for (var i = 0; i < s.length; i++) {
    final ch = s.codeUnitAt(i);
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == 0x5C) {
        escaped = true;
      } else if (ch == 0x22) {
        inString = false;
      }
      continue;
    }
    if (ch == 0x22) {
      inString = true;
    } else if (ch == 0x7B || ch == 0x5B) {
      depth++;
      if (depth > maxDepth) maxDepth = depth;
    } else if (ch == 0x7D || ch == 0x5D) {
      depth--;
      if (depth < 0) return P2PSyncService._maxJsonDepth + 1;
    }
  }
  return maxDepth;
}

const List<String> _allowedUrlHosts = [
  'saavncdn.com',
  'jiosaavn.com',
  'cdn.jiosaavn.com',
  'i.ytimg.com',
  'music.youtube.com',
  'lh3.googleusercontent.com',
  'googlevideo.com',
  'is1-ssl.mzstatic.com',
  'itunes.apple.com',
  'jamendo.com',
  'storage.googleapis.com',
  'akamaized.net',
  'cloudfront.net',
  'images.unsplash.com',
  'i.scdn.co',
  'mosaic.scdn.co',
  'lastfm.freetls.fastly.net',
  'coverartarchive.org',
];

String? _allowedRemoteUrl(dynamic v) {
  if (v == null) return null;
  final s = _stripControlChars(v.toString()).trim();
  if (s.isEmpty || s.length > _maxUrlLen) return null;
  final uri = Uri.tryParse(s);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.userInfo.isNotEmpty) return null;
  if (uri.port != 80 && uri.port != 443) return null;
  final host = uri.host.toLowerCase();
  if (host.isEmpty || host.endsWith('.')) return null;
  final allowed =
      _allowedUrlHosts.any((d) => host == d || host.endsWith('.$d'));
  if (!allowed) return null;
  return s;
}

extension P2PPacketCodec on P2PSyncService {
  Map<String, dynamic>? _decodeWireObject(dynamic rawData) {
    try {
      String str;
      if (rawData is List<int>) {
        if (rawData.length > P2PSyncService.maxPayloadBytes) return null;
        str = utf8.decode(rawData, allowMalformed: false);
      } else if (rawData is String) {
        if (rawData.length > P2PSyncService.maxPayloadBytes) return null;
        str = rawData;
      } else {
        return null;
      }
      if (_jsonNestingDepth(str) > P2PSyncService._maxJsonDepth) return null;
      final decoded = jsonDecode(str);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  String? _cleanStr(dynamic v, {required int maxLen}) {
    if (v == null) return null;
    final s = _stripControlChars(v.toString()).trim();
    if (s.isEmpty) return null;
    return _cap(s, maxLen);
  }

  Song? _decodeRemoteSong(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final rawId = map['id'];
    if (rawId is! String) return null;
    final capped = _cleanStr(rawId, maxLen: _maxIdLen);
    if (capped == null || capped.isEmpty) return null;
    // Song ids flow into filesystem paths (stem dirs, downloads), cache
    // keys, and local DB rows. Reduce a hostile peer id (`../../evil`,
    // absolute paths, control characters) to a single safe component so
    // it can never escape its storage directory on this device.
    final id = safePathSegment(capped);
    if (id.isEmpty) return null;
    final title =
        _cleanStr(map['title'], maxLen: _maxTitleLen) ?? 'Unknown Track';
    final artist =
        _cleanStr(map['artist'], maxLen: _maxArtistLen) ?? 'Unknown Artist';
    final album = _cleanStr(map['album'], maxLen: _maxAlbumLen);
    final genre = _cleanStr(map['genre'], maxLen: _maxGenreLen);
    final mood = _cleanStr(map['mood'], maxLen: _maxMoodLen);

    var durationMs = _readNum(map['durationMs']);
    if (durationMs == null) {
      final sec = _readNum(map['duration']);
      if (sec != null) durationMs = sec * 1000;
    }
    final duration = (durationMs != null &&
            durationMs > 0 &&
            durationMs <= 24 * 60 * 60 * 1000)
        ? Duration(milliseconds: durationMs.round())
        : Duration.zero;

    List<double> vec = List.filled(32, 0.5);
    var hasValidVector = false;
    final rawVec = map['featureVector'];
    if (rawVec != null) {
      try {
        List<dynamic> rawList;
        if (rawVec is List) {
          rawList = rawVec;
        } else {
          final decoded = jsonDecode(rawVec.toString());
          rawList = decoded is List ? decoded : <dynamic>[];
        }
        if (rawList.length == 32 && rawList.every((e) => e is num)) {
          final parsed =
              rawList.map<double>((e) => (e as num).toDouble()).toList();
          if (parsed.every((v) => v >= 0.0 && v <= 1.0)) {
            vec = parsed;
            hasValidVector = true;
          }
        }
      } catch (_) {}
    }

    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album ?? 'Single',
      artworkUrl: _allowedRemoteUrl(map['artworkUrl']),
      streamUrl: _allowedRemoteUrl(map['streamUrl']),
      duration: duration,
      genre: genre,
      mood: mood,
      featureVector: vec,
      hasValidFeatureVector: hasValidVector,
    );
  }

  Song _sanitizeSongForWire(Song s) => Song(
        id: _cap(_stripControlChars(s.id), _maxIdLen),
        title: _cap(_stripControlChars(s.title), _maxTitleLen),
        artist: _cap(_stripControlChars(s.artist), _maxArtistLen),
        album: _cap(_stripControlChars(s.album), _maxAlbumLen),
        artworkUrl: _allowedRemoteUrl(s.artworkUrl),
        streamUrl: _allowedRemoteUrl(s.streamUrl),
        localFilePath: null,
        duration: s.duration,
        genre: _cleanStr(s.genre, maxLen: _maxGenreLen),
        mood: _cleanStr(s.mood, maxLen: _maxMoodLen),
        featureVector: s.featureVector,
        hasValidFeatureVector: s.hasValidFeatureVector,
      );

  List<Map<String, dynamic>> _wireQueueSlice() => _collaborativeQueue
      .take(P2PSyncService.maxQueueLength)
      .map((s) => _sanitizeSongForWire(s).toMap())
      .toList();

  JamChatMessage? _decodeChatMessage(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final rawSender = map['senderName'];
    final rawText = map['text'];
    if (rawSender is! String || rawText is! String) return null;
    final sender = _cleanStr(rawSender, maxLen: _maxNameLen) ?? 'Listener';
    final text = _cleanStr(rawText, maxLen: _maxChatLen);
    if (text == null || text.isEmpty) return null;
    final id = _cleanStr(map['id'], maxLen: 64) ?? '';
    final tsNum = _readNum(map['timestamp']);
    final timestamp = (tsNum != null && tsNum > 0)
        ? DateTime.fromMillisecondsSinceEpoch(tsNum.round())
        : DateTime.now();
    return JamChatMessage(
        id: id, senderName: sender, text: text, timestamp: timestamp);
  }

  void _appendChat(JamChatMessage msg) {
    _chatMessages.add(msg);
    if (_chatMessages.length > P2PSyncService.maxChatCount) {
      _chatMessages.removeRange(
          0, _chatMessages.length - P2PSyncService.maxChatCount);
    }
    notify();
  }

  String _safePeerSenderName(String claimed) {
    final name = claimed.trim();
    if (name.isEmpty) return 'Listener';
    final lower = name.toLowerCase();
    final hostName = _userName.trim();
    if (lower == 'system' ||
        (hostName.isNotEmpty && lower == hostName.toLowerCase())) {
      return 'Listener';
    }
    return name;
  }
}
