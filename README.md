# Noctra

**Next-Generation Autonomous Music Streaming Platform & On-Device AI Intelligence Engine**

Developed by **Nomad Guy**  
- **GitHub Profile**: [https://github.com/nomad-guy](https://github.com/nomad-guy)
- **Official Repository**: [https://github.com/nomad-guy/Noctra](https://github.com/nomad-guy/Noctra)

---

## Overview

Noctra is an autonomous, privacy-focused, on-device music streaming platform built with Flutter, Dart, and Riverpod. It combines high-fidelity audio discovery (JioSaavn 320kbps CD lossless and YouTube Music InnerTube direct extraction), on-device 16-axis vector recommendation, multi-tier synchronized lyrics, local P2P party synchronization, hardware-accelerated audio visualizers, and a Liquid Noir user interface.

---

## Key Architectural Features

### 1. Multi-Tier Audio Streaming Engine
- **Tier 1 (JioSaavn 320kbps CD Lossless)**: Direct on-device DES decryption resolving bit-perfect 320kbps MP4/AAC audio.
- **Tier 2 (YouTube Music InnerTube REST Direct)**: Direct REST JSON extraction via `ANDROID_MUSIC` client payloads delivering high-bitrate Opus/AAC adaptive streams without third-party sidecars.
- **Tier 3 (YouTube Explode)**: Robust manifest fallback resolver for edge-case video streams.
- **Tier 4 (Local Offline Library)**: Offline audio scanner indexing and playing downloaded MP3/FLAC/M4A files.

### 2. AutoMix & Seamless Playback Pipeline
- **AutoMix Radio Queue**: Automatically fetches and appends related algorithmic radio tracks when the current playback queue completes.
- **Sleep Timer**: Configurable countdown (15m, 30m, 45m, 60m) with exponential volume fade-out.
- **SponsorBlock Integration**: Automatically bypasses non-music talking intros, skits, and video padding.
- **Studio DSP Master Modes**: Real-time sound profiles for Lossless 320k, Spatial 3D Soundstage, and Concert Reverb.

### 3. Multi-Engine Frame-Accurate Synced Lyrics
- **Lrclib Synchronized LRC**: Primary millisecond time-coded lyric synchronization with word-level highlight tracking.
- **Lrclib Global Database**: Fuzzy metadata search fallback for live, remixed, and international songs.
- **YouTube Music InnerTube Lyrics**: Official verified distributor lyrics extracted from YouTube Music browse endpoints.
- **JioSaavn Master Lyrics**: Native Hindi, Punjabi, Tamil, and Romanized script lyrics.
- **Lyrics.ovh**: International plain-text lyrics fallback.

### 4. On-Device 16-Axis Neural Vector Recommendation
- Zero cloud dependence: 100% private vector space modeling musical affinities across 16 acoustic dimensions (Dark Tone, Ambient Depth, Energy, Chill Factor, Melancholy, Acoustic Warmth, Analog Synth, Night Drive, and more).
- Reinforcement learning reward shaping updating taste weights in real time based on user interactions (+0.10 on completion, -0.06 on fast skip, +0.16 on favorite).
- Cosine similarity ranking and AI Radio curation with transparent natural-language match explanations.

### 5. Liquid Noir Design System & Triple Theme Trinity
- **Noir Black**: Obsidian liquid glass with specular reflections and backdrop blur filters.
- **Noir White**: Clean editorial minimal white aesthetic with high-contrast typography.
- **AMOLED Pitch Black**: True `#000000` surface designed for zero OLED battery consumption.
- **Dynamic Launcher Icon**: Automatically synchronizes the Android launcher app icon with the active theme.
- **Mini-Player Gestures**: Horizontal swipe left/right to skip tracks and vertical swipe up to open the player sheet.

### 6. Hardware-Accelerated Audio Visualizers
- **32-Band Spectrum Bars**: Multi-band harmonic blending with realistic acoustic attack, smooth decay, and falling peak markers.
- **Radial Sound Glow**: Concentric circular pulse reactive to audio amplitude.
- **3D Synthwave Cyber Grid**: Perspective retro-futuristic grid with reactive neon horizon lines.

### 7. P2P SyncCast (Party Mode)
- Local decentralized WebSocket synchronization engine broadcasting audio state and clock offsets over local Wi-Fi or mobile hotspots with zero external servers.

---

## Building and Running

### Prerequisites
- Flutter SDK (v3.19.0 or higher)
- Android SDK (API Level 21 to 34)
- Java 17 / OpenJDK 17

### Commands
```bash
# Clone the repository
git clone https://github.com/nomad-guy/Noctra.git
cd Noctra

# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Build optimized split APKs
flutter build apk --split-per-abi --release
```

---

## License

PROPRIETARY - PERSONAL USE & RESTRICTED INSPECTION LICENSE  
Copyright (c) 2026 Nomad Guy. All rights reserved.  
Permission is granted to use the app for personal listening, but strictly prohibited to modify, unpack, tamper, or reverse engineer it. See [LICENSE](LICENSE) for full legal terms.
