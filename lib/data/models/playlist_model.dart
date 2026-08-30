import 'song_model.dart';

class AIPlaylist {
  final String id;
  final String title;
  final String subtitle;
  final String artworkUrl;
  final String vibeKey;
  final List<Song> tracks;

  const AIPlaylist({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
    required this.vibeKey,
    required this.tracks,
  });
}
