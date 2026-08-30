# Noctra Architecture & Technical Documentation

> **Noctra** is an authentication-less, privacy-first, on-device agentic music player built with Flutter, Dart, Riverpod, and a lightweight Python sidecar. It features an on-device 16-Axis Neural Knowledge Graph, compact vector embeddings, adaptive smart queueing, zero-key metadata enrichment, and multi-source streaming (JioSaavn 320kbps CD lossless and YouTube Music Opus/AAC).

---

## 1. System Overview

```text
+-------------------------------------------------------------+
|                           FLUTTER                           |
|                 Dart + Flutter Riverpod                     |
+-------------------------------------------------------------+
| UI Layer (Material 3 + Liquid Glassmorphic Noir)            |
| - Noir Design System (Noir White / Noir Black)              |
| - Home Screen (Spotify-Style Flow, Trending, Made For You)  |
| - Search & Multi-Source Explorer (YouTube + JioSaavn)       |
| - Library (Songs, Albums, Artists, Folders)                 |
| - AI Studio (16-Axis Vibe Prompts, Similarity Radio)        |
| - Adaptive Player & Smart Queue (Synthwave & Spectrum Bars) |
| - P2P SyncCast (Local WebSocket Hotspot Party Mode)         |
+-------------------------------------------------------------+
| LOCAL STORAGE & KNOWLEDGE GRAPH (Drift / SQLite)            |
| - songs, artists, albums, playlists, history                |
| - user_preferences & user_taste_vector                      |
| - graph_nodes & graph_edges (PERFORMED, HAS_MOOD, etc.)     |
| - metadata_cache (LRCLIB, Cover Art & Tag Cache)            |
+-------------------------------------------------------------+
| ZERO-API-KEY METADATA PIPELINE                              |
| - 1. Embedded ID3 / Vorbis Tags reader                      |
| - 2. LRCLIB Duration-Aware Synced Lyrics Service            |
| - 3. JioSaavn 500x500 Uncompressed Artwork Pipeline         |
| - 4. Persistent Local SQLite Artwork & Tag Cache            |
+-------------------------------------------------------------+
| PYTHON SIDECAR (yt-dlp & ML Intelligence Engine)            |
| - JioSaavn Direct DES 320kbps Audio Decrypter               |
| - yt-dlp Audio Stream Resolver (Android Client)             |
| - Chunked Stream Proxy with HTTP Range Header Support       |
| - 16-Axis Text Vectorizer & Hybrid Dense RAG Reranker       |
+-------------------------------------------------------------+
| ON-DEVICE MUSIC INTELLIGENCE ENGINE                         |
| - Knowledge Graph Recommender & Co-occurrence Traversal     |
| - Incremental Taste Profile (Reward on Complete/Replay)     |
| - Adaptive Queue Agent (Skip detection & energy shift)      |
| - Transparent "Why This?" Explanation Engine                |
+-------------------------------------------------------------+
| PLAYBACK & PLATFORM INTEGRATION                             |
| - Android Media3 / ExoPlayer (just_audio + service)         |
| - System Notifications, Lock Screen & Audio Focus           |
+-------------------------------------------------------------+
```

---

## 2. Multi-Source Streaming & Stream Resolution

### JioSaavn Direct 320kbps Stream Decryption
- Uses Triple-DES ECB decryption on the `encrypted_media_url` payload returned by JioSaavn's internal catalog.
- Replaces bitrate tags with `_320.mp4` / `_320.m4a` to stream full 320kbps CD-quality audio directly from `aac.saavncdn.com`.
- Cached in-memory with a 300-second TTL to minimize repeated requests.

### YouTube Audio Android Client Extraction
- Uses `yt-dlp` configured with the `android` player client to avoid SABR-related 403 authorization errors.
- Extracted streams are proxied via Flask (`/api/proxy_stream`) supporting HTTP `Range` requests, enabling precise player seeking without downloading entire tracks upfront.

---

## 3. On-Device 16-Axis Acoustic Intelligence

### Vector Space Dimensions
The recommendation model operates across 16 acoustic dimensions:
1. `Dark Tone`
2. `Ambient Depth`
3. `Energy`
4. `Chill Factor`
5. `Melancholy`
6. `Acoustic Warmth`
7. `Electronic`
8. `Vocal Presence`
9. `Harmonic Density`
10. `Analog Synth`
11. `Night Drive`
12. `Cognitive Focus`
13. `Uplift`
14. `Sub-Bass Weight`
15. `Rhythm Tempo`
16. `Instrumental`

### Scoring & Matching Logic
- **Cosine Similarity**: Vector dot products normalize similarity scores between candidate tracks and the user's active taste vector.
- **Match Score**: Scaled to `75% - 99%` for human-readable affinity ratings.
- **Incremental Feedback**:
  - `PLAY / COMPLETE / REPLAY`: Increases weights of matching acoustic dimensions.
  - `QUICK SKIP`: Decreases weights of active dimensions.

---

## 4. Frame-Accurate Synced Lyrics Engine

- **Tier 1**: Local Python sidecar exact query with duration filtering.
- **Tier 2**: Direct LRCLIB exact matching (`track_name`, `artist_name`, `duration`).
- **Tier 3**: Direct LRCLIB fuzzy search with duration proximity sorting (+/- 15 seconds).
- **Tier 4**: JioSaavn plain lyrics fallback.

---

## 5. Local P2P SyncCast (Party Mode)

- **Local Discovery**: Operates over local Wi-Fi or mobile hotspots using WebSockets.
- **Clock Synchronization**: Synchronizes playback position and state between Host and Client devices without an external cloud mediator.
- **Shared Queue**: Broadcasts track queue and metadata in real time.
