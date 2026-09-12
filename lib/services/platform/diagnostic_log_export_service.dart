import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/noctra_logger.dart';

/// Service-layer adapter that writes the diagnostic log (see
/// [NoctraLogger.buildLogText]) to a .txt file.
///
/// Lives in services/ because exporting touches the platform filesystem
/// (native save dialog via file_picker, app-documents fallback). core/ must
/// stay free of dart:io — enforced by the architecture boundary tests.
class DiagnosticLogExportService {
  DiagnosticLogExportService._();

  /// Exports the log buffer as a user-selected .txt file.
  ///
  /// Returns the path written, or null when the user cancelled the dialog or
  /// export is unavailable. Uses the native save dialog (desktop + Android
  /// SAF via file_picker); falls back to the app documents directory when
  /// the dialog is unsupported.
  static Future<String?> exportLogs() async {
    final content = NoctraLogger.buildLogText();
    final defaultName =
        'noctra-log-${DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19)}.txt';
    try {
      final result = await FilePicker.saveFile(
        fileName: defaultName,
        mimeType: 'text/plain',
        bytes: Uint8List.fromList(content.codeUnits),
      );
      if (result != null) {
        // On desktop `bytes` already wrote the file; on some platforms only
        // the path is returned, so persist explicitly when the file is empty.
        final path = result.scheme == 'file'
            ? result.toFilePath()
            : result.toString();
        final f = File(path);
        if (!f.existsSync() || f.lengthSync() == 0) {
          await f.writeAsString(content);
        }
        NoctraLogger.i('Diagnostic log exported to $path');
        return path;
      }
      return null; // user cancelled
    } catch (_) {
      // Fallback: write into the app documents directory.
      try {
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/$defaultName');
        await f.writeAsString(content);
        NoctraLogger.i('Diagnostic log exported to ${f.path}');
        return f.path;
      } catch (e) {
        NoctraLogger.w('Diagnostic log export failed', e);
        return null;
      }
    }
  }
}
