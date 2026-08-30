import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

class MusicStorageService {
  static Future<void> saveState({
    required List<double> tasteVector,
    required List<Song> downloads,
    required List<Song> recentlyPlayed,
    required Map<String, List<Song>> customFolders,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('noctra_taste_vector', jsonEncode(tasteVector));
      await prefs.setString('noctra_downloads', jsonEncode(downloads.map((e) => e.toMap()).toList()));
      await prefs.setString('noctra_recently_played', jsonEncode(recentlyPlayed.take(20).map((e) => e.toMap()).toList()));

      final foldersMap = <String, dynamic>{};
      customFolders.forEach((k, v) {
        foldersMap[k] = v.map((s) => s.toMap()).toList();
      });
      await prefs.setString('noctra_custom_folders', jsonEncode(foldersMap));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadState() async {
    final result = <String, dynamic>{};
    try {
      final prefs = await SharedPreferences.getInstance();

      final tasteJson = prefs.getString('noctra_taste_vector');
      if (tasteJson != null) {
        final decoded = jsonDecode(tasteJson) as List?;
        if (decoded != null && decoded.length == 16) {
          result['tasteVector'] = decoded.map((e) => (e as num).toDouble()).toList();
        }
      }

      final downloadsJson = prefs.getString('noctra_downloads');
      if (downloadsJson != null) {
        final decoded = jsonDecode(downloadsJson) as List?;
        if (decoded != null) {
          result['downloads'] = decoded.map((item) => Song.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      }

      final recentJson = prefs.getString('noctra_recently_played');
      if (recentJson != null) {
        final decoded = jsonDecode(recentJson) as List?;
        if (decoded != null) {
          result['recentlyPlayed'] = decoded.map((item) => Song.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      }

      final foldersJson = prefs.getString('noctra_custom_folders');
      if (foldersJson != null) {
        final decoded = jsonDecode(foldersJson) as Map<String, dynamic>?;
        if (decoded != null) {
          final customFolders = <String, List<Song>>{};
          decoded.forEach((key, val) {
            if (val is List) {
              customFolders[key] = val.map((s) => Song.fromMap(Map<String, dynamic>.from(s))).toList();
            }
          });
          result['customFolders'] = customFolders;
        }
      }
    } catch (_) {}
    return result;
  }
}
