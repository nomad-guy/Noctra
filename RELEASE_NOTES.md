# Noctra v1.1.6 Release Notes

Next-Generation Autonomous Music Streaming Platform & On-Device AI Intelligence Engine.

---

## APK Download Guide: Which Version Should You Download?

| File Name | Architecture | Recommended Device Target |
| :--- | :--- | :--- |
| **`app-arm64-v8a-release.apk`** | `arm64-v8a` | **RECOMMENDED FOR 99% OF USERS.** Modern Android smartphones and tablets (Snapdragon, MediaTek, Exynos, Tensor, 64-bit Android 8.0+). |
| **`app-armeabi-v7a-release.apk`** | `armeabi-v7a` | Older 32-bit Android smartphones and budget legacy devices. |
| **`app-x86_64-release.apk`** | `x86_64` | Android emulators (Android Studio Emulator, WSA, BlueStacks), Chromebooks, and Intel/AMD tablets. |
| **`app-release.apk`** | Universal | Universal "Fat" APK bundled with all native architectures combined. Works on any device. |

---

## What's New in v1.1.6

### Complete Architectural Modularization (Phase 17)
- **Zero Monolithic Files ($\le$ 300 LOC)**: Every Dart, Kotlin, and Java file across the entire application and test suite has been refactored to adhere strictly to a 300 LOC ceiling for maximum maintainability and modular decoupling.
- **Isolate Rebuild Scoping**: Extracted `LibrarySongRow` to decouple row-level playback updates from whole-library re-merges.
- **Decomposed Playback & Crossfade Delegates**: Separated crossfade, session loading, volume ramps, and radio autoplay managers into clean single-responsibility components.
- **Decomposed Native Android Engine**: Channel delegates for audio session, visualizer, package installer, resolver, launcher icon, and stem DSP.

### 6-Tier Composite Audio Streaming & Security
- **Hierarchical Stream Resolution**: Local Cache $\rightarrow$ Direct Stream $\rightarrow$ JioSaavn 320kbps CD Master $\rightarrow$ Native Android Kotlin $\rightarrow$ YouTube Music InnerTube REST $\rightarrow$ YouTube Web Search.
- **Hardened Remote Stream Security**: Server-Side Request Forgery (SSRF) protections, loopback/private IP blocking, untrusted redirect prevention, and strict HTTPS enforcement.
- **Granular Codec & Bitrate Controls**: Select between 64kbps Opus, 128kbps AAC, 256kbps AAC, 320kbps MP3, and Hi-Res FLAC lossless tiers with volume normalization and gapless playback.

### Multi-Script Synced Lyrics & Poetic Translation
- **Frame-Accurate Synced Lyrics**: Millisecond-accurate playback synchronization with dual caching.
- **Indic Brahmic Transliteration**: Pure Dart zero-dependency script matrix supporting Devanagari, Gurmukhi, Bengali, Gujarati, Telugu, Tamil, Kannada, Malayalam, and Odia.
- **Dynamic Semantic Translation**: Learn and translate Hindi/Urdu poetic expressions with smart schwa-deletion heuristics.

### Triple Theme Trinity
- **Noir Black**: Signature obsidian glassmorphism with layered blur effects.
- **Noir White**: High-contrast editorial monochrome for bright environments.
- **Liquid Glass**: Sapphire blue glassmorphism with dynamic ambient reflections.
- **Dynamic App Icon**: Android launcher icon switches automatically to match the active theme.

### Zero-Server Decentralized Jam Mode (SyncCast)
- Local network WebSocket synchronization with automatic discovery, room secret authentication, and zero latency drift.

### Resilient Library Migration & Importers
- Native importers for Spotify, Apple Music, YouTube Music, JioSaavn, and CSV/M3U playlist files.
- Chunked database commits (500 songs/batch) prevent UI freezes on massive 10,000+ track imports.

### 100% Privacy & FOSS
- No login, no accounts, zero tracking, no cloud telemetry, zero advertisements.

---

## Verification & Integrity
- **Tests**: 576 / 576 tests passing
- **Static Analysis**: 0 warnings, 0 errors (`flutter analyze`)
- **Compatibility**: Android 8.0 (API 26) through Android 15 (API 35+)
