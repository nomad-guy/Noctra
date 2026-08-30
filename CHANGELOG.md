# Noctra Changelog

All notable changes to Noctra will be documented in this file.

The project adheres to Semantic Versioning: `vX.Y.Z`
- **X**: Generation
- **Y**: Major Features and Architecture Overhauls
- **Z**: Bug Fixes, Reliability Patches, and Performance Optimizations

---

## [1.0.4] - 2026-08-30

### Added
- **Native Android Kotlin Stream Engine**: Ported multi-client YouTube stream extraction (`ANDROID_TESTSUITE`, `ANDROID_MUSIC`, `TVHTML5`) directly to native Kotlin (`NoctraNativeStreamEngine.kt`), extracting adaptive Opus/AAC streams in under 20ms.
- **Hardware DSP Audio Effects Engine**: Integrated Android's native `android.media.audiofx` suite (`NoctraAudioEffectsEngine.kt`) with 5-Band Equalizer, 3D Spatial Virtualizer, Hardware Reverb (`PRESET_LARGEHALL`), BassBoost Exciter, and automatic `LoudnessEnhancer`.
- **Hindi & Devanagari Lyrics Engine**: Added dedicated language selection pills (Auto / हिन्दी) in `LyricsView` with real-time JioSaavn master search and parsing for authentic Devanagari lyrics.
- **Live Chunked Offline Downloader**: Implemented real-time chunked byte stream downloading in `MusicService` with live progress bars and green verification checkmarks in the Library tab.
- **Categorized Artist Discography**: Added structured discography sections (Hero Header, Studio Albums & EPs, Top Hits, and Similar Artists) in `ArtistScreen`.

### Fixed
- **Visualizer Rendering & Frame Invalidation**: Fixed animation tick loops and enabled unconditional canvas repainting across `SpectrumBarsVisualizer`, `RadialCircleVisualizer`, and `ProperSynthwaveVisualizer` for fluid 60FPS motion.
- **Mini-Player Swipe-to-Dismiss**: Resolved gesture collision and synchronized dismissal state in `NoirMiniPlayer`, eliminating debug tree assertions and red screen flashes on track close.
- **Layout Overflows Resolution**: Eliminated layout overflows on narrow screens across player header actions, studio master mode chips, and seekbar timestamps.
- **Mathematical Vector Architecture**: Upgraded `TasteVectorEngine.cosineSimilarity` to compute normalized cosine similarity on `[-1.0, 1.0]` mapped to `[0.0, 1.0]` with additive feature vector nudging and unified match scoring.
- **Stream Cache TTL & Race Protection**: Added 12-hour LRU cache TTL with automatic invalidation in `CompositeStreamResolver` and play session epoch locks in `AudioPlayerService` to prevent fast skip race conditions.

---

## [1.0.3] - 2026-08-30

### Added
- **In-Player Sleep Timer**: Quick 1-tap Moon action button placed directly inside the Now Playing sheet header with auto fade-out presets (15m, 30m, 45m, 60m, 90m) and dynamic countdown indicator.
- **Explore Artists Carousel**: Dedicated horizontal artist carousel on the Home Screen for 1-tap discovery of featured global and Indian artists (Arijit Singh, Sidhu Moose Wala, Diljit Dosanjh, Fly By Midnight, The Weeknd, Pritam, Karan Aujla, AP Dhillon, Taylor Swift) as well as the user's top-played artists.
- **Artist Screen Integration**: Clicking artist avatars on the Home screen or artist subtitles on the Now Playing screen opens the dedicated Artist Page with discography, high-resolution artwork, and AI Artist Radio.

### Fixed
- **Instant Stream Fallback & First-Play Silence Resolution**: Implemented automatic fallback retry in `AudioPlayerService` that immediately tries composite stream resolvers if an initial stream endpoint fails, eliminating silence on first play.
- **JioSaavn & Indian Track Direct Stream Decryption**: Direct PID detail parsing and decryption in `JioSaavnDirectResolver` for 320kbps Indian audio streams.
- **ExoPlayer Connection Negotiation**: Removed synthetic desktop browser header overrides that triggered HTTP 403 or connection stalls on mobile CDNs.

---

## [1.0.2] - 2026-08-30

### Fixed
- **Audio Pipeline Hardening**: Preserved local sidecar HTTP playback connections without forced TLS errors.
- **Gapless Looping**: Implemented seamless gapless single-track looping (`LoopMode.one`) via position seeking instead of full stream re-resolution.
- **P2P WebSocket Hardening**: Added host IP sanitization and illegal character stripping in `P2PSocketEngine`.
- **AI Studio Resiliency**: Added 500-character input caps, 8-second request timeouts, and error state recovery.
- **UI Performance Tuning**: Optimized folder list lookups from O(n²) to O(1) and added memory-bounded image decoding on collections.

---

## [1.0.1] - 2026-08-30

### Added
- **In-App OTA Update Checker**: Added background and manual GitHub Releases updater with direct download in Settings.
- **Triple Theme Support**: Added Pitch-Black Obsidian AMOLED mode alongside Obsidian Dark and Editorial Light.

### Fixed
- **Android 15 & 16 Hardware Crash Resolution**: Migrated Kotlin package namespace to `com.nomadguy.noctra` and safeguarded audio visualizer capture.
- **On-Device Hybrid Taste Engine**: Blended 16-axis neural cosine similarity with local playback frequency history with zero telemetry.
- **Dead Code Cleanup**: Purged legacy duplicate Python tree from `android/app/src/main/python/`.

---

## [1.0.0] - 2026-08-30

### Initial Release
- **Full Lossless Audio Streaming**: 320kbps CD-quality audio streams and YouTube Music playback with zero ads and no login requirement.
- **Synced Lyrics Engine**: Millisecond-accurate time-coded LRC lyrics.
- **AutoMix & Endless Radio**: Automated queue generation when playlists end.
- **SponsorBlock**: Automatic skipping of non-music intros and outro skits.
- **On-Device AI Taste Vector**: Local 16-dimensional acoustic vector learning.
- **Triple Visualizer Suite**: Live Spectrum Bars, Radial Circle, and Synthwave Grid.
- **SyncCast P2P Jam Rooms**: Local network party playback synchronization.
