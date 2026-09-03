part of '../noctra_local_database.dart';

extension LocalDatabaseDecoders on NoctraLocalDatabase {
  static List<Song> safeDecodeSongList(
      String? jsonStr, String key, SharedPreferences prefs) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) throw const FormatException('Expected List');
      final seen = <String, Set<String>>{};
      final list = <Song>[];
      for (final item in decoded) {
        if (item is Map) {
          try {
            final song = Song.fromMap(Map<String, dynamic>.from(item));
            if (song.title.isEmpty) continue;
            final effectiveId = song.id.isNotEmpty
                ? song.id
                : 'syn_${song.title.hashCode ^ song.artist.hashCode}';
            final dedupSong =
                song.id.isEmpty ? song.copyWith(id: effectiveId) : song;
            final contentKey = '${dedupSong.title}\u0000${dedupSong.artist}';
            final seenContent = seen.putIfAbsent(effectiveId, () => <String>{});
            if (seenContent.add(contentKey)) list.add(dedupSong);
          } catch (e) {
            NoctraLogger.w('Skipping corrupt song in list for $key', e);
          }
        }
      }
      return list;
    } catch (e) {
      NoctraLogger.w('Corrupted JSON detected for key $key; backing up', e);
      try {
        prefs.setString('${key}_corrupt_bak', jsonStr);
      } catch (_) {}
      prefs.remove(key);
      return [];
    }
  }

  static Map<String, List<Song>> safeDecodeCustomFolders(
      String? jsonStr, SharedPreferences prefs) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) throw const FormatException('Expected Map');
      final res = <String, List<Song>>{};
      int syntheticId = 0;
      decoded.forEach((rawK, v) {
        final k = rawK?.toString();
        if (k != null && k.isNotEmpty && v is List) {
          final seen = <String, Set<String>>{};
          final songs = <Song>[];
          for (final item in v) {
            if (item is Map) {
              try {
                final song = Song.fromMap(Map<String, dynamic>.from(item));
                if (song.title.isEmpty) continue;
                final effectiveId = song.id.isNotEmpty
                    ? song.id
                    : 'syn_f_${song.title.hashCode}_${syntheticId++}';
                final dedupSong =
                    song.id.isEmpty ? song.copyWith(id: effectiveId) : song;
                final contentKey =
                    '${dedupSong.title}\u0000${dedupSong.artist}';
                final seenContent =
                    seen.putIfAbsent(effectiveId, () => <String>{});
                if (seenContent.add(contentKey)) songs.add(dedupSong);
              } catch (e) {
                NoctraLogger.w('Skipping corrupt song in folder $k', e);
              }
            }
          }
          res[k] = songs;
        }
      });
      return res;
    } catch (e) {
      NoctraLogger.w(
          'Corrupted JSON detected for custom folders; backing up', e);
      try {
        prefs.setString('noctra_custom_folders_corrupt_bak', jsonStr);
      } catch (_) {}
      prefs.remove('noctra_custom_folders');
      return {};
    }
  }

  static List<double> safeDecodeTasteVector(
      String? jsonStr, SharedPreferences prefs) {
    final def = TasteVectorEngine.getDefaultVector();
    if (jsonStr == null || jsonStr.trim().isEmpty) return def;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) throw const FormatException('Expected List');
      final list = <double>[];
      for (final e in decoded) {
        if (e is num) {
          final val = e.toDouble();
          list.add(val.isNaN || val.isInfinite ? 0.5 : val.clamp(0.05, 0.95));
        } else {
          list.add(0.5);
        }
      }
      while (list.length < TasteVectorEngine.vectorDimension) {
        list.add(0.5);
      }
      return list.take(TasteVectorEngine.vectorDimension).toList();
    } catch (e) {
      NoctraLogger.w('Self-healing corrupted taste vector', e);
      try {
        prefs.setString('noctra_taste_vector_corrupt_bak', jsonStr);
      } catch (_) {}
      prefs.remove('noctra_taste_vector');
      return def;
    }
  }
}
