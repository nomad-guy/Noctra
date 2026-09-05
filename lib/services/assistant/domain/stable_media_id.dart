/// Stable URI scheme for Noctra's MediaBrowser content tree and Assistant routing.
/// Follows `noctra://<type>/<id>` format to guarantee persistence across app restarts.
class StableMediaId {
  static const String scheme = 'noctra';
  static const String rootId = 'noctra://root';
  static const String favoritesId = 'noctra://favorites';
  static const String downloadsId = 'noctra://downloads';
  static const String recentlyPlayedId = 'noctra://recently_played';
  static const String recommendationsId = 'noctra://recommendations';
  static const String playlistsId = 'noctra://playlists';
  static const String albumsId = 'noctra://albums';
  static const String artistsId = 'noctra://artists';

  final String type;
  final String? value;

  const StableMediaId({required this.type, this.value});

  static StableMediaId? parse(String? uriString) {
    if (uriString == null || uriString.isEmpty) return null;
    final uri = Uri.tryParse(uriString);
    if (uri == null || uri.scheme != scheme) {
      // Allow raw string fallbacks for simple keys
      if (uriString == 'root') return const StableMediaId(type: 'root');
      if (uriString == 'favorites') return const StableMediaId(type: 'favorites');
      if (uriString == 'downloads') return const StableMediaId(type: 'downloads');
      if (uriString == 'recently_played') return const StableMediaId(type: 'recently_played');
      if (uriString == 'recommendations') return const StableMediaId(type: 'recommendations');
      return null;
    }

    final host = uri.host;
    final pathSegments = uri.pathSegments;

    if (pathSegments.isEmpty) {
      return StableMediaId(type: host);
    }

    return StableMediaId(
      type: host,
      value: Uri.decodeComponent(pathSegments.first),
    );
  }

  static String forTrack(String trackId) =>
      '$scheme://track/${Uri.encodeComponent(trackId)}';

  static String forArtist(String artistName) =>
      '$scheme://artist/${Uri.encodeComponent(artistName)}';

  static String forAlbum(String albumName) =>
      '$scheme://album/${Uri.encodeComponent(albumName)}';

  static String forPlaylist(String playlistId) =>
      '$scheme://playlist/${Uri.encodeComponent(playlistId)}';

  @override
  String toString() {
    if (value == null || value!.isEmpty) {
      return '$scheme://$type';
    }
    return '$scheme://$type/${Uri.encodeComponent(value!)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StableMediaId &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value;

  @override
  int get hashCode => Object.hash(type, value);
}
