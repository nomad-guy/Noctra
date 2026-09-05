import 'dart:math';
import '../../data/models/song_model.dart';
import '../../data/repositories/music_repository.dart';
import '../ytdlp/music_service.dart';

/// Resolves real, playable tracks for an AI-generated mix or AI folder, and
/// produces deterministic "remixes" of a vibe so a generated collection can
/// be refreshed without repeating the exact previous order.
///
/// Background: AI folders/mixes were driven by their vibe key alone. The
/// always-present "Favorites"/"Downloads" folders went straight to a network
/// "vibe feed" search (so they silently played the wrong thing or nothing,
/// and were dead offline), and every mix that had no locally curated tracks
/// did an 8s network wait that could end in a silent no-op. This source makes
/// each tap deterministic:
///
///  * `favorites` → the user's actual favorites (local, offline-safe)
///  * `downloads` → the user's actual downloads (local, offline-safe)
///  * any other vibe → bounded network vibe feed first, then a local
///    taste-vector curation fallback, so something plays whenever the device
///    has any matching library at all (empty only when truly nothing exists).
class AiMixTrackSource {
  AiMixTrackSource._();

  /// Upper bound for the network vibe-feed fetch; a slow network must fail
  /// over to local curation instead of leaving the UI waiting.
  static const Duration feedTimeout = Duration(seconds: 6);

  /// Short bound used for the instant-open fast path below.
  static const Duration fastLocalTimeout = Duration(milliseconds: 400);

  static Future<List<Song>> resolveTracks(
    MusicRepository repo, {
    required String vibeKey,
    Future<List<Song>> Function(String vibeKey)? feedFetcher,
  }) {
    return resolveFrom(
      favorites: repo.favorites,
      downloads: repo.downloads,
      localCurator: (vk) => repo
          .curateByVibe(vibeKey: vk)
          .map((e) => e['song'] as Song)
          .where((s) => s.id.isNotEmpty)
          .toList(),
      vibeKey: vibeKey,
      feedFetcher: feedFetcher,
    );
  }

  /// Remix variant: resolves the same pool as [resolveTracks] but re-orders
  /// it deterministically from [epoch] and [previousIds], so an "Remix" tap
  /// on an open AI folder/mix surfaces a fresh arrangement (and prefers
  /// tracks that were NOT in the previous arrangement).
  static Future<List<Song>> resolveRemix(
    MusicRepository repo, {
    required String vibeKey,
    List<String> previousIds = const [],
    int epoch = 0,
    Future<List<Song>> Function(String vibeKey)? feedFetcher,
  }) async {
    final pool = await resolveTracks(repo, vibeKey: vibeKey, feedFetcher: feedFetcher);
    return applyRemixOrder(pool,
        previousIds: previousIds, epoch: epoch, vibeKey: vibeKey);
  }

  /// Pure core (no repository), so deterministic tests can pin the exact
  /// resolution rules without persistence or platform channels.
  ///
  /// Ordering matters for perceived reliability: a vibe folder must OPEN
  /// with the user's own library picks the moment it can, not after a
  /// network round-trip. Local curation therefore runs first and wins when
  /// it finds tracks; the network vibe feed only runs when the device has
  /// nothing matching locally (cold start / discovery). The feed is still
  /// bounded by [feedTimeout] so it can never hang an open.
  static Future<List<Song>> resolveFrom({
    required List<Song> favorites,
    required List<Song> downloads,
    required List<Song> Function(String vibeKey) localCurator,
    required String vibeKey,
    Future<List<Song>> Function(String vibeKey)? feedFetcher,
  }) async {
    if (vibeKey == 'favorites') return favorites;
    if (vibeKey == 'downloads') return downloads;

    // Instant path: the user's library already has matching tracks.
    try {
      final local = localCurator(vibeKey);
      if (local.isNotEmpty) return local;
    } catch (_) {
      // Fall through to the network feed.
    }

    final fetch = feedFetcher ?? MusicService.fetchVibeFeed;
    List<Song>? feed;
    try {
      feed = await fetch(vibeKey).timeout(feedTimeout);
    } catch (_) {
      feed = null;
    }
    if (feed != null && feed.isNotEmpty) return feed;
    return localCurator(vibeKey);
  }

  /// Deterministic remix ordering. Keeps tracks that were NOT in the
  /// previous arrangement first, shuffles both groups from a seed derived
  /// from the vibe + epoch, then rotates the combined list by [epoch] so a
  /// pool that fully repeats still shifts position between remixes. Pure and
  /// reproducible for the same inputs — ideal for tests.
  static List<Song> applyRemixOrder(
    List<Song> pool, {
    List<String> previousIds = const [],
    int epoch = 0,
    String vibeKey = '',
  }) {
    if (pool.length < 2) return List<Song>.of(pool);
    final seed = (vibeKey.hashCode ^ (epoch * 7919));
    final rnd = Random(seed);
    final fresh = pool.where((s) => !previousIds.contains(s.id)).toList()
      ..shuffle(rnd);
    final repeats = pool.where((s) => previousIds.contains(s.id)).toList()
      ..shuffle(rnd);
    final ordered = <Song>[...fresh, ...repeats];
    if (ordered.isEmpty) return ordered;
    final offset = epoch % ordered.length;
    return [...ordered.sublist(offset), ...ordered.sublist(0, offset)];
  }
}