import 'dart:async';
import 'dart:convert' show ByteConversionSink;
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import '../../core/utils/noctra_logger.dart';
import 'app_update_verifier.dart';

/// State machine for one verified, resumable APK transfer.
///
/// The caller owns the [HttpClient]; this class handles redirect hops
/// (re-validating trust on every hop), byte-range resume of a `.part`
/// file, monotonic deadline checks, hard size caps, and full-file
/// SHA-256 verification before promoting the `.part` to its final name.
class AppUpdateTransfer {
  final Duration overallTimeout;
  final Duration readIdleTimeout;
  final int maxBytes;
  final bool Function(Uri uri) isTrusted;
  final void Function(int received, int total)? onProgress;

  AppUpdateTransfer({
    required this.overallTimeout,
    required this.readIdleTimeout,
    required this.maxBytes,
    required this.isTrusted,
    this.onProgress,
  });

  /// Returns the promoted file path on success, null on any failure.
  Future<String?> run({
    required HttpClient client,
    required Uri initial,
    required File tmp,
    required File finalFile,
    required String expectedSha256,
  }) {
    final deadline = DateTime.now().add(overallTimeout);
    return _runInternal(client, initial, tmp, finalFile, expectedSha256,
        deadline);
  }

  Future<String?> _runInternal(
    HttpClient client,
    Uri initial,
    File tmp,
    File finalFile,
    String expectedSha256,
    DateTime deadline,
  ) async {
    var sink = tmp.openWrite(mode: FileMode.append);
    var startOffset = 0;
    if (tmp.existsSync()) {
      try {
        startOffset = tmp.lengthSync();
      } catch (_) {
        startOffset = 0;
      }
    }

    // Feed any existing partial bytes into the digest before resuming.
    var accumulator = DigestAccumulator();
    var converter = crypto.sha256.startChunkedConversion(accumulator);
    var totalBytes = 0;
    if (startOffset > 0) {
      final hadPartial = await _hashExistingPart(
          tmp, startOffset, accumulator, converter);
      if (!hadPartial) {
        startOffset = 0;
        totalBytes = 0;
        accumulator = DigestAccumulator();
        converter = crypto.sha256.startChunkedConversion(accumulator);
      } else {
        totalBytes = startOffset;
      }
    }

    var current = initial;
    var declaredTotal = -1;
    for (int hop = 0; hop <= 5; hop++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        NoctraLogger.w('APK download timed out');
        await _cleanupPartial(tmp, sink);
        return null;
      }
      final req = await client.getUrl(current).timeout(remaining);
      req.followRedirects = false;
      req.maxRedirects = 0;
      req.headers.set(HttpHeaders.userAgentHeader, 'Noctra-Update/1.0');
      if (startOffset > 0) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$startOffset-');
      }
      final resp = await req.close().timeout(remaining);

      if (resp.statusCode >= 300 && resp.statusCode < 400) {
        final loc = resp.headers.value(HttpHeaders.locationHeader);
        await _drainQuietly(resp);
        if (loc == null) {
          NoctraLogger.w('APK redirect without Location header');
          await _cleanupPartial(tmp, sink);
          return null;
        }
        final next = current.resolve(loc);
        if (!isTrusted(next)) {
          NoctraLogger.w(
              'APK redirect to untrusted host refused: ${next.host}');
          await _cleanupPartial(tmp, sink);
          return null;
        }
        current = next;
        continue;
      }

      if (resp.statusCode == 416 && startOffset > 0) {
        await _drainQuietly(resp);
        // Range not satisfiable → the partial already holds everything.
        try {
          await sink.flush();
        } catch (_) {}
        await sink.close();
        return _verifyAndPromote(
            tmp, finalFile, expectedSha256, converter, accumulator,
            deadline: deadline);
      }

