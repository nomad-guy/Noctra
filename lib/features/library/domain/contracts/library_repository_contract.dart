import '../../../../data/models/song_model.dart';

/// Pure domain contract for the library subsystem.
/// Decouples feature UI and domain workflows from concrete persistence implementations.
abstract class LibraryRepositoryContract {
  /// Returns all songs currently saved in the local library.
  List<Song> get localLibrary;

  /// Returns all songs flagged as favorite.
  List<Song> get favorites;

  /// Returns the history of recently played songs.
  List<Song> get recentlyPlayed;

  /// Checks whether a song is marked as a favorite.
  bool isFavorite(String songId);

  /// Toggles favorite status for [song] with immediate local persistence.
  Future<void> toggleFavorite(Song song);

  /// Records a playback event in recently played history.
  Future<void> addToRecentlyPlayed(Song song);

  /// Refreshes and loads the library state from persistent storage.
  Future<void> init();
}
