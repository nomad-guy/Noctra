# Noctra

<div align="center">

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![FOSS](https://img.shields.io/badge/FOSS-Free%20%26%20Open%20Source-brightgreen)
![Privacy](https://img.shields.io/badge/Privacy-100%25%20On--Device-success)
![Flutter](https://img.shields.io/badge/Flutter-v3.24+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Linux%20%7C%20Windows-lightgrey)

**An authentication-less, privacy-first lossless music player powered by an on-device two-stage neural recommender (MLP + MMR), SQLite telemetry, and dual Noir themes. Zero ads, zero tracking.**

[Download Release APK](https://github.com/nomad-guy/Noctra/releases/latest) • [Report Issue](https://github.com/nomad-guy/Noctra/issues) • [Changelog](CHANGELOG.md)

</div>

---

## Highlights

- **100% Free & Open Source (FOSS)**: Licensed under the GNU General Public License v3.0 (GPL-3.0).
- **Authentication-Free**: Zero accounts, zero login screens, and zero tracking cookies.
- **Pure On-Device Neural Recommender**:
  - **Stage 1 (Retrieval)**: Fast candidate generator extracting ~100 candidate tracks across SQLite history, library, and live charts.
  - **Stage 2 (Tiny Neural MLP Ranker)**: 3-Layer Dense network ($80 \rightarrow 32 \rightarrow 16 \rightarrow 1$) predicting $P(\text{meaningful engagement})$ in $<1\text{ms}$ with zero battery drain.
  - **Stage 3 (Maximal Marginal Relevance Diversity Reranker)**: MMR algorithm ($\lambda = 0.75$) with hard constraint capping repeat artists to max 2 in Top 15 to eliminate recommendation fatigue.
- **SQLite Telemetry & Vector Store**: Full ACID transaction database (`noctra_neural_store.db`) with Write-Ahead Logging (WAL) for local-first speed.
- **Lossless & High-Bitrate Audio**: Direct 320kbps CD lossless stream resolution with zero ads and background playback support.
- **Hardware DSP Equalizer**: Native Android 5-band millibel Equalizer, Bass Boost exciter, 3D Spatial Virtualizer, and Reverb effects.
- **Multi-Engine Synced Lyrics**: Millisecond time-coded LRC lyrics with Devanagari transliteration and Roman script support.
- **P2P SyncCast Jam Studio**: Decentralized local-network party playback synchronization with automatic socket reconnection.
- **Spotify-Style First-Run Onboarding**: Multilingual, vibe, and artist selection with live Wikipedia portrait avatars.
- **Triple Noir Aesthetic**: Obsidian Dark, AMOLED Pitch-Black (`#000000`), and Editorial Minimal Light modes with adaptive app icon switching.

---

## Screenshots & Visual Experience

| Dual Noir Aesthetic | Neural Player Sheet | Equalizer & DSP |
|:---:|:---:|:---:|
| Dual Noir Glassmorphism with adaptive contrast typography | Real-time 60FPS audio visualizers & millisecond-synced lyrics | 5-Band Hardware Equalizer, 3D Spatializer & Presets |

---

## Architectural Principles

```text
┌──────────────────────────────────────────────────────────┐
│                   USER LISTENING EVENTS                  │
│  Fast Skip (-1.0) | Partial (+0.4) | Full (+1.0) | Fav (+3.0)  │
└────────────────────────────┬─────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────┐
│             ONLINE GRADIENT DESCENT LEARNER              │
│       U_new = normalize(U_old + alpha * signal * T)      │
│          with Half-Life Recency Decay (tau = 14d)        │
└────────────────────────────┬─────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────┐
│             STAGE 1: CANDIDATE GENERATOR                 │
│    Retrieves ~100 tracks from Library + Trends + Charts  │
└────────────────────────────┬─────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────┐
│             STAGE 2: ON-DEVICE TINY MLP RANKER           │
│   Input: [User (32) + Track (32) + Context (16)] (80d)   │
│             Dense 80 -> 32 -> 1 (Sigmoid Score)          │
└────────────────────────────┬─────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────┐
│             STAGE 3: MMR DIVERSITY RERANKER              │
│       Selects Top 15-20 Tracks with Artist Diversity      │
└──────────────────────────────────────────────────────────┘
```

- **Strict Modularity**: Every source file in the codebase is strictly maintained under 300 lines of code.
- **Zero Cloud AI Dependency**: The neural MLP and matrix mathematics run 100% on-device in pure Dart.

---

## Building from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.24.0 or higher)
- Android SDK (API Level 24 to 35)
- Java 17 / OpenJDK 17

### Build Steps
```bash
# Clone the repository
git clone https://github.com/nomad-guy/Noctra.git
cd Noctra

# Fetch dependencies
flutter pub get

# Run unit tests (10/10 green)
flutter test

# Run static analysis (0 issues)
flutter analyze

# Build release APK
flutter build apk --release
```

---

## Legal Disclaimer

Noctra is a Free and Open Source Software (FOSS) client application developed for personal, educational, and research purposes.

- **No Media Hosting**: Noctra does not operate central servers that host, store, cache, or redistribute copyrighted audio, video, or media files. 
- **Client-Side Resolution**: All stream resolution, metadata indexing, Wikipedia biographies, and lyric parsing occur strictly on-device via publicly accessible web APIs and user-initiated queries.
- **Trademarks & Attribution**: Spotify, YouTube, YouTube Music, JioSaavn, Wikipedia, and other third-party brand names or logos mentioned in the codebase are the property of their respective owners and are used strictly for nominal identification and referencing purposes under fair use.
- **User Responsibility**: Users are responsible for complying with the terms of service of the third-party platforms they access and the applicable copyright laws in their respective jurisdictions.

---

## License

Copyright (C) 2026 Nomad Guy

This project is Free and Open Source Software licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for complete details.
