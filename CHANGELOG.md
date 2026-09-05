# Changelog

## v1.0.2 (2026-09-05)

### Features & Output Routing Hardening

This release introduces comprehensive offline playback control, dynamic audio DNA profiling, smart playback FX, swipe gesture queuing, shareable lyric story cards, universal playlist importing, updater rollback capabilities, and Bluetooth output router enhancements.

### In-App Rollback Architecture
- **Seamless Rollback Support**: Users can now easily roll back to previous stable versions directly from the In-App Update Sheet.
- **Rollback Manifest Tracking**: Cached fallback APK snapshots and SHA-256 digest validation prevent broken downgrade loops.

### Offline Mode ("Downloads Only" Mode)
- **One-Tap Offline Toggle**: Added dedicated offline switch on the Home Screen AppBar and Library screen.
- **Dynamic Content Fallback**: When active, Home Trending, Spotify Charts, and Live Vibe feeds automatically resolve to downloaded and local songs with zero network requests.

### Taste Radar & Audio DNA Profile Visualizer
- **Interactive Acoustic Radar**: Custom multi-polygon visualizer mapping 8 acoustic traits: Energy, Valence, Danceability, Acousticness, Instrumentalness, Tempo, Liveness, and Speechiness.
- **Acoustic Archetype Engine**: Classifies user listening habits into dynamic archetypes (e.g. Cyber Synth Architect, Melodic Architect, Nocturnal Dreamer).
- **Audio DNA Sheet**: Accessible from Music Preferences in Settings.

### Smart Playback Speed & Pitch FX
- **Granular Speed Slider**: Full 0.5x to 2.0x playback rate adjustment with pristine audio time-stretching.
- **Instant Preset Chips**: One-tap speed presets: Slowed (0.85x), Chill (0.90x), Normal (1.0x), Nightcore (1.25x), and Fast (1.50x).
- **Player Quick Menu**: Speed & Pitch FX action sheet accessible directly from the player header.

### Swipeable List Gesture Actions
- **Swipe to Play Next**: Swipe track right (Cyan) to insert immediately behind the active song.
- **Swipe to Add to Queue**: Swipe track left (Amber) to append to the end of the current play queue.
- **Tactile Haptic Triggers**: Native haptic feedback on swipe thresholds across Library Songs and Search Results.

### Shareable Song & Lyric Story Cards
- **9:16 Story Card Generator**: Export high-resolution, beautifully styled music story cards for Instagram, Telegram, and WhatsApp stories.
- **5 Dynamic Visual Themes**: Noir Black, Liquid Glass, Amber Glow, Neon Cyber, and Velvet Rose.
- **Native Android Share Intent**: Zero external dependencies; shares directly using Android's native `FileProvider` and chooser sheet.

### Universal Playlist URL Importer
- **Multi-Platform Support**: Directly import Spotify public playlists, YouTube playlists, or plaintext tracklists ("Song - Artist").
- **Automatic Matching**: Resolves metadata and saves songs into custom library folders seamlessly.

### Bluetooth & Output Router Hardening
- **Android 12+ Permission Resolution**: Prompts for `BLUETOOTH_CONNECT` runtime permissions so connected Bluetooth headphones/speakers are reliably enumerated.
- **Accurate Active Sink Detection**: Dynamic priority heuristics for Communication Device -> Bluetooth A2DP -> Wired AUX -> Phone Speaker.
- **Samsung Dual Audio Integration**: Direct launch of Samsung One UI QuickBoard Media Output panel for concurrent dual Bluetooth streaming.

---

## v1.0.1 (2026-09-05)

### Complete System-Wide Localization & Voice Integration Foundation

This release brings comprehensive, production-grade system-wide localization across all 8 supported languages with 100% 1:1 key parity, dynamic runtime reactivity without app restarts, and external voice assistant controller hardening.

