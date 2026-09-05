import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'app_providers.dart';

final playbackSpeedStateProvider = StateProvider<double>((ref) => 1.0);

class PlaybackPreset {
  final String label;
  final double speed;
  final String description;

  const PlaybackPreset({
    required this.label,
    required this.speed,
    required this.description,
  });
}

const List<PlaybackPreset> kPlaybackSpeedPresets = [
  PlaybackPreset(
    label: 'Slowed',
    speed: 0.85,
    description: 'Slowed reverb nocturnal tempo',
  ),
  PlaybackPreset(
    label: 'Chill',
    speed: 0.90,
    description: 'Relaxed ambient listening',
  ),
  PlaybackPreset(
    label: 'Normal',
    speed: 1.0,
    description: 'Original master tempo',
  ),
  PlaybackPreset(
    label: 'Nightcore',
    speed: 1.25,
    description: 'High-energy accelerated pitch',
  ),
  PlaybackPreset(
    label: 'Fast',
    speed: 1.50,
    description: 'Rapid pace listening',
  ),
];

Future<void> setAppPlaybackSpeed(WidgetRef ref, double speed) async {
  HapticFeedback.selectionClick();
  final clamped = speed.clamp(0.25, 2.0);
  ref.read(playbackSpeedStateProvider.notifier).state = clamped;
  final audioPlayer = ref.read(audioPlayerServiceProvider);
  try {
    await audioPlayer.player.setSpeed(clamped);
  } catch (_) {}
}
