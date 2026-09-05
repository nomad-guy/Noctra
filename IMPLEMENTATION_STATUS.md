# Noctra Implementation Status & Architecture Roadmap

Comprehensive audit of all 20 development phases and architecture milestones defined for Noctra.

---

## 1. Executive Summary

Noctra is built around a local-first, privacy-respecting music player architecture:
- **Local-First Core**: Offline playback, SQLite storage, native caching, zero telemetry.
- **Unified Music Source Abstraction**: Multi-resolver engine spanning JioSaavn 320kbps CD lossless streams, YouTube Music Opus/AAC direct extraction, and Local storage.
- **On-Device 16-Axis Acoustic Intelligence**: Tiny vector embeddings and cosine similarity ranking without cloud dependencies.
- **P2P SyncCast & Hotspot Party**: Local WebSocket synchronization over Wi-Fi and mobile hotspots.
- **Spotify-Inspired Liquid Noir UI**: Dynamic liquid glassmorphism, responsive quick sound blocks, ranked trending hits, and real-time visualizers.

---

## 2. Phase-by-Phase Implementation Matrix

| Phase | Description | Status | Implementation Details |
|---|---|---|---|
| **01** | **Flutter Setup & Foundation** | **COMPLETE** | Flutter 3.x with Dart, Riverpod state management, responsive desktop/mobile/web layout. |
| **02** | **Noir Design System (Dual Theme)** | **COMPLETE** | `NoirColors`, `NoirThemeMode.noirBlack` & `NoirThemeMode.noirWhite`, liquid glass decorations in `lib/core/theme/noir_theme.dart`. |
| **03** | **Local Music Scanner** | **COMPLETE** | `LocalSource` in `lib/data/sources/local_source.dart` with metadata extraction and local directory indexing. |
| **04** | **SQLite / Storage Layer** | **COMPLETE** | `MusicStorageService` with persistent tracking of library, downloaded tracks, recently played history, and custom folders. |
| **05** | **Audio Playback Engine** | **COMPLETE** | `just_audio` with streaming buffer management, seeking, duration tracking, and state listeners in `lib/services/audio/audio_player_service.dart`. |
| **06** | **Background Playback & Lock Screen** | **COMPLETE** | `audio_service` integration configured for notification controls, media session management, and background playback. |
| **07** | **Search, Queue & Playlist Management** | **COMPLETE** | Multi-source search bar, active queue provider, folder organizer sheets (`AddToFolderSheet`), and custom playlist creation. |
| **08** | **Zero-Key Metadata Enrichment** | **COMPLETE** | LRCLIB synchronized lyrics resolver, 500x500 high-res artwork processor, and embedded ID3/Vorbis tag parsing. |
| **09** | **YouTube Music Source** | **COMPLETE** | `youtube_service.py` using `yt-dlp` Android player client for direct Opus/AAC extraction without cipher blockage. |
| **10** | **Streaming-First Playback** | **COMPLETE** | Direct chunked streaming proxy (`/api/proxy_stream` and `_stream_response` in Flask) with HTTP `Range` request support for instant seeking. |
| **11** | **Download & Offline Cache** | **COMPLETE** | 1-tap lossless downloader saving `.m4a` files with embedded tags to local storage via `/api/download` and `MusicService.downloadTrack`. |
| **12** | **Listening History & Action Tracking** | **COMPLETE** | `recentlyPlayed` list persistence, play count counters, and `user_actions` logging on play, pause, complete, and skip events. |
| **13** | **Recommendation Engine** | **COMPLETE** | `TasteVectorEngine.cosineSimilarity` comparing candidate feature vectors against active user taste profiles, generating match scores (75%-99%). |
| **14** | **Knowledge Graph & Acoustic Nodes** | **COMPLETE** | 16-axis dimensional modeling (`Dark Tone`, `Ambient Depth`, `Energy`, `Night Drive`, `Analog Synth`, `Acoustic Warmth`, etc.). |
| **15** | **User Taste Learning** | **COMPLETE** | Incremental vector adjustments: positive reinforcement on completion and replay, negative reinforcement on quick skip. |
| **16** | **Tiny Music Model & AI RAG Service** | **COMPLETE** | `ai_rag_service.py` with hybrid dense RAG reranking and text vectorization in compact memory footprint (<5 MB). |
| **17** | **Natural Language Curation** | **COMPLETE** | `AIPromptCuratorSection` and `/api/vibe_curate` converting natural language prompts into target acoustic vectors. |
| **18** | **P2P SyncCast Streaming** | **COMPLETE** | `P2PSyncService` over local WebSockets for clock synchronization, shared playback state, and party mode. |
| **19** | **P2P Library Sharing** | **COMPLETE** | P2P queue broadcasting and local track streaming without cloud intermediaries. |
| **20** | **RAM & Performance Optimization** | **COMPLETE** | Lazy list rendering, in-memory TTL caching (300s), RepaintBoundary isolation for visualizers, and minimal asset tree-shaking. |

