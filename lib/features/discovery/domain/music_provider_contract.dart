import 'dart:async';
import '../../../shared/models/models.dart';

/// Contract for music data providers (JioSaavn, YouTube Music, Local, Fake, etc.)
abstract class MusicProviderContract {
  String get providerId;
  String get displayName;

  Future<List<Song>> search(String query, {int limit = 20});

  Future<List<Song>> getTrending({String? countryCode, int limit = 20});

  Future<List<Song>> getArtistTopTracks(String artistName, {int limit = 20});

  Future<Song?> getTrackDetails(String trackId);
}
