import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural regression tests for the Phase 6 UI rebuild-scope fixes.
///
/// These read the production sources to lock the *scope boundary* of
/// position-driven playback state. The design rule they enforce:
///
///   Position ticks (~5/s) must only rebuild the small seek widgets that
///   display them — never whole screens/cards/lists. Playback streams that
///   emit rarely (currentSong, isPlaying, theme) may stay at roots.
void main() {
  final root = Directory.current.path;

  String read(String rel) => File('$root/$rel').readAsStringSync();

  test('mini player root does not watch the position stream', () {
    final src = read('lib/ui/widgets/noir_mini_player.dart');
    // The card-level widget (song identity + theme only) and its state class
    // must not subscribe to per-tick position state.
    final viewClass = _classSource(src, 'class NoirMiniPlayerView');
    expect(
      viewClass.contains('watch(positionStreamProvider)'),
      isFalse,
      reason: 'NoirMiniPlayerView rebuilds on every position tick',
    );
    final viewStateClass = _classSource(src, 'class _NoirMiniPlayerViewState');
    expect(
      viewStateClass.contains('watch(positionStreamProvider)'),
      isFalse,
      reason: '_NoirMiniPlayerViewState rebuilds on every position tick',
    );
    // The only position watcher left is the extracted seek area.
    final seekArea = _classSource(src, 'class _MiniSeekAreaState');
    expect(
      seekArea.contains('watch(positionStreamProvider)'),
      isTrue,
      reason: '_MiniSeekAreaState should own the position watch so the rest of '
          'the mini player stays stable between ticks',
    );
  });

  test('player sheet root does not watch the position stream', () {
    final src = read('lib/ui/screens/player_sheet.dart');
    final build = _methodSource(src, 'PlayerSheet', 'Widget build');
    expect(
      build.contains('watch(positionStreamProvider)'),
      isFalse,
      reason:
          'PlayerSheet rebuilds the whole modal (hero/artwork/lyrics) on every '
          'position tick',
    );
  });

  test('seek progress owns position watch inside player controls', () {
    final src = read('lib/ui/widgets/player_controls_section.dart');
    final sectionBuild = _methodSource(
      src,
      'PlayerControlsSection',
      'Widget build',
    );
    expect(
      sectionBuild.contains('watch(positionStreamProvider)'),
      isFalse,
      reason: 'control buttons/volume row should not rebuild on position ticks',
    );
    final seekProgress = _classSource(src, 'class _SeekProgressState');
    expect(
      seekProgress.contains('watch(positionStreamProvider)'),
      isTrue,
      reason: 'the extracted seek slider should own the position watch',
    );
  });

  test('library all-songs tab does not rebuild the whole list on playback', () {
    final src = read('lib/ui/widgets/library_all_songs_tab.dart');
    final tabBuild = _methodSource(src, 'LibraryAllSongsTab', 'Widget build');
    expect(
      tabBuild.contains('watch(currentSongStreamProvider)'),
      isFalse,
      reason:
          'LibraryAllSongsTab rebuilds its full sliver + displaySongs merge '
          'on track change',
    );
    expect(
      tabBuild.contains('watch(isPlayingStreamProvider)'),
      isFalse,
      reason: 'LibraryAllSongsTab rebuilds its full sliver on play/pause',
    );
    // Playback state is consumed per-row so only visible rows rebuild.
    final rowSrc = read('lib/ui/widgets/library/library_song_row.dart');
    final rowClass = _classSource(rowSrc, 'class LibrarySongRow');
    expect(
      rowClass.contains('watch(currentSongStreamProvider)'),
      isTrue,
      reason: 'row highlight must still react to the current song',
    );
  });

  test('lyrics view does not rebuild the lyric list on every position tick',
      () {
    final src = read('lib/ui/widgets/lyrics_view.dart');
    final stateClass = _classSource(src, 'class _LyricsViewState');
    expect(
      stateClass.contains('watch(positionStreamProvider)'),
      isFalse,
      reason:
          'LyricsView rebuilds transliteration output + ShaderMask on every '
          'position tick; the subscription must gate rebuilds on active-index '
          'changes instead',
    );
    expect(
      stateClass.contains('_positionSub'),
      isTrue,
      reason: 'active-line tracking should run through a position subscription',
    );
  });
}

/// Extracts the text of a top-level (or nested) class/mixin whose declaration
/// starts with [classStart] (e.g. `class _FooState extends ...`) up to the
/// line that closes it at brace-depth zero relative to the class body.
String _classSource(String file, String classStart) {
  final decl = file.indexOf(classStart);
  if (decl < 0) {
    fail('Could not find "$classStart" in source');
  }
  final open = file.indexOf('{', decl);
  var depth = 0;
  for (var i = open; i < file.length; i++) {
    if (file[i] == '{') depth++;
    if (file[i] == '}') {
      depth--;
      if (depth == 0) return file.substring(decl, i + 1);
    }
  }
  fail('Could not find closing brace for "$classStart"');
}

/// Extracts the text of a method inside a class: finds [methodSignature]
/// (e.g. `Widget build`) after [classStart] and returns up to the matching
/// closing brace.
String _methodSource(String file, String classStart, String methodSignature) {
  final cls = _classSource(file, classStart);
  final idx = cls.indexOf(methodSignature);
  if (idx < 0) {
    fail('Could not find "$methodSignature" in "$classStart"');
  }
  // Find the signature's closing paren + opening brace.
  final open = cls.indexOf('{', idx);
  var depth = 0;
  for (var i = open; i < cls.length; i++) {
    if (cls[i] == '{') depth++;
    if (cls[i] == '}') {
      depth--;
      if (depth == 0) return cls.substring(idx, i + 1);
    }
  }
  fail('Could not find closing brace for "$methodSignature"');
}
