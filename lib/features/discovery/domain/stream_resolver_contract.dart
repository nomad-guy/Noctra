import 'dart:async';
import '../../../shared/models/models.dart';

/// Domain contract for resolving audio playback streams from various sources.
abstract class StreamResolverContract {
  String get sourceId;

  Future<bool> canResolve(Song song, {Duration? timeBudget});

  Future<String?> resolveStreamUrl(Song song, {Duration? timeBudget});
}
