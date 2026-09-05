# Changelog

## v1.0.0 (2026-09-05)

### 🚀 First Stable Signed Production Release

This is the first **properly signed** public release of Noctra, built with a
freshly generated release keystore and shipped as per-ABI APKs plus a
machine-readable update manifest.

### ✨ AI Libraries That Actually Open
- **AI folders/mixes open instantly**: resolution is now local-first — your
  curated library picks appear immediately instead of waiting on a network
  vibe feed, which made collections feel dead on slow networks.
- **Remix works offline**: Remix deterministically re-orders the already-
  resolved track pool in place instead of re-running the same network search
  on every tap.
- **No more rebuild storms**: all nine vibe curations share one cached
  embedding pool per data state, and AI playlists/folders are memoized on a
  content signature so Library/Home rebuilds stop re-scoring the whole
  library.

### 🧱 Architecture & Platform Isolation
- Mechanically enforced module boundaries (`test/architecture_boundaries_test.dart`):
  no source file exceeds 300 LOC, no import cycles, layer direction enforced.
- `GlassCard` moved to a shared widgets layer; UI no longer reaches the
  database or constructs repositories directly.
- Platform capabilities registry (`core/platform`); Android channel adapters
  moved out of `core/utils`; `dart:io` / Android path assumptions removed
  from models and UI.

### 🔒 Release Signing
- Release keystore generated and wired via git-ignored `android/key.properties`;
  builds are signed with a production key (not the debug keystore).
- Per-ABI APKs + `SHA256SUMS.txt` + signed release manifest for the in-app
  updater.

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
