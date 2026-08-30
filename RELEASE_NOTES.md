# Noctra v1.0.0 Release Notes

Next-Generation Autonomous Music Streaming Platform & On-Device AI Intelligence Engine.

---

## APK Download Guide: Which Version Should You Download?

| File Name | Architecture | File Size | Recommended Device Target |
| :--- | :--- | :--- | :--- |
| **`Noctra-v1.0.0-arm64-v8a.apk`** | `arm64-v8a` | **22.1 MB** | **RECOMMENDED FOR 99% OF USERS.** Modern Android smartphones and tablets (Snapdragon, MediaTek, Exynos, Tensor, 64-bit Android 8.0+). |
| **`Noctra-v1.0.0-armeabi-v7a.apk`** | `armeabi-v7a` | **19.8 MB** | Older 32-bit Android smartphones and budget legacy devices. |
| **`Noctra-v1.0.0-x86_64.apk`** | `x86_64` | **23.5 MB** | Android emulators (BlueStacks, Android Studio Emulator, WSA), Chromebooks, and Intel/AMD tablets. |
| **`Noctra-v1.0.0-Universal.apk`** | Universal | **59.1 MB** | Universal "Fat" APK bundled with all architectures combined. Works on any device if you are unsure which architecture you have. |

---

## What's New in v1.0.0

### High-Fidelity Audio Discovery & Streaming Engine
- **JioSaavn 320kbps CD Lossless Master**: Direct on-device DES stream decryption resolving bit-perfect 320kbps audio.
- **YouTube Music InnerTube REST Direct Extractor**: Direct REST JSON extraction via `ANDROID_MUSIC` client payloads delivering high-bitrate Opus/AAC adaptive streams with zero sidecar dependencies.
- **AutoMix Radio Queue**: Automatically fetches and appends related algorithmic radio tracks when the queue finishes.
- **SponsorBlock Music Video Intro Skip**: Automatically skips non-music talking intros, skits, and video silences.
- **Sleep Timer**: Configurable countdown (15m, 30m, 45m, 60m) with exponential volume fade-out.
- **Studio DSP Master Modes**: Real-time sound profiles for Lossless 320k, Spatial 3D Soundstage, and Concert Reverb.

### Multi-Engine Frame-Accurate Synced Lyrics
- **5-Tier Lyrics Resolution**: Lrclib millisecond-synced LRC, Lrclib fuzzy database search, YouTube Music InnerTube official verified distributor lyrics, JioSaavn native regional master lyrics, and Lyrics.ovh.

### On-Device 16-Axis Neural Vector Recommendation
- 100% private on-device vector space modeling 16 acoustic dimensions (Dark Tone, Energy, Melancholy, Chill Factor, Analog Synth, and more).
- Reinforcement learning reward shaping (+0.10 on completion, -0.06 on fast skip, +0.16 on favorite).
- Cosine similarity ranking and AI Radio curation.

### Liquid Noir Design System & Triple Themes
- **Triple Theme Trinity**: Noir Black (Obsidian Liquid Glass), Noir White (Editorial Minimal), and AMOLED (True `#000000` pitch black).
- **Dynamic Launcher Icon**: Automatically synchronizes the Android launcher app icon with the active theme.
- **Mini-Player Swipe Gestures**: Swipe left/right to skip tracks and swipe up to open the full-screen player sheet.

### Hardware-Accelerated Audio Visualizers
- **32-Band Spectrum Bars**: Multi-band harmonic blending with realistic acoustic attack, smooth decay, and falling peak markers.
- **Radial Sound Glow**: Amplitude-reactive concentric circular pulse.
- **3D Synthwave Cyber Grid**: Perspective retro-futuristic grid with reactive neon horizon lines.

### P2P SyncCast Jam Mode
- Local decentralized WebSocket synchronization engine for zero-server party listening over Wi-Fi or mobile hotspots.
