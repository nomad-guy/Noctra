import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/noctra_logger.dart';
import '../../core/utils/path_safe_identifier.dart';
import '../resolvers/trusted_audio_hosts.dart';

/// Downloads a remote audio file into app temp storage for stem
/// separation, enforcing a 100 MB hard cap while streaming.
///
/// Kept separate from [AudioStemSeparationService] so the service file
/// stays under the 300-LOC limit; this helper owns the network/disk
/// concerns of fetching the separation input.
class StemInputDownloader {
  StemInputDownloader._();

  /// Returns the local path of the downloaded input, or '' on failure.
  /// Reuses an existing cached download for the same [songId].
  static Future<String> download(String url, String songId) async {
    final client = HttpClient();
    File? tempFile;
    var completed = false;
    try {
      final initialUri = Uri.tryParse(url);
      if (initialUri == null || !TrustedAudioHosts.isTrusted(url)) {
        NoctraLogger.w('Rejected untrusted stem input URL');
        return '';
      }
      final tempDir = await getTemporaryDirectory();
      // [songId] can be attacker-influenced; never let it escape the temp
      // directory or name a `.part`/directory path.
      tempFile =
          File('${tempDir.path}/stem_input_${safePathSegment(songId)}.wav');
      if (tempFile.existsSync() && tempFile.lengthSync() > 1024) {
        return tempFile.path;
      }

      // Hard cap the input size to 100 MB. A 4-minute 320 kbps MP3
      // is ~10 MB; anything materially larger indicates either a
      // raw lossless file (not suitable for the band splitter) or
      // a malicious server. Refuse rather than pin disk.
      const maxInputBytes = 100 * 1024 * 1024;
      client.connectionTimeout = const Duration(seconds: 8);
      // idleTimeout / connectionTimeout are connection-level; a
      // per-request timeout is also applied below via .timeout().
      final request =
          await client.getUrl(initialUri).timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      final response = await request.close();
      if (response.isRedirect ||
          response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        NoctraLogger.w('Stem input request returned ${response.statusCode}');
        return '';
      }
      final contentType = response.headers.contentType;
      if (contentType != null && contentType.primaryType != 'audio') {
        NoctraLogger.w('Stem input response was not audio');
        return '';
      }
      final sink = tempFile.openWrite();
      int received = 0;
      // Idle read timeout: a server that accepts the connection but stops
      // sending (or a dead NAT path) must not hang the download forever.
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
        if (received > maxInputBytes) {
          await sink.close();
          if (tempFile.existsSync()) {
            try {
              tempFile.deleteSync();
            } catch (_) {}
          }
          NoctraLogger.w('Stem input exceeded 100 MB, aborted');
          return '';
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      completed = true;
      return tempFile.path;
    } catch (e) {
      NoctraLogger.e('Failed to download audio for separation', e);
      return '';
    } finally {
      if (!completed && tempFile != null && tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }
}
