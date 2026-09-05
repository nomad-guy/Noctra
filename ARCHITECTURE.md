# Noctra Architecture & Technical Documentation

> **Noctra** is an authentication-less, privacy-first, on-device agentic music player built with Flutter, Dart, Riverpod, and native Android Kotlin DSP delegates. It features an on-device 120-Dimension Neural Knowledge Graph, compact vector embeddings, adaptive smart queueing, zero-key metadata enrichment, 6-tier composite stream resolution (JioSaavn 320kbps CD lossless and YouTube Music Opus/AAC), and a strict $\le$ 300 LOC modular architectural design.

---

## 1. System Architectural Overview

```text
+-------------------------------------------------------------+
|                           FLUTTER                           |
|                 Dart 3 + Flutter Riverpod                   |
+-------------------------------------------------------------+
| UI LAYER (Material 3 + Triple Noir Aesthetic)               |
| - Noir Design System (Noir Black / Noir White / Liquid Glass) |
| - Home Screen (Spotify-Style Flow, Trending, Made For You)  |
| - Search & Multi-Source Explorer (YouTube + JioSaavn)       |
| - Library (Songs, Albums, Artists, Folders)                 |
| - AI Studio (120-dim Vibe Prompts, Similarity Radio)        |
| - Adaptive Player & Smart Queue (Synthwave & Spectrum Bars) |
| - P2P SyncCast (Local WebSocket Hotspot Party Mode)         |
+-------------------------------------------------------------+
| LOCAL STORAGE & KNOWLEDGE GRAPH (SQLite Engine)             |
| - songs, artists, albums, playlists, history                |
| - user_preferences & user_taste_vector (120 dimensions)     |
| - graph_nodes & graph_edges (PERFORMED, HAS_MOOD, etc.)     |
| - metadata_cache (LRCLIB, Cover Art & Tag Cache)            |
+-------------------------------------------------------------+
| ZERO-API-KEY METADATA PIPELINE                              |
| - 1. Embedded ID3 / Vorbis Tags reader                      |
| - 2. LRCLIB Duration-Aware Synced Lyrics Service            |
| - 3. JioSaavn 500x500 Uncompressed Artwork Pipeline         |
| - 4. Persistent Local SQLite Artwork & Tag Cache            |
+-------------------------------------------------------------+
| STREAM RESOLUTION PIPELINE (6-Tier Composite Resolver)      |
| - Tier 1: Local Disk Vault Cache                            |
| - Tier 2: Direct Validated HTTPS Stream                     |
| - Tier 3: JioSaavn Direct 320kbps CD Decryption             |
| - Tier 4: Native Android Kotlin Audio Resolver              |
| - Tier 5: YouTube Music InnerTube REST Direct Extractor     |
| - Tier 6: YouTube Web Search Fallback Resolver              |
+-------------------------------------------------------------+
| ON-DEVICE NEURAL INTELLIGENCE ENGINE                        |
| - 120-Dimensional Vector Space (Acoustic + Context)         |
| - 4-Layer Tiny MLP Ranker (120 -> 64 -> 32 -> 16 -> 1)      |
| - Maximal Marginal Relevance (MMR) Diversity Reranker       |
| - Online Reinforcement Learning (Reward Shaping Engine)     |
+-------------------------------------------------------------+
| PLAYBACK & NATIVE PLATFORM INTEGRATION                      |
| - Android Media3 / ExoPlayer (just_audio + background)      |
| - Hardware-Accelerated Kotlin DSP Equalizer & Effects       |
| - System Notifications, Lock Screen & Audio Focus           |
+-------------------------------------------------------------+
```

---

## 2. Strict Modular Architecture ($\le$ 300 LOC Limit)

Every source file in Noctra is bounded to $\le$ 300 lines of code. Monolithic files have been decomposed into dedicated delegates:

### Playback Infrastructure
- `PlayerCrossfadeEngine`: Orchestrates dual-player crossfading.
- `PlayerSessionLoader`: Handles session loading and pre-buffering.
- `PlayerCrossfadeRamp`: Computes exponential/logarithmic volume ramps.
- `PlayerAutoplayManager`: Algorithmic queue population when playback finishes.
- `PlayerPlaybackController`: Exposes high-level playback actions.

### Native Android Architecture
- `AudioChannelsDelegate`: ExoPlayer lifecycle and native channel bridge.
- `ResolverChannelDelegate`: Native audio stream resolution.
- `VisualizerChannelDelegate`: Hardware audio visualizer FFT data streaming.
- `LauncherIconChannelDelegate`: Theme-synchronized launcher activity-alias switching.
- `InstallerChannelDelegate`: Self-updating APK verification and installation.
- `StemDspHelper`: Hardware digital signal processing filters.

### Rebuild Scope Isolation
- `LibrarySongRow`: Dedicated consumer widget isolating playback stream subscriptions per visible row. Eliminates full-tab rebuilds during playback ticks.

---

## 3. 6-Tier Composite Stream Resolution

```text
Incoming Song Request
       |
       v
[Local Disk Cache?] ---> YES ---> Play Local File
       |
       NO
       v
[Direct Stream Valid?] -> YES -> Play Direct Stream
       |
       NO
       v
[JioSaavn 320k Match?] -> YES -> Decrypt & Play 320k Stream
       |
       NO
       v
[Native Kotlin Extractor] -> YES -> Play Native Stream
       |
       NO
       v
[InnerTube REST JSON] ---> YES ---> Play Opus/AAC Stream
       |
       NO
       v
[YouTube Web Search Fallback] -> YES -> Play Search Stream
       |
       NO
       v
Throw ResolutionException (Graceful User Alert)
```

---

## 4. Multi-Script Indic & World Lyrics Engine

- **Sanscript Brahmic Matrix Engine**: Offline, zero-latency pure Dart transliteration across Devanagari, Gurmukhi, Bengali, Gujarati, Telugu, Tamil, Kannada, Malayalam, and Odia.
- **International Script Transliteration**: Japanese (Romaji), Korean (Hangul $\rightarrow$ Roman), Chinese (Hanzi $\rightarrow$ Pinyin), Cyrillic, Arabic, Greek, Thai, and Hebrew.
- **Dynamic Semantic Translation**: 3-layer lexicon with runtime learning, schwa-deletion heuristics, and poetic Hindustani glossary.

---

## 5. Security Architecture

- **Host Whitelisting**: Connections strictly restricted to verified audio CDN domains.
- **Anti-SSRF Protection**: Rejects all private IP ranges, loopback (`127.0.0.1`, `localhost`), link-local, and non-HTTPS URLs.
- **Hop-by-Hop Redirect Validation**: Follows HTTP redirects only after independently validating the target host against the security whitelist.

---

## 6. Google Assistant & MediaSession Integration

- **Single Authoritative Playback**: All external voice and media session actions converge through `AssistantCommandRouter` to `AssistantContentRouter` and the single `AudioPlayerService` / `MusicRepository` instance. No parallel playback or queue engines exist.
- **Structured Media Hierarchy (`MediaBrowserService`)**: Exposes roots for Favorites (`noctra://favorites`), Downloads (`noctra://downloads`), Recently Played (`noctra://recently_played`), Playlists (`noctra://playlists`), Albums (`noctra://albums`), Artists (`noctra://artists`), and AI Recommendations (`noctra://recommendations`).
- **Voice Search & Playback (`MEDIA_PLAY_FROM_SEARCH`)**: Natural language queries route through `AssistantSearchPipeline`, preserving candidate ranking, timeout bounds, and strict `TrackMatchingGuard` validation.
- **Custom Session Actions**: Extends MediaSession with custom session commands for dynamic theme switching, queue addition, and favorites management.