### System-Wide Localization Architecture
- **8 Fully Supported Languages**: Complete dictionary parity across English (`en`), Hindi (`hi`), Punjabi (`pa`), Urdu (`ur`), Kannada (`kn`), Tamil (`ta`), Marathi (`mr`), and Odia (`or`).
- **Reactive Localization Scope**: Upgraded `LocalizationContextX.tr(key, [args])` to support clean positional parameter interpolation (`context.tr(L10nKeys.key, {'param': 'val'})`) and instant reactive updates across the widget tree via `NoctraLocalizationScope`.
- **Zero-Emoji Compliance**: Verified all dictionaries and localized user-facing strings strictly adhere to professional typographic standards with zero emojis.
- **Bi-Directional Script & RTL Support**: Native Right-To-Left layout mirroring and bidirectional text flow for Urdu (`ur`) using `NoctraLocalization.isRtl`.

### UI & Bottom Sheet Internationalization
- **Media Controls & Mini Player**: Fully localized track titles, durations, codec badges, audio visualizers, and playback actions.
- **Audio Output & Sleep Timer**: Localized device casting targets, sleep timer durations, auto-pause descriptions, and state toasts.
- **Jam Studio & P2P SyncCast**: Complete localization for room codes, host controls, real-time sync status, chat, and queue operations.
- **Library & Search Catalogs**: Localized genre chips, AI mixes, folders management, catalog status messages, and dynamic search prompts.
- **Equalizer & Audio Stems**: Localized preset names, frequency band controls, neural stem separation progress, and vocal isolation labels.
- **In-App Updater & Settings**: Fully localized update prompts, release version comparison labels, action buttons, and storage management tools.

### Android Voice Assistant Hardening
- **MediaSession Voice Integration**: Strengthened Android `MediaSession` external controller callbacks allowing Google Assistant and Gemini to control playback, volume, skipping, and track metadata querying.
- **App Actions Capabilities**: Validated `shortcuts.xml` declarations for `actions.intent.PLAY_MUSIC` and `actions.intent.OPEN_APP_FEATURE`.

### Architecture & Verification
- **Strict <= 300 LOC Invariant**: Maintained 100% compliance across all Dart and Kotlin source files.
- **Clean Static Analysis**: 0 warnings and 0 errors across the entire repository with `flutter analyze`.
- **Comprehensive Automated Test Coverage**: All test suites passing including key parity verification and release manifest integrity.

---

## v1.0.0 (2026-09-05)

### Stable Signed Production Release

This is the official stable signed production release of Noctra, built with release signing keys, shipped as per-ABI and universal APKs with cryptographic checksum verification and machine-readable update manifests.

### Adaptive Dual-Engine Audio Effects Architecture
- **DynamicsProcessing Engine (API 28+)**: Implemented `NoctraDynamicsProcessor` utilizing zero-latency time-domain IIR filters (`VARIANT_FAVOR_TIME_RESOLUTION`), 10-band PreEq, and an integrated studio output limiter (-0.5 dBFS threshold).
- **Universal OEM Compatibility & Graceful Fallback**: Implemented `NoctraAudioEffectsEngine` with strict mutual exclusivity. Automatically probes dynamics processing capability; if the device audio HAL rejects custom parameters (e.g. Realme/Oplus returning bad parameter value in `AudioEffect.checkStatus`), the engine smoothly transitions to `NoctraLegacyEffects` (NXP Equalizer, BassBoost, Virtualizer, and Reverb) without interrupting playback or causing Dolby Atmos audio muting.
- **Opus 48 kHz Stream Prioritization**: Prioritizes 48 kHz Opus audio streams (itag 251) over 128 kbps AAC, preserving full 20 kHz acoustic extension and aligning with Android's native 48 kHz mixer.

