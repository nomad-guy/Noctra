import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/core/utils/playback_settings_store.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/cache/search_disk_cache.dart';

void main() {
  group('SearchDiskCache', () {
    late Directory tmpDir;

    setUp(() {
      SearchDiskCache.resetForTesting();
      tmpDir = Directory.systemTemp.createTempSync('noctra_cache_test');
      SearchDiskCache.configure(tmpDir.path);
    });

    tearDown(() {
      SearchDiskCache.resetForTesting();
      tmpDir.deleteSync(recursive: true);
    });

    test('put then get returns persisted songs', () async {
      await SearchDiskCache.instance.put('all:believer', [
        _song('id1', 'Believer'),
        _song('id2', 'Thunder'),
      ]);
      final got = await SearchDiskCache.instance.get('all:believer');
      expect(got, isNotNull);
      expect(got!.length, 2);
      expect(got.first.title, 'Believer');
    });

    test('get misses for unknown key', () async {
      final got = await SearchDiskCache.instance.get('all:nothing');
      expect(got, isNull);
    });

    test('corrupt file is fault-isolated (starts clean)', () async {
      await SearchDiskCache.instance.put('all:x', [_song('a', 'A')]);
      // Wait for debounced flush, then corrupt the file.
      await Future<void>.delayed(const Duration(seconds: 4));
      final f = File('${tmpDir.path}/noctra_search_cache.json');
      expect(f.existsSync(), isTrue, reason: 'flush should have happened');
      f.writeAsStringSync('{not valid json!!');

      // New instance reads the corrupt file → clean state, no crash.
      SearchDiskCache.resetForTesting();
      SearchDiskCache.configure(tmpDir.path);
      final got = await SearchDiskCache.instance.get('all:x');
      expect(got, isNull);
    });

    test('stale entries rejected unless allowStale', () async {
      await SearchDiskCache.instance.put('all:old', [_song('a', 'A')]);
      await Future<void>.delayed(const Duration(seconds: 4));
      // Rewrite timestamp to 31 days ago (older than stale TTL).
      final f = File('${tmpDir.path}/noctra_search_cache.json');
      final data =
          const JsonDecoder().convert(f.readAsStringSync()) as Map;
      data['all:old']['ts'] =
          DateTime.now().millisecondsSinceEpoch - 31 * 24 * 3600 * 1000;
      f.writeAsStringSync(const JsonEncoder().convert(data));
      SearchDiskCache.resetForTesting();
      SearchDiskCache.configure(tmpDir.path);

      final stale = await SearchDiskCache.instance.get('all:old');
      expect(stale, isNull, reason: '31-day entry exceeds stale TTL');
    });

    test('clear removes everything', () async {
      await SearchDiskCache.instance.put('all:k', [_song('a', 'A')]);
      await SearchDiskCache.instance.clear();
      final got = await SearchDiskCache.instance.get('all:k');
      expect(got, isNull);
    });
  });

  group('PlaybackSettingsStore.homeSections', () {
    test('default visibility: shown unless in kDefaultHidden', () {
      final store = PlaybackSettingsStore.instance;
      expect(store.isHomeSectionVisible('trending'), isTrue);
      expect(store.isHomeSectionVisible('vibeChips'), isFalse);
    });

    test('setHomeSectionVisible persists and reads back', () {
      final store = PlaybackSettingsStore.instance;
      store.setHomeSectionVisible('charts', false);
      expect(store.isHomeSectionVisible('charts'), isFalse);
      store.setHomeSectionVisible('charts', true);
      expect(store.isHomeSectionVisible('charts'), isTrue);
      // Cleanup so other tests see defaults.
      store.setHomeSectionVisible('charts', true);
    });
  });
}

Song _song(String id, String title) => Song(
      id: id,
      title: title,
      artist: 'Test Artist',
      album: 'Test Album',
      duration: const Duration(milliseconds: 210000),
    );
