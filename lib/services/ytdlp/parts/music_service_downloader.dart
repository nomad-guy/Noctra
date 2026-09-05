part of '../music_service.dart';

extension MusicServiceDownloader on MusicService {
  static Future<Directory> getMusicDirectory() async =>
      const DownloadLocationResolver()
          .resolve(MusicService._selectedDownloadLocationKey());

  static Future<String?> resolveStreamUrl(Song song) async =>
      CompositeStreamResolver.resolve(song);

  static Future<Song?> downloadTrack(Song song) async {
    if (kIsWeb) return song.copyWith(isDownloaded: true);
    if (MusicService._downloadInFlight.containsKey(song.id)) {
      return MusicService._downloadInFlight[song.id]!;
    }
    final future = _doDownloadTrack(song);
    MusicService._downloadInFlight[song.id] = future;
    try {
      return await future;
    } finally {
      MusicService._downloadInFlight.remove(song.id);
    }
  }

  static Future<Song?> _doDownloadTrack(Song song) async {
    try {
      final musicDir = await const DownloadLocationResolver()
          .resolve(MusicService._selectedDownloadLocationKey());
      if (!musicDir.existsSync()) {
        musicDir.createSync(recursive: true);
      }
      if (!musicDir.existsSync()) musicDir.createSync(recursive: true);
      final rawName = '${song.artist}_${song.title}'
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final qualityService = StreamQualityService();
      final ext = qualityService.preferredCodec.name;
      final sanitizedFallbackId = song.id.replaceAll(RegExp(r'[^\w-]'), '_');
      final baseName = rawName.isNotEmpty ? rawName : sanitizedFallbackId;
      final safeBase =
          baseName.length > 120 ? baseName.substring(0, 120) : baseName;
      final uniqueId = sanitizedFallbackId.isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : sanitizedFallbackId;
      final fileName =
          '${safeBase.isNotEmpty ? safeBase : "track"}_$uniqueId.$ext';
      final file = File('${musicDir.path}/$fileName');

      final canonicalDir = musicDir.absolute.path.replaceAll('\\', '/');
      final canonicalFile = file.absolute.path.replaceAll('\\', '/');
      final normalizedPrefix =
          canonicalDir.endsWith('/') ? canonicalDir : '$canonicalDir/';
      if (!canonicalFile.startsWith(normalizedPrefix)) {
        throw const FormatException(
            'Path traversal detected in download target');
      }

      final nonce = DateTime.now().microsecondsSinceEpoch;
      final tempFile = File('${musicDir.path}/.$fileName.$nonce.part');
      final resolvedUrl = await resolveStreamUrl(song);
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        if (!MusicService.downloadProgressController.isClosed) {
          MusicService.downloadProgressController.add({song.id: 1.0});
        }
        return null;
      }
      final parsedUri = Uri.tryParse(resolvedUrl);
      if (parsedUri == null ||
          (parsedUri.scheme != 'https' && parsedUri.scheme != 'file')) {
        NoctraLogger.w(
            'downloadTrack: Insecure or invalid URI scheme for ${song.title}');
        if (!MusicService.downloadProgressController.isClosed) {
          MusicService.downloadProgressController.add({song.id: 1.0});
        }
        return null;
      }
      final req = http.Request('GET', parsedUri)
        ..headers.addAll({'User-Agent': 'Mozilla/5.0'});
      final client = http.Client();
      try {
        final resp = await client.send(req);
        final total = resp.contentLength ?? 0;
        int received = 0;
        final sink = tempFile.openWrite();
        try {
          // Idle read timeout: a stalled-but-open connection must fail and
          // clean up instead of hanging the download (and its UI state).
          await resp.stream
              .timeout(const Duration(seconds: 30))
              .forEach((chunk) {
            sink.add(chunk);
            received += chunk.length;
            if (!MusicService.downloadProgressController.isClosed) {
              if (total > 0) {
                MusicService.downloadProgressController
                    .add({song.id: (received / total).clamp(0.0, 0.99)});
              } else {
                MusicService.downloadProgressController
                    .add({song.id: (received / 4000000.0).clamp(0.05, 0.95)});
              }
            }
          });
          await sink.flush();
          await sink.close();
          if (total > 0 && received < (total * 0.95)) {
            throw FormatException(
                'Incomplete download: received $received of $total bytes');
          }
          if (received < 10000) {
            throw const FormatException(
                'Downloaded audio file is too small or corrupt');
          }
          if (tempFile.existsSync()) {
            File? backupFile;
            try {
              if (file.existsSync()) {
                backupFile = File('${file.path}.$nonce.previous');
                file.renameSync(backupFile.path);
              }
              tempFile.renameSync(file.path);
            } catch (_) {
              try {
                tempFile.copySync(file.path);
                tempFile.deleteSync();
              } catch (_) {
                if (backupFile?.existsSync() ?? false) {
                  backupFile!.renameSync(file.path);
                }
                rethrow;
              }
            }
            if (backupFile?.existsSync() ?? false) {
              try {
                backupFile!.deleteSync();
              } catch (_) {}
            }
          }
        } catch (e) {
          try {
            await sink.close();
          } catch (_) {}
          if (tempFile.existsSync()) {
            try {
              tempFile.deleteSync();
            } catch (_) {}
          }
          rethrow;
        }
        if (!MusicService.downloadProgressController.isClosed) {
          MusicService.downloadProgressController.add({song.id: 1.0});
        }
        return song.copyWith(isDownloaded: true, localFilePath: file.path);
      } finally {
        client.close();
      }
    } catch (e) {
      NoctraLogger.e('Track download failed for "${song.title}"', e);
      if (!MusicService.downloadProgressController.isClosed) {
        MusicService.downloadProgressController.add({song.id: 1.0});
      }
      return null;
    }
  }

  static Future<double?> fetchSponsorBlockIntroSkip(String videoId) async {
    try {
      final uri = Uri.parse(
          'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["music_offtopic"]');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List?;
        if (data != null && data.isNotEmpty) {
          final seg = data[0]['segment'] as List?;
          if (seg != null && seg.length >= 2) {
            final start = (seg[0] as num).toDouble(),
                end = (seg[1] as num).toDouble();
            if (start < 15.0 && end > 0) return end;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
