import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/song_model.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/ai/ai_mix_track_source.dart';
import '../noir_mini_player_dock.dart';
import 'ai_collection_action_bar.dart';
import 'ai_collection_song_row.dart';

/// Loader seam for tests: returns the tracks to show for a vibe. The default
/// resolves through [AiMixTrackSource] (local-first curation + bounded feed).
typedef AiTracksLoader = Future<List<Song>> Function(String vibeKey,
    {List<String>? previousIds, int? epoch});

/// Full-screen view opened from the Library AI tab for an AI folder or AI
/// mix. Shows the resolved contents, lets the user Play All / open a song
/// (queue = the collection), add rows to the queue, and — for generated
/// vibes — Remix the collection into a fresh deterministic arrangement.
class AiCollectionDetailView extends ConsumerStatefulWidget {
  final bool isDark;
  final MusicRepository repo;
  final String title;
  final String? subtitle;
  final String? artworkUrl;
  final IconData? icon;
  final String vibeKey;
  final List<Song> initialTracks;
  final AiTracksLoader? loader;

  const AiCollectionDetailView({
    super.key,
    required this.isDark,
    required this.repo,
    required this.title,
    required this.vibeKey,
    this.subtitle,
    this.artworkUrl,
    this.icon,
    this.initialTracks = const [],
    this.loader,
  });

  @override
  ConsumerState<AiCollectionDetailView> createState() =>
      _AiCollectionDetailViewState();
}

class _AiCollectionDetailViewState
    extends ConsumerState<AiCollectionDetailView> {
  List<Song> _tracks = [];
  bool _busy = false;
  String? _error;
  int _epoch = 0;
  List<String> _previousIds = const [];

  // Once the pool has been resolved (from curated local tracks or a bounded
  // network feed), remixing re-orders the SAME pool in place. A network
  // round-trip per remix tap would make every refresh wait on the network.
  List<Song>? _resolvedPool;

  bool get _canRemix =>
      widget.vibeKey != 'favorites' && widget.vibeKey != 'downloads';

  @override
  void initState() {
    super.initState();
    _tracks = List<Song>.of(widget.initialTracks);
    if (_tracks.isEmpty) _load();
  }

  /// Resolves the collection pool (initial open, retry). The source is
  /// local-first, so an open does not wait on the network when the user's
  /// library already has matching tracks.
  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loader = widget.loader ?? _defaultLoader;
      final result = await loader(widget.vibeKey,
          previousIds: const [], epoch: 0);
      if (!mounted) return;
      setState(() {
        _resolvedPool = result;
        _tracks = result;
        _previousIds = const [];
        _epoch = 0;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not load this collection right now.';
      });
    }
  }

  /// Remix re-orders the already-resolved pool deterministically. When the
  /// open used preloaded tracks (mix opened from the Library with a full
  /// track list) there is no resolved pool, so a fresh resolution runs.
  void _remix() {
    if (_busy || !_canRemix) return;
    _previousIds = _tracks.map((s) => s.id).toList();
    _epoch++;
    final pool = _resolvedPool;
    if (pool != null && pool.length >= 2) {
      setState(() {
        _tracks = AiMixTrackSource.applyRemixOrder(pool,
            previousIds: _previousIds, epoch: _epoch, vibeKey: widget.vibeKey);
      });
      return;
    }
    _load();
  }

  Future<List<Song>> _defaultLoader(String vibeKey,
      {List<String>? previousIds, int? epoch}) {
    return AiMixTrackSource.resolveTracks(widget.repo, vibeKey: vibeKey);
  }

  void _playAll() {
    if (_tracks.isEmpty || _busy) return;
    ref
        .read(audioPlayerServiceProvider)
        .playSong(_tracks.first, newQueue: List<Song>.of(_tracks));
  }

  void _playFrom(int index) {
    final queue = List<Song>.of(_tracks);
    final start = queue.removeAt(index);
    ref.read(audioPlayerServiceProvider).playSong(start, newQueue: queue);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _header(isDark, textPrimary, textSecondary),
                AiCollectionActionBar(
                  isDark: isDark,
                  canRemix: _canRemix,
                  busy: _busy,
                  hasTracks: _tracks.isNotEmpty,
                  onPlayAll: _playAll,
                  onRemix: _remix,
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(isDark, textSecondary)),
              ],
            ),
          ),
          // Floating mini-player dock (this page is pushed over the shell).
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerDock(),
          ),
        ],
      ),
    );
  }

  Widget _header(bool isDark, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textPrimary)),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                  Text(widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, Color textSecondary) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 34, color: textSecondary),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_busy && _tracks.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              'Nothing here yet. Play a few songs and this collection will build itself.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary)),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 200),
      itemCount: _tracks.length,
      itemBuilder: (context, i) {
        final song = _tracks[i];
        return AiCollectionSongRow(
          isDark: isDark,
          song: song,
          onTap: () => _playFrom(i),
        );
      },
    );
  }
}
