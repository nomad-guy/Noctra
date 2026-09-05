import 'recommendation_intent.dart';

/// Sealed hierarchy of all legitimate voice and media commands that Noctra can process.
sealed class AssistantCommand {
  const AssistantCommand();
}

// ─── Playback Controls ──────────────────────────────────────────────────────

class PlayCommand extends AssistantCommand {
  const PlayCommand();
}

class PauseCommand extends AssistantCommand {
  const PauseCommand();
}

class ResumeCommand extends AssistantCommand {
  const ResumeCommand();
}

class StopCommand extends AssistantCommand {
  const StopCommand();
}

class NextCommand extends AssistantCommand {
  const NextCommand();
}

class PreviousCommand extends AssistantCommand {
  const PreviousCommand();
}

class SeekCommand extends AssistantCommand {
  final Duration position;
  const SeekCommand(this.position);
}

class FastForwardCommand extends AssistantCommand {
  final Duration offset;
  const FastForwardCommand([this.offset = const Duration(seconds: 15)]);
}

class RewindCommand extends AssistantCommand {
  final Duration offset;
  const RewindCommand([this.offset = const Duration(seconds: 15)]);
}

class SetPlaybackSpeedCommand extends AssistantCommand {
  final double speed;
  const SetPlaybackSpeedCommand(this.speed);
}

// ─── Shuffle & Repeat ───────────────────────────────────────────────────────

class SetShuffleCommand extends AssistantCommand {
  final bool enable;
  const SetShuffleCommand(this.enable);
}

class SetRepeatCommand extends AssistantCommand {
  final String mode; // 'off', 'all', 'one'
  const SetRepeatCommand(this.mode);
}

// ─── Search & Content Playback ──────────────────────────────────────────────

class SearchAndPlayCommand extends AssistantCommand {
  final String query;
  final Map<String, dynamic>? extras;
  const SearchAndPlayCommand(this.query, [this.extras]);
}

class PlayTrackCommand extends AssistantCommand {
  final String trackId;
  final String? title;
  final String? artist;
  const PlayTrackCommand(this.trackId, {this.title, this.artist});
}

class PlayArtistCommand extends AssistantCommand {
  final String artistName;
  const PlayArtistCommand(this.artistName);
}

class PlayAlbumCommand extends AssistantCommand {
  final String albumName;
  const PlayAlbumCommand(this.albumName);
}

class PlayPlaylistCommand extends AssistantCommand {
  final String playlistIdOrName;
  final bool shuffle;
  const PlayPlaylistCommand(this.playlistIdOrName, {this.shuffle = false});
}

class PlayRecommendationCommand extends AssistantCommand {
  final RecommendationIntent intent;
  const PlayRecommendationCommand(this.intent);
}

// ─── Queue Operations ───────────────────────────────────────────────────────

class AddToQueueCommand extends AssistantCommand {
  final String queryOrTrackId;
  const AddToQueueCommand(this.queryOrTrackId);
}

class PlayNextCommand extends AssistantCommand {
  final String queryOrTrackId;
  const PlayNextCommand(this.queryOrTrackId);
}

class RemoveFromQueueCommand extends AssistantCommand {
  final String trackId;
  const RemoveFromQueueCommand(this.trackId);
}

class ClearQueueCommand extends AssistantCommand {
  const ClearQueueCommand();
}

// ─── Library & Favorites ────────────────────────────────────────────────────

class AddFavoriteCommand extends AssistantCommand {
  final String? trackId;
  const AddFavoriteCommand([this.trackId]);
}

class RemoveFavoriteCommand extends AssistantCommand {
  final String? trackId;
  const RemoveFavoriteCommand([this.trackId]);
}

// ─── Theme Operations ───────────────────────────────────────────────────────

class ChangeThemeCommand extends AssistantCommand {
  final String themeName; // 'noir_black', 'noir_white', 'liquid_glass'
  const ChangeThemeCommand(this.themeName);
}
