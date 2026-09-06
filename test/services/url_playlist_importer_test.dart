import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/migration/importers/url_playlist_importer.dart';

void main() {
  group('UrlPlaylistImporter', () {
    test('isPlaylistUrl correctly identifies supported URLs', () {
      expect(UrlPlaylistImporter.isPlaylistUrl('https://open.spotify.com/playlist/3uUsXbBtAYAXDXJbbMdUYN'), isTrue);
      expect(UrlPlaylistImporter.isPlaylistUrl('https://youtube.com/playlist?list=PLRxBzSTHBVbwX1DQa-AEfq73ZyuWM005u'), isTrue);
      expect(UrlPlaylistImporter.isPlaylistUrl('https://music.youtube.com/playlist?list=PLRxBzSTHBVbwX1DQa-AEfq73ZyuWM005u'), isTrue);
      expect(UrlPlaylistImporter.isPlaylistUrl('https://example.com/other'), isFalse);
    });

    test('importFromTracklistText parses tracklist lines properly', () {
      const text = '''
1. Song One - Artist A
2) Song Two by Artist B
Song Three – Artist C
Song Four
''';
      final playlist = UrlPlaylistImporter.importFromTracklistText(text, playlistName: 'Custom List');
      expect(playlist.name, 'Custom List');
      expect(playlist.tracks.length, 4);
      expect(playlist.tracks[0].title, 'Song One');
      expect(playlist.tracks[0].artist, 'Artist A');
      expect(playlist.tracks[1].title, 'Song Two');
      expect(playlist.tracks[1].artist, 'Artist B');
      expect(playlist.tracks[2].title, 'Song Three');
      expect(playlist.tracks[2].artist, 'Artist C');
      expect(playlist.tracks[3].title, 'Song Four');
      expect(playlist.tracks[3].artist, 'Various Artists');
    });
  });
}
