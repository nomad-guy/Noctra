import 'dart:async';
import '../../../shared/models/models.dart';
import '../domain/music_provider_contract.dart';

/// Test/Replacement provider implementing [MusicProviderContract].
/// Allows testing search, queue, and discovery without live network calls.
class FakeMusicProvider implements MusicProviderContract {
  @override
  final String providerId;

  @override
  final String displayName;

  final List<Song> cannedTracks;

  FakeMusicProvider({
    this.providerId = 'fake_provider',
    this.displayName = 'Mock Audio Source',
    List<Song>? tracks,
  }) : cannedTracks = tracks ?? _defaultMockTracks();

  @override
  Future<List<Song>> search(String query, {int limit = 20}) async {
    final lower = query.toLowerCase();
    final results = cannedTracks.where((t) {
      return t.title.toLowerCase().contains(lower) ||
          t.artist.toLowerCase().contains(lower);
    }).take(limit).toList();
    return results;
  }

  @override
  Future<List<Song>> getTrending({String? countryCode, int limit = 20}) async {
    return cannedTracks.take(limit).toList();
  }

  @override
  Future<List<Song>> getArtistTopTracks(String artistName, {int limit = 20}) async {
    final lower = artistName.toLowerCase();
    return cannedTracks
        .where((t) => t.artist.toLowerCase().contains(lower))
        .take(limit)
        .toList();
  }

  @override
  Future<Song?> getTrackDetails(String trackId) async {
    try {
      return cannedTracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return null;
    }
  }

  static List<Song> _defaultMockTracks() {
    return [
      Song(
        id: 'fake_1',
        title: 'Midnight Echo',
        artist: 'Noir Syndicate',
        duration: const Duration(seconds: 210),
        album: 'Cyber Dreams',
        streamUrl: 'https://example.com/stream1.mp3',
      ),
      Song(
        id: 'fake_2',
        title: 'Neon Skyline',
        artist: 'Noir Syndicate',
        duration: const Duration(seconds: 185),
        album: 'Cyber Dreams',
        streamUrl: 'https://example.com/stream2.mp3',
      ),
      Song(
        id: 'fake_3',
        title: 'Glass Horizon',
        artist: 'Liquid Pulse',
        duration: const Duration(seconds: 240),
        album: 'Aesthetic Chill',
        streamUrl: 'https://example.com/stream3.mp3',
      ),
    ];
  }
}
