<div align="center">

<table border="0">
  <tr>
    <td align="center"><img src="assets/images/logo_noctra_noir_black.png" alt="Noir Black Logo" width="96" height="96" style="border-radius: 20px;" /><br/><sub><b>Noir Black</b></sub></td>
    <td align="center"><img src="assets/images/logo_noctra_liquid_glass.png" alt="Liquid Glass Logo" width="96" height="96" style="border-radius: 20px;" /><br/><sub><b>Liquid Glass</b></sub></td>
    <td align="center"><img src="assets/images/logo_noctra_noir_white.png" alt="Noir White Logo" width="96" height="96" style="border-radius: 20px;" /><br/><sub><b>Noir White</b></sub></td>
  </tr>
</table>

# NOCTRA

### Autonomous, Privacy-First, On-Device Music Intelligence Platform

[![Version: 1.1.6](https://img.shields.io/badge/Release-v1.1.6-black.svg?style=for-the-badge&logo=android)](https://github.com/nomad-guy/Noctra/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-0052CC.svg?style=for-the-badge)](https://www.gnu.org/licenses/gpl-3.0)
[![FOSS](https://img.shields.io/badge/Type-100%25%20FOSS-00C853.svg?style=for-the-badge)](#-privacy-first--free-to-use)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry-7C4DFF.svg?style=for-the-badge)](#-privacy-first--free-to-use)
[![No Ads](https://img.shields.io/badge/Monetization-Zero%20Ads%20%2F%20No%20Login-FF6D00.svg?style=for-the-badge)](#-privacy-first--free-to-use)
[![Tests: 576 Passing](https://img.shields.io/badge/Tests-576%20Passing-brightgreen.svg?style=for-the-badge)](#-automated-testing--verification)
[![Architecture: <= 300 LOC](https://img.shields.io/badge/Architecture-%E2%89%A4%20300%20LOC%20Enforced-blueviolet.svg?style=for-the-badge)](#-strict-modular-architecture--300-loc-hard-limit)
[![Flutter](https://img.shields.io/badge/Framework-Flutter%203.47%20%7C%20Kotlin%20DSP-02569B.svg?style=for-the-badge&logo=flutter)](https://flutter.dev)

<p align="center">
  <b>Noctra</b> is a sovereign high-fidelity music streaming application engineered for audiophiles, privacy purists, and design connoisseurs.<br/>
  Featuring an <b>on-device neural recommender (120-dim MLP + MMR)</b>, <b>zero-telemetry SQLite engine</b>, <b>hardware-accelerated Android DSP</b>, <b>6-tier composite stream resolution</b>, and a bespoke <b>Triple Noir design language</b>.
</p>

[Download Release APK](https://github.com/nomad-guy/Noctra/releases/latest) • [Technical Architecture](ARCHITECTURE.md) • [Changelog](CHANGELOG.md) • [Release Notes](RELEASE_NOTES.md) • [Legal & Compliance](#-comprehensive-legal-notice-intellectual-property--compliance-policy)

</div>

---

## 🛡️ Privacy-First & Free to Use

Noctra operates on an uncompromising philosophy: your musical identity and listening habits are private, sovereign, and belong exclusively to you.

- **100% Free & Open Source (FOSS)**: Zero subscription fees, zero paywalls, zero in-app purchases, and no feature gating.
- **Zero Commercial Advertisements**: Continuous, uninterrupted playback with zero audio interstitials, banner ads, or tracking pixels.
- **Authentication-Less**: No accounts, emails, phone numbers, Google login, or passwords. Install and start listening in seconds.
- **Zero Cloud Telemetry**: Listening history, play counts, taste profiles, and skipped tracks never leave your physical device. All metrics are computed and stored in an on-device encrypted SQLite database.
- **Offline Resilient**: Direct vault storage for offline playback in high-fidelity 320kbps MP3 and high-bitrate AAC.

---

## 🎨 The Triple Noir Design System

Noctra is crafted around a bespoke design language inspired by luxury Swiss typography and minimal high-end audio engineering:

| Theme Trinity | Visual Experience | Technological Highlights |
| :--- | :--- | :--- |
| **Noir Black** | Signature obsidian glassmorphism | Deep charcoal/black surfaces (`#0A0A0A`), 16px fluid radii, specular borders, and layered frosted glass. |
| **Noir White** | High-contrast editorial monochrome | Paper-white backgrounds, sharp typography, and daylight-readable layouts designed for bright environments. |
| **Liquid Glass** | Ambient sapphire blur | Deep sapphire blue glassmorphism (`#162E4A`), dynamic background refraction, and real-time backdrop blur. |

> [!NOTE]
> Noctra strictly implements the **Triple Noir** system (**Noir Black**, **Noir White**, and **Liquid Glass**). AMOLED has been deprecated in favor of authentic Noir glass styling. The Android launcher icon dynamically synchronizes in the background to match your active in-app theme.

---

## ⚙️ Core Architectural Pillars & Capabilities

### 1. 🏗️ Strict Modular Architecture ($\le$ 300 LOC Hard Limit)
Every single Dart, Kotlin, and Java source file across the entire repository strictly adheres to a **300 LOC maximum ceiling**. Monolithic classes have been broken down into single-responsibility delegates:
- **Playback Delegates**: `PlayerCrossfadeEngine`, `PlayerSessionLoader`, `PlayerCrossfadeRamp`, `PlayerAutoplayManager`, and `PlayerPlaybackController`.
- **Native Android Delegates**: `AudioChannelsDelegate`, `VisualizerChannelDelegate`, `InstallerChannelDelegate`, `ResolverChannelDelegate`, `LauncherIconChannelDelegate`, and `StemDspHelper`.
- **Rebuild Scope Isolation**: `LibrarySongRow` isolates playback updates to visible rows, eliminating parent list re-evaluations during active playback ticks.

### 2. 🧠 On-Device Neural Recommendation Engine
- **120-Dimensional Vector Space**: Captures acoustic features (energy, danceability, valence, tempo), listening contexts (time of day, day of week), user affinity, and cross-genre interactions.
- **On-Device 4-Layer MLP Ranker**: A deep feedforward neural network (120 $\rightarrow$ 64 $\rightarrow$ 32 $\rightarrow$ 16 $\rightarrow$ 1) scores candidate tracks in under 1 millisecond on-device.
- **Maximal Marginal Relevance (MMR)**: Diversity filtering with configurable $\lambda = 0.75$ reranks recommendations to eliminate artist fatigue and genre echo chambers.
- **Continuous Behavioral Gradient Learning**: Dynamically updates user taste vectors based on natural micro-interactions (+1.0 for track completion, +1.5 for immediate replay, +3.0 for favorites, -1.0 for fast skips) with an exponential 14-day half-life decay.

### 3. 🎵 6-Tier Composite Stream Resolver
A self-healing, multi-tier stream resolution pipeline guarantees continuous playback availability:
```text
  [Song Request]
        │
        ├── Tier 1: Local Disk Vault Cache (Instant 320k)
        ├── Tier 2: Direct Validated HTTPS Stream
        ├── Tier 3: JioSaavn 320kbps CD Lossless Master (On-Device Decryption)
        ├── Tier 4: Native Android Kotlin Audio Extractor (Hardware-Assisted)
        ├── Tier 5: YouTube Music InnerTube REST API (Adaptive Opus/AAC)
        └── Tier 6: YouTube Web Search Fallback Resolver (Autonomous Recovery)
```

### 4. 🔒 Enterprise-Grade Resolver Security
- **Strict Host Whitelist**: Remote audio endpoints are constrained to cryptographically verified audio CDN domains.
- **Anti-SSRF Protections**: Forbids loopback (`127.0.0.1`, `localhost`), link-local, broadcast, private RFC 1918 subnets, and non-HTTPS URLs.
- **Hop-by-Hop Redirect Verification**: Every redirection hop is independently verified against the security whitelist before initiating audio connections.

### 5. 📜 Multi-Script Synced Lyrics & Poetic Translation
- **Millisecond Synced Lyrics**: Sub-frame accurate synchronized LRC scrolling with LRCLIB, JioSaavn, and InnerTube lyrics providers.
- **Brahmic Indic Script Matrix (Sanscript Engine)**: Zero-latency offline transliteration across **Devanagari, Gurmukhi, Bengali, Gujarati, Telugu, Tamil, Kannada, Malayalam, and Odia**.
- **Global Script Transliteration**: Native transliteration for **Japanese (Romaji), Korean (Hangul $\rightarrow$ Roman), Chinese (Pinyin), Cyrillic, Arabic, Greek, Thai (RTGS), and Hebrew**.
- **Semantic Translation Engine**: 3-layer lexicon with intelligent Hindi schwa-deletion heuristics and real-time word learning.

### 6. 🎛️ Hardware-Accelerated Audio DSP & Visualizers
- **Android Native Kotlin DSP**: 5-band parametric equalizer, dynamic loudness enhancer, bass boost exciter, and 3D spatial virtualizer.
- **Studio Master Presets**: Lossless 320k Master, Spatial 3D Soundstage, and Concert Hall Reverb.
- **Hardware-Accelerated Visualizers**: 32-Band Spectrum Bars with harmonic blending and falling peak markers, Radial Sound Glow, and 3D Synthwave Cyber Grid.

### 7. 👥 Decentralized P2P SyncCast (Party Mode)
- Synchronize playback across multiple devices over local Wi-Fi or mobile hotspots using a lightweight WebSocket protocol.
- Automatic device discovery, low-latency clock drift compensation, and cryptographic room secret authentication with zero external server dependencies.

### 8. 📦 Resilient Library Migration & Importers
- Native importers for **Spotify**, **Apple Music**, **YouTube Music**, **JioSaavn**, and standard **CSV/M3U** files.
- Resilient chunked database commits (500 songs per batch) eliminate UI lockup and memory pressure during massive 10,000+ track imports.

### 9. 🌐 Native Internationalization (i18n)
- Native localization for **8 languages**: English, Hindi (हिंदी), Punjabi (ਪੰਜਾਬੀ), Urdu (اردو), Kannada (ಕನ್ನಡ), Tamil (தமிழ்), Marathi (मराठी), and Odia (ଓଡ଼ିଆ).

---

## 🛠️ Building and Running from Source

### System Prerequisites
- **Flutter SDK**: 3.24.0 or higher (`channel stable`)
- **Android SDK**: API Level 26 (Android 8.0) through API Level 35 (Android 15+)
- **Java Development Kit**: JDK 17 (recommended: OpenJDK 17)

### Terminal Commands
```bash
# 1. Clone the Noctra repository
git clone https://github.com/nomad-guy/Noctra.git
cd Noctra

# 2. Retrieve Flutter dependencies
flutter pub get

# 3. Verify static code analysis (0 issues enforced)
flutter analyze

# 4. Run automated test suite (576 passing tests)
flutter test

# 5. Compile the optimized release APK
flutter build apk --release
```

Release APK binaries will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧪 Automated Testing & Verification

Noctra enforces rigorous automated test coverage across all architectural components:
- **576/576 Automated Tests Passing** (`flutter test`)
- **0 Static Analysis Warnings or Errors** (`flutter analyze`)
- **100% Architectural Compliance**: Every source file verified to be $\le$ 300 LOC.

---

## ⚖️ Comprehensive Legal Notice, Intellectual Property & Compliance Policy

**Please read this legal notice carefully before downloading, compiling, contributing to, or operating Noctra.**

### 1. Client-Side Architecture & Zero Media Hosting
Noctra is strictly an on-device client application, parser, and media playback interface.
- **No Hosting or Storage**: Noctra does **NOT** own, host, store, cache on remote servers, re-encode, or redistribute any audio recordings, copyrighted music files, lyrical compositions, artwork, or video streams.
- **Client-Side Query Resolution**: All stream URLs, metadata, cover art, and lyrical timestamp data are fetched and parsed directly on the end-user's local device from publicly accessible web endpoints and CDNs upon explicit user invocation.
- **No Cloud Proxies or Relays**: Noctra operates without intermediary relay servers, cloud stream caches, or proprietary proxy backends.

### 2. Non-Commercial Educational & Research Scope
Noctra is developed, maintained, and distributed strictly as a Free and Open Source Software (FOSS) educational and research project under the GNU General Public License v3.0. The project is created solely to research and demonstrate:
- Efficient on-device deep learning recommendation models running on mobile edge hardware without central data collection.
- Decentralized, serverless peer-to-peer clock synchronization over local ad-hoc networks.
- Hardware-accelerated digital signal processing (DSP) pipelines on modern mobile operating systems.
- Zero-telemetry, privacy-preserving client-side database management.

**Noctra is not commercial software.** The developers and maintainers do not monetize, sell, license, collect subscriptions for, display paid advertisements within, or derive commercial profit from this project.

### 3. Nominative Fair Use & Third-Party Trademarks
- All third-party company names, platform names, service names, logos, and registered trademarks—including but not limited to **Spotify**, **Apple Music**, **YouTube**, **YouTube Music**, **JioSaavn**, **Deezer**, **MusicBrainz**, **LRCLIB**, and **Android**—are the intellectual property of their respective owners.
- The use of these trademarks within the Noctra codebase, user interface, or documentation is strictly for **nominative, identification, descriptive, and technical interoperability purposes** under Fair Use doctrine.
- Noctra is an independent open-source project and is **not** endorsed by, affiliated with, sponsored by, or associated with any of the aforementioned companies or trademark holders.

### 4. End-User Compliance & Permissible Use
- **User Responsibility**: End users are solely and independently responsible for ensuring that their use of Noctra complies with all applicable local, national, and international copyright laws, intellectual property statutes, and third-party terms of service in their legal jurisdiction.
- **Indemnification**: The developers, maintainers, and contributors of Noctra explicitly disclaim all liability and legal responsibility for unauthorized use, copyright infringement, terms-of-service violations, or improper deployment of this application by end users.

### 5. Digital Millennium Copyright Act (DMCA) & Safe Harbor Notice
Because Noctra is an open-source client application distributed without central servers, and because Noctra hosts no media files, streams, or intellectual property on any remote server infrastructure:
- Any concerns regarding media content or stream availability should be directed to the respective third-party service or content host where that media is published.
- If you are a copyright holder with questions regarding the open-source code in this repository, please review our [LICENSE](LICENSE) or submit an inquiry through GitHub issues for constructive resolution.

### 6. Disclaimer of Warranty & Limitation of Liability
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT ARE ENTIRELY DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

---

## 📄 License

Copyright (C) 2026 Nomad Guy

This project is Free and Open Source Software licensed under the **GNU General Public License v3.0 (GPL-3.0)**.  
You are free to inspect, run, modify, and redistribute this software in accordance with the terms of the license.

See the complete [LICENSE](LICENSE) file for legal terms.

---

<div align="center">
  <sub>Engineered with architectural discipline, privacy, and precision by <b>Nomad Guy</b> • <a href="https://github.com/nomad-guy">@nomad-guy</a></sub>
</div>
