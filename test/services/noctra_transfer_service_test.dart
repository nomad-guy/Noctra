import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/data/models/song_model.dart';
import 'package:noctra/services/migration/noctra_transfer_service.dart';

void main() {
  group('NoctraTransferService Tests', () {
    final sampleSongs = [
      Song(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        album: 'Whenever You Need Somebody',
        duration: const Duration(seconds: 213),
        artworkUrl: 'https://example.com/rick.jpg',
        genre: 'Pop',
      ),
      Song(
        id: 'kXYiU_JCYtU',
        title: 'Numb',
        artist: 'Linkin Park',
        album: 'Meteora',
        duration: const Duration(seconds: 187),
        genre: 'Rock',
      ),
    ];

    test('exportPlaylistToJson creates valid Noctra Manifest JSON', () {
      final jsonStr = NoctraTransferService.exportPlaylistToJson(
        'My Test Mix',
        sampleSongs,
      );

      expect(jsonStr.contains('noctra_manifest'), isTrue);
      expect(jsonStr.contains('My Test Mix'), isTrue);
      expect(jsonStr.contains('Rick Astley'), isTrue);
      expect(jsonStr.contains('Linkin Park'), isTrue);

      final parsed = NoctraTransferService.parseManifest(jsonStr);
      expect(parsed, isNotNull);
      expect(parsed!.type, 'playlist');
      expect(parsed.title, 'My Test Mix');
      expect(parsed.tracks.length, 2);
      expect(parsed.tracks[0].title, 'Never Gonna Give You Up');
      expect(parsed.tracks[0].artist, 'Rick Astley');
      expect(parsed.tracks[0].duration.inSeconds, 213);
      expect(parsed.tracks[1].title, 'Numb');
    });

    test('exportPlaylistToCsv creates standard CSV and parses back accurately', () {
      final csvStr = NoctraTransferService.exportPlaylistToCsv(
        'Rock & Pop',
        sampleSongs,
      );

      expect(csvStr.contains('Title,Artist,Album'), isTrue);
      expect(csvStr.contains('Never Gonna Give You Up,Rick Astley'), isTrue);

      final parsed = NoctraTransferService.parseManifest(csvStr);
      expect(parsed, isNotNull);
      expect(parsed!.type, 'playlist');
      expect(parsed.tracks.length, 2);
      expect(parsed.tracks[0].title, 'Never Gonna Give You Up');
      expect(parsed.tracks[1].artist, 'Linkin Park');
    });

    test('exportLibraryToJson exports custom folders and favorites', () {
      final jsonStr = NoctraTransferService.exportLibraryToJson(
        {'Workout': sampleSongs},
        [sampleSongs.first],
      );

      expect(jsonStr.contains('noctra_manifest'), isTrue);
      expect(jsonStr.contains('Workout'), isTrue);
      expect(jsonStr.contains('favoritesCount'), isTrue);

      final parsed = NoctraTransferService.parseManifest(jsonStr);
      expect(parsed, isNotNull);
      expect(parsed!.type, 'library');
      expect(parsed.folders, isNotNull);
      expect(parsed.folders!.containsKey('Workout'), isTrue);
      expect(parsed.folders!['Workout']!.length, 2);
    });

    test('parseManifest handles invalid or empty text gracefully', () {
      expect(NoctraTransferService.parseManifest(''), isNull);
      expect(NoctraTransferService.parseManifest('random unformatted text'), isNull);
      expect(NoctraTransferService.parseManifest('{"invalid": true}'), isNull);
    });
  });
}