---

## 3. Core Architecture & Component Map

```text
                               NOCTRA
                                  |
        +-------------------------+-------------------------+
        |                         |                         |
        v                         v                         v
   MY LIBRARY                  DISCOVER                    P2P
  (Local Storage)         (Multi-Source Stream)        (SyncCast Party)
        |                         |                         |
        |               +---------+---------+               |
        |               v         v         v               |
        |            JioSaavn  YouTube   LRCLIB             |
        |            (320kbps) (Android) (Synced LRC)       |
        |               |         |         |               |
        +---------------+---------+---------+---------------+
                                  v
                          UNIFIED SONG MODEL
                                  |
                    +-------------+-------------+
                    v             v             v
                Metadata      16-Axis Taste   Knowledge
               (500x500)      Vector Graph     Graph
                    |             |             |
                    +-------------+-------------+
                                  v
                        HYBRID DENSE RAG /
                       COSINE SIMILARITY RANKER
                                  |
                                  v
                        JUST_AUDIO STREAMING
```

---

## 4. Key Engineering Implementations

### Direct 320kbps JioSaavn Audio Decryption
- Triple-DES ECB decryption pipeline in `backend/services/jiosaavn_service.py`.
- Generates direct high-bitrate media URLs with 500x500 release artwork.
- In-memory 5-minute caching with automatic retry and error recovery.

### YouTube Audio Android Extraction
- Utilizes `yt-dlp` with the `android` player client to bypass YouTube 403 SABR cipher restrictions.
- Serves chunked audio through Flask proxy with HTTP `Range` headers, supporting seamless player seeking.

### Frame-Accurate Synced Lyrics Engine
- Multi-tier resolution: Python sidecar exact match -> LRCLIB duration-aware search -> JioSaavn plain lyrics fallback.
- Duration proximity scoring prevents studio-cut lyrics from desyncing with live/extended performances.
- Zero-latency UI scrolling with dynamic line highlighting in `lib/ui/widgets/lyrics_view.dart`.

### Spotify-Style Liquid Noir Interface
- 26px bold greeting typography with real-time status indicators.
- 2x3 Quick Sound Blocks for instant access to recent and local tracks.
- Top Trending Hits carousel with numbered rank badges (#1, #2, #3).
- Compact "Made For You" list rows with integrated waveform visualizers and download actions.
- Real-time animated Synthwave Grid, Spectrum Bars, and Sound Pulse visualizers with automatic lifecycle sleeping.

---

## 5. Security & Privacy Guarantees

1. **Zero Cloud Dependencies**: All recommendations, history, and taste graphs reside on the local device.
2. **Zero Telemetry**: No third-party analytics trackers, crashlytics, or remote telemetry SDKs.
3. **Privacy-Hardened Requests**: Upstream requests strip `Referer`, `X-Forwarded-For`, and `X-Real-IP` headers.
4. **Zero API Key Requirement**: Completely functional using open protocols, local caching, and public metadata sources.
