import 'package:flutter/material.dart';
import 'noir_mini_player.dart';

/// Bottom mini-player dock used by pushed full-screen content pages
/// (artist profiles, library/AI collection details, ...) that sit on top
/// of the tabbed shell and therefore cannot see the shell's own dock.
///
/// The dock renders nothing until a song is active (NoirMiniPlayer hides
/// itself), so pages are safe to include it unconditionally. Modal sheets
/// opened from the page still appear above it, preserving the normal
/// mini-player → full-player layering.
class MiniPlayerDock extends StatelessWidget {
  const MiniPlayerDock({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(top: 4, bottom: 2),
        child: NoirMiniPlayer(),
      ),
    );
  }
}
