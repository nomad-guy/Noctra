import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/features/library/infrastructure/local_media_scanner.dart';

void main() {
  group('LocalMediaScanner', () {
    test('supportedExtensions contains expected audio formats', () {
      expect(LocalMediaScanner.supportedExtensions, contains('.flac'));
      expect(LocalMediaScanner.supportedExtensions, contains('.mp3'));
      expect(LocalMediaScanner.supportedExtensions, contains('.wav'));
      expect(LocalMediaScanner.supportedExtensions, contains('.m4a'));
    });

    test('parseAudioFile parses artist and title from standard naming conventions', () {
      final file = File('/music/Pink Floyd - Comfortably Numb.flac');
      final song = LocalMediaScanner.parseAudioFile(file);

      expect(song, isNotNull);
      expect(song!.artist, equals('Pink Floyd'));
      expect(song.title, equals('Comfortably Numb'));
      expect(song.genre, contains('Bit-Perfect Local Lossless'));
    });

    test('parseAudioFile strips track numbers from artist name', () {
      final file = File('/music/02. Queen - Bohemian Rhapsody.mp3');
      final song = LocalMediaScanner.parseAudioFile(file);

      expect(song, isNotNull);
      expect(song!.artist, equals('Queen'));
      expect(song.title, equals('Bohemian Rhapsody'));
      expect(song.genre, contains('Local Audio (MP3)'));
    });
  });
}