### Liquid Glass Theme Performance Overhaul
- **Eliminated BackdropFilter Churn**: Replaced expensive per-card `BackdropFilter` shaders with hardware-accelerated translucent gradients, hairline specular borders, top edge reflection highlights, and soft elevation shadows.
- **RepaintBoundary Display List Caching**: Isolated `NoctraThemeBackdrop` liquid orbs and gradients inside a `RepaintBoundary` so the background is rasterized once and never repaints during list scrolling.
- **Tuned Floating Blur Sigmas**: Optimized `CustomBottomNavBar` (sigma 12), `PlayerSheet` (sigma 14), and `EqualizerSheet` (sigma 14) for 60/120 FPS fluid scrolling.

### App Shell & System Integrations
- **App Icon Change Confirmation Dialog**: Added a theme-consistent modal popup when changing the dynamic app icon in Settings, advising users that Android restarts the application to update launcher activities, with explicit "No" and "Yes, Apply" options.
- **Google Assistant App Actions**: Added `shortcuts.xml` declaring `actions.intent.PLAY_MUSIC` and `actions.intent.OPEN_APP_FEATURE` capabilities, linking metadata in `AndroidManifest.xml` for system voice search integration.
- **Interactive Notification Heart Button**: Replaced the static stop button in the notification shade with an interactive favorite toggle (`ic_favorite` / `ic_favorite_border`) that persists track preference instantly.

### Architecture & Verification
- **Strict LOC Constraint**: Every single source file in the repository satisfies the `<= 300 LOC` limit.
- **Verified Zero Static Issues**: `flutter analyze` clean with 0 warnings.
- **Verified Automated Tests**: Test suite passing with 100% verification including release manifest integrity.

---

## v1.1.6 (2026-09-03)

### 🏗️ Architecture & Modular Decomposition (Phase 17)
- **Strict $\le$ 300 LOC Ceiling**: Fully decomposed all monolithic files across `lib/`, `test/`, and `android/app/src/main/` — zero source files exceed 300 lines of code.
- **Rebuild Scope Isolation**: Extracted `LibrarySongRow` into an isolated consumer widget; playback stream changes now only rebuild the visible rows rather than recomputing the full master library merge.
- **Decoupled Audio Playback Engine**: Segmented playback infrastructure into clean delegates (`PlayerCrossfadeEngine`, `PlayerSessionLoader`, `PlayerCrossfadeRamp`, `PlayerAutoplayManager`, and `PlayerPlaybackController`).
- **Decoupled Neural Recommender Engine**: Separated feature extraction, model weights, and training routines (`NeuralFeatureBuilder`, `NeuralModelWeights`, `NeuralTrainingEngine`).
- **Decoupled P2P SyncCast Suite**: Modularized host and client engines, packet codecs, rate limiting, and cryptographic handshake handlers.
- **Decoupled Migration & Importer Pipeline**: Extracted modular importers (`SpotifyImporter`, `AppleMusicImporter`, `YouTubeMusicImporter`, `JioSaavnImporter`, `PlaylistFileImporters`) with chunked resilient database commits.
- **Decoupled Native Android Layer**: Split `MainActivity.kt` and `NoctraAudioStemEngine.kt` into dedicated channel delegates for audio, installer, icon switcher, resolver, visualizer, and DSP processing.

### 🎵 High-Fidelity Streaming & Resolver Security
- **6-Tier Composite Stream Resolver**: Resilient hierarchical resolution pipeline (`Local Cache` $\rightarrow$ `Direct Stream` $\rightarrow$ `JioSaavn 320k` $\rightarrow$ `Native Kotlin` $\rightarrow$ `InnerTube REST` $\rightarrow$ `YouTube Web Search`).
- **Resolver Security Hardening**: Strict host whitelisting, SSRF protection, untrusted redirect refusal, and mandatory HTTPS validation on remote audio endpoints.
- **Granular Quality & Codec Control**: Re-architected `StreamQualitySheet` with dedicated option selectors for bitrate tiers (64k to Lossless), audio processing toggles (volume normalization & gapless playback), and real-time file size estimation.