      if (resp.statusCode == 200) {
        // Server ignored Range → full body: restart from zero.
        if (startOffset > 0) {
          startOffset = 0;
          totalBytes = 0;
          accumulator = DigestAccumulator();
          converter = crypto.sha256.startChunkedConversion(accumulator);
          try {
            await sink.close();
          } catch (_) {}
          try {
            if (tmp.existsSync()) tmp.deleteSync();
          } catch (_) {}
          sink = tmp.openWrite(mode: FileMode.append);
        }
        final declared = resp.contentLength;
        if (declared > maxBytes) {
          await _drainQuietly(resp);
          NoctraLogger.w('APK too large: $declared bytes');
          await _cleanupPartial(tmp, sink);
          return null;
        }
        declaredTotal = declared >= 0 ? declared : -1;
      } else if (resp.statusCode == 206) {
        final full = _fullSizeFromContentRange(resp, startOffset);
        if (full == null || full <= 0) {
          await _drainQuietly(resp);
          NoctraLogger.w('APK resumed with malformed Content-Range');
          await _cleanupPartial(tmp, sink);
          return null;
        }
        declaredTotal = full;
        if (declaredTotal > maxBytes) {
          await _drainQuietly(resp);
          NoctraLogger.w('APK too large: $declaredTotal bytes');
          await _cleanupPartial(tmp, sink);
          return null;
        }
      } else {
        await _drainQuietly(resp);
        NoctraLogger.w('APK download HTTP ${resp.statusCode}');
        await _cleanupPartial(tmp, sink);
        return null;
      }

      var received = totalBytes;
      try {
        await for (final chunk in resp.timeout(readIdleTimeout)) {
          if (received + chunk.length > maxBytes) {
            await _cleanupPartial(tmp, sink);
            NoctraLogger.w('APK exceeded max size, aborted');
            return null;
          }
          converter.add(chunk);
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, declaredTotal);
        }
        converter.close();
        await sink.flush();
        await sink.close();
        final hex = accumulator.digests.single.toString();
        if (hex.toLowerCase() != expectedSha256.toLowerCase()) {
          await _deleteFile(tmp);
          NoctraLogger.w(
              'APK SHA-256 mismatch (expected=$expectedSha256, got=$hex)');
          return null;
        }
        await promoteVerifiedFile(tmp, finalFile);
        return finalFile.path;
      } catch (e) {
        // Transient network failure mid-stream: keep the partial file so
        // the next attempt resumes from where this one stopped.
        try {
          converter.close();
        } catch (_) {}
        try {
          await sink.close();
        } catch (_) {}
        NoctraLogger.w('APK download interrupted (resumable): $e');
        return null;
      }
    }
    NoctraLogger.w('APK download exceeded max redirects');
    await _cleanupPartial(tmp, sink);
    return null;
  }

  Future<bool> _hashExistingPart(
    File tmp,
    int startOffset,
    DigestAccumulator accumulator,
    ByteConversionSink converter,
  ) async {
    try {
      var bytes = 0;
      await for (final chunk in tmp.openRead()) {
        converter.add(chunk);
        bytes += chunk.length;
      }
      return bytes == startOffset;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _verifyAndPromote(
    File tmp,
    File finalFile,
    String expectedSha256,
    ByteConversionSink converter,
    DigestAccumulator accumulator, {
    required DateTime deadline,
  }) async {
    if (deadline.isBefore(DateTime.now())) {
      NoctraLogger.w('APK download timed out during verification');
      return null;
    }
    try {
      converter.close();
    } catch (_) {}
    final hex = accumulator.digests.single.toString();
    if (hex.toLowerCase() != expectedSha256.toLowerCase()) {
      await _deleteFile(tmp);
      NoctraLogger.w('APK SHA-256 mismatch on resumed part');
      return null;
    }
    try {
      await promoteVerifiedFile(tmp, finalFile);
      return finalFile.path;
    } catch (e) {
      NoctraLogger.w('APK promote failed: $e');
      return null;
    }
  }

  int? _fullSizeFromContentRange(
      HttpClientResponse resp, int startOffset) {
    final cr = resp.headers.value(HttpHeaders.contentRangeHeader);
    if (cr == null) {
      final declared = resp.contentLength;
      if (declared < 0) return null;
      return startOffset + declared;
    }
    final m = RegExp(r'bytes\s+\d+-\d+/(\d+)').firstMatch(cr);
    if (m == null) return null;
    final total = int.tryParse(m.group(1)!);
    if (total == null || total <= 0) return null;
    return total;
  }

  Future<void> _cleanupPartial(File tmp, IOSink sink) async {
    try {
      await sink.close();
    } catch (_) {}
    await _deleteFile(tmp);
  }

  Future<void> _deleteFile(File f) async {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Future<void> _drainQuietly(HttpClientResponse resp) async {
    try {
      await for (final _ in resp) {}
    } catch (_) {}
  }
}
