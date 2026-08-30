# Changelog

All notable changes to the Noctra platform are documented in this file.

## [1.0.0-RELEASE] - 2026-08-30

### Added
- **Multi-Source Audio Streaming Engine**:
  - Integrated JioSaavn 320kbps CD-quality lossless direct streaming with native DES stream decryptor.
  - Added YouTube Music InnerTube direct REST extractor using `ANDROID_MUSIC` protocol for high-bitrate adaptive Opus/AAC playback with zero sidecar dependencies.
  - Added full fallback support via YouTube Explode and local offline music library scanner.
- **AutoMix & Playback Enhancements**:
  - Implemented AutoMix radio queue automatically pulling related tracks from YouTube Music when the queue finishes.
  - Added Sleep Timer in preferences (15m, 30m, 45m, 60m) with exponential volume fade-out.
  - Added SponsorBlock integration automatically skipping non-music talking intros, skits, and video silences.
  - Added typeahead search autocomplete returning query suggestions in under 30ms.
- **Multi-Engine Synced Lyrics Pipeline**:
  - 5-tier lyrics resolution: Lrclib millisecond-synced LRC, Lrclib fuzzy database search, YouTube Music InnerTube official verified distributor lyrics, JioSaavn native regional master lyrics, and Lyrics.ovh.
- **On-Device 16-Axis Neural Vector Recommendation**:
  - 16-dimensional acoustic feature space modeling Dark Tone, Energy, Melancholy, Chill Factor, and Analog Synth affinities.
  - Reinforcement learning reward shaping (+0.10 on full completion, -0.06 on fast skip, +0.16 on favorite).
  - Cosine similarity ranking and AI Radio curation.
- **Visualizers & Liquid Noir Themes**:
  - 32-Band Spectrum Bars with organic harmonic blending, smooth acoustic attack, and falling peak markers.
  - Radial Sound Glow and 3D Synthwave Grid visualizers.
  - Triple Theme Trinity: Noir Black (Obsidian Glass), Noir White (Minimal Editorial), and AMOLED (True `#000000` pitch black).
  - Dynamic Android app icon switching corresponding to the active theme.
  - Mini-Player swipe gestures: Swipe left/right to skip tracks and swipe up to open player sheet.
- **P2P SyncCast Jam Mode**:
  - Local decentralized WebSocket synchronization engine for zero-server party listening.

### Fixed
- Fixed 30-second preview clip issue by removing truncated preview URL bindings and enforcing full 320kbps resolution.
- Fixed Android launcher icon duplication by removing duplicate intent filters from the manifest.
- Fixed theme persistence on app relaunch.
- Fixed Spectrum Bars flat baseline bug with dynamic multi-band harmonic energy calculation.
- Added clickable developer profile, repository, and issue links via `url_launcher`.

### Security & Privacy
- Updated license to Personal Use & Restricted Inspection under Nomad Guy.
- Removed personal email and contact references.