### 📜 Multi-Script Lyrics & Poetic Translation
- **Modular Transliteration Engines**: Segmented transliteration mapping tables and phonetic rules for Devanagari, Brahmic Indic scripts, and international scripts (Japanese, Korean, Chinese, Cyrillic, Arabic, Greek, Thai, Hebrew).
- **Poetic Semantic Translator**: Integrated 3-layer translation lexicon with runtime word learning and Hindustani lyrical terms glossary.

### 🎨 Noir Design System & Theme Engine
- **Triple Theme Harmony**: Precision-tuned **Noir Black** (obsidian glass), **Noir White** (minimal editorial), and **Liquid Glass** (sapphire blur glassmorphism). Confirmed complete deprecation of AMOLED in favor of true Noir branding.
- **Dynamic Launcher Icon Synchronization**: Seamlessly switches the Android launcher icon in background lifecycle events to reflect the active theme.

### 🌐 Internationalization & App Shell
- **Comprehensive 8-Language Localization**: Full native coverage across English, Hindi, Punjabi, Urdu, Kannada, Tamil, Marathi, and Odia.
- **Modular App Shell**: Decomposed `main.dart` into `MainNavigationShell` and `CustomBottomNavBar` with smooth animated tab transitions and drawer navigation.

### ✅ Test Suite & Verification
- **576/576 Tests Passing**: Expanded test suite covering model validation, stream security, audio crossfade, P2P networking, migration parsing, and rebuild scope isolation.
- **Zero Static Analysis Warnings**: Clean `flutter analyze` run across all Dart code.

---

## v1.1.5 (2026-09-01)

### 🎵 Audio & Playback
- Improved stream resolver pipeline with 6-tier fallback (Local → Direct → JioSaavn → Native → InnerTube → YouTube Web Search)
- New `YoutubeWebSearchResolver` for songs that fail all other tiers
- Deep YTMusic result parsing: handles `musicTwoRowItemRenderer`, `musicShelfRenderer`, and flexColumn fallback
- Increased NativeKotlinResolver timeout from 4s to 6s
- Fixed songs not playing due to incomplete videoId extraction

### 🎨 Dynamic Launcher Icon
- Proper activity-alias system with `.default` alias owning the LAUNCHER entry
- Theme-aware launcher icons: Noir Black, Noir White, Liquid Glass
- Deferred icon swap — applies when app goes to background to avoid process kill
- `WidgetsBindingObserver` integration for lifecycle-aware icon updates

### 🌐 Internationalization (8 languages)
- Full i18n system: English, Hindi, Punjabi, Urdu, Kannada, Tamil, Marathi, Odia
- Language switcher in Settings with all 8 languages
- Updated all UI strings to use `NoctraLocalization.tr()`

### 🧠 Neural Recommendation Engine v2
- Expanded from 88→120 input dimensions
- 4-layer MLP: 120→64→32→16→1 (was 88→40→20→1)
- New feature dimensions: audio features (8d), temporal encoding (8d), listening patterns (8d), cross-platform metadata (8d)
- Deezer audio features integration (zero API key): energy, danceability, valence, tempo
- MusicBrainz enhanced: ISRC lookup, artist credits, rate limiting

### 🎨 Theme System
- Liquid Glass theme brightened — visible sapphire blue (#162E4A) instead of near-black
- Dynamic `MaterialApp` theme — both `theme:` and `darkTheme:` update simultaneously
- Splash screen uses theme tokens instead of hardcoded colors

### 🎵 Audio Router
- Multi-output audio routing implementation
- Dual Bluetooth/speaker output support

### 🐛 Bug Fixes
- Fixed Python syntax error in `backend/routes/api_routes.py`
- Fixed line length violations in test files
- Fixed widget test for updated localization
- Removed unused imports across codebase
- Fixed `deprecated_member_use` for `onReorder` in queue sheet

### ✅ Quality
- 320/320 tests passing
- 0 flutter analyze issues
