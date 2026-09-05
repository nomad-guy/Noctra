import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/noctra_logger.dart';

class StoryCardExporter {
  StoryCardExporter._();

  static const _channel = MethodChannel('com.nomadguy.noctra/update_notify');

  static Future<bool> shareStoryImage({
    required Uint8List bytes,
    required String title,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final folder = Directory('${tempDir.path}/story_cards');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final filename =
          'noctra_story_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${folder.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      final result = await _channel.invokeMethod<bool>('shareFile', {
        'filePath': file.path,
        'title': 'Share Story: $title',
        'mimeType': 'image/png',
      });
      return result ?? false;
    } catch (e) {
      NoctraLogger.w('Failed to export and share story card', e);
      return false;
    }
  }
}
