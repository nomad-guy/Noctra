<p align="center">
  <img src="assets/images/logo_noctra_noir_black.png" alt="Noctra Logo" width="128" height="128" />
</p>

<h1 align="center">NOCTRA</h1>

<p align="center">
  <b>Autonomous, Privacy-Sovereign, On-Device Music Intelligence Platform</b>
</p>

<p align="center">
  <a href="https://github.com/nomad-guy/Noctra/releases/tag/v1.0.0"><img src="https://img.shields.io/badge/Release-v1.0.0-000000.svg?style=flat-square" alt="Release v1.0.0" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-000000.svg?style=flat-square" alt="License GPL-3.0" /></a>
  <a href="#privacy-architecture"><img src="https://img.shields.io/badge/Telemetry-0%25-000000.svg?style=flat-square" alt="Zero Telemetry" /></a>
  <a href="#automated-verification"><img src="https://img.shields.io/badge/Tests-780%2B%20Passing-000000.svg?style=flat-square" alt="780+ Tests Passing" /></a>
  <a href="#codebase-architecture"><img src="https://img.shields.io/badge/Architecture-%E2%89%A4300%20LOC-000000.svg?style=flat-square" alt="Modular Architecture" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Framework-Flutter%203.47-000000.svg?style=flat-square" alt="Flutter" /></a>
</p>

<p align="center">
  <a href="#production-release-downloads">Downloads</a> &bull;
  <a href="ARCHITECTURE.md">Architecture</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="RELEASE_NOTES.md">Release Notes</a> &bull;
  <a href="#legal-notice-and-statutory-compliance-policy">Legal Notice</a>
</p>

---

## Overview

Noctra is an authentication-less, privacy-first audio streaming and collection client engineered for Android. Built with Flutter, Dart, Riverpod, and native Android Kotlin digital signal processing delegates, Noctra executes recommendation ranking, vector embeddings, query routing, and library persistence entirely on the local device without intermediary servers or remote telemetry collection.

---

## Production Release Downloads

Direct binary artifacts for version 1.0.0. Every artifact is signed with the official Noctra release key and compiled with ProGuard and R8 bytecode optimization.

```text
Noctra-1.0.0-arm64-v8a.apk (22.1 MB) — Modern 64-bit Android devices (Android 8.0+)
Noctra-1.0.0-armeabi-v7a.apk (19.9 MB) — Legacy 32-bit ARM devices
Noctra-1.0.0-x86_64.apk (23.6 MB) — Emulators and x86_64 Chromebooks / tablets
Noctra-1.0.0-universal.apk (60.7 MB) — Universal multi-ABI compatibility fallback
```

### Artifact Manifest

| Package | Architecture | Direct Download | SHA-256 Digest |
| :--- | :--- | :--- | :--- |
| `Noctra-1.0.0-arm64-v8a.apk` | `arm64-v8a` | [Download](https://github.com/nomad-guy/Noctra/releases/download/v1.0.0/Noctra-1.0.0-arm64-v8a.apk) | `48641fd75b8c10ebda88b6393defc5646c78c9a9ccb5494fca643e0b51eae0f1` |
| `Noctra-1.0.0-armeabi-v7a.apk` | `armeabi-v7a` | [Download](https://github.com/nomad-guy/Noctra/releases/download/v1.0.0/Noctra-1.0.0-armeabi-v7a.apk) | `9be3a18f502612cdb488fe17397b3c2ccde7171d107e360091fa1284c5452a5f` |
| `Noctra-1.0.0-x86_64.apk` | `x86_64` | [Download](https://github.com/nomad-guy/Noctra/releases/download/v1.0.0/Noctra-1.0.0-x86_64.apk) | `aaa4f649bae13acb9ece4ee66d90673505be7aa44201c501c838095909f3604b` |
| `Noctra-1.0.0-universal.apk` | Universal | [Download](https://github.com/nomad-guy/Noctra/releases/download/v1.0.0/Noctra-1.0.0-universal.apk) | `94d7b1d1fd31b75fa9d299a963b2b8ad82d086c9a232b221d4ebad4f466214ea` |

### Integrity Verification
Verify all downloaded binaries against the official checksum manifest:
```bash
sha256sum -c SHA256SUMS.txt
```

---

## Privacy Architecture

Noctra operates under a strict zero-knowledge, zero-telemetry architectural boundary:

- **Zero Remote Telemetry**: Playback history, search queries, skip rates, and taste profiles never leave the physical device.
- **Authentication-Less**: No accounts, emails, telephone numbers, or OAuth logins. The application initializes directly into a functional state upon launch.
- **Encrypted Local Storage**: Playlists, listening graphs, and downloaded media metadata reside in an encrypted SQLite database on local storage.
- **Self-Contained Network Queries**: Outbound HTTP requests originate directly from the client to public endpoints without routing through proxy servers or proprietary cloud relays.

---

## The Triple Noir Design System

The visual interface is built on Swiss typography, strict contrast ratios, and minimalist geometric surfaces:

| Theme | Description | Specifications |
| :--- | :--- | :--- |
| **Noir Black** | Obsidian glassmorphism | `#0A0A0A` background, 16px fluid radii, subtle specular borders, and frosted glass layering. |
| **Noir White** | Editorial monochrome | High-contrast paper white, structured typography, and daylight-readable surfaces. |
| **Liquid Glass** | Sapphire optical blur | Deep sapphire refraction (`#162E4A`), dynamic backdrop blur, and hardware-accelerated shaders. |

The Android launcher icon dynamically synchronizes in the background via Activity aliases to match the active in-app theme selection.

---

## Core System Architecture

### 1. Composite Stream Resolution
Playback relies on a prioritized, self-healing 6-tier stream resolution pipeline:

```text
Stream Request
      |
      +---> Tier 1: Local Disk Vault (320kbps MP3 / High-bitrate AAC)
      |
      +---> Tier 2: Validated Direct HTTPS Stream
      |
      +---> Tier 3: JioSaavn 320kbps CD Lossless Master
      |
      +---> Tier 4: Native Android Kotlin Extractor
      |
      +---> Tier 5: YouTube Music InnerTube REST API (Adaptive Opus/AAC)
      |
      +---> Tier 6: YouTube Search Fallback Resolver
```

### 2. Network Security & SSRF Protection
- **Host Whitelisting**: Connections are restricted to verified audio CDN hostnames.
- **Anti-SSRF Enforcement**: Rejects loopback (`127.0.0.1`, `localhost`), link-local, broadcast, and RFC 1918 private subnets.
- **Redirect Validation**: Follows HTTP 3xx redirects only after independently validating destination hosts against security boundaries.

### 3. On-Device Neural Recommender
- **120-Dimensional Representation**: Encodes acoustic metrics, temporal listening context, and genre affinities.
- **4-Layer MLP Classifier**: Deep feedforward network (120 to 64 to 32 to 16 to 1) scoring candidates with sub-millisecond on-device latency.
- **Maximal Marginal Relevance (MMR)**: Configurable diversity reranking parameter ($\lambda = 0.75$) preventing artist saturation.
- **Behavioral Reward Shaping**: Gradient updates driven by natural user interactions (+1.0 completion, +1.5 immediate replay, +3.0 favorite, -1.0 quick skip) with an exponential 14-day half-life decay.

### 4. Codebase Architecture
- **Strict LOC Limits**: Every source file in `lib/`, `test/`, and `android/` is bounded to $\le$ 300 lines of code, verified mechanically during CI.
- **Decoupled Engine Delegates**: Audio operations are modularized into `PlayerCrossfadeEngine`, `PlayerSessionLoader`, `PlayerCrossfadeRamp`, `PlayerAutoplayManager`, and `PlayerPlaybackController`.
- **Rebuild Scope Isolation**: `LibrarySongRow` manages localized consumer rebuilds to eliminate full-list rendering during active playback ticks.

### 5. Google Assistant & MediaSession Integration
- **MediaBrowserService Content Hierarchy**: Exposes structured navigation roots for Favorites, Downloads, Recently Played, Playlists, Albums, Artists, and AI Recommendations.
- **Voice Search Routing**: Handles `android.media.action.MEDIA_PLAY_FROM_SEARCH` with query normalization, artist and album extras filtering, and candidate validation.
- **Wrong-Song Protection**: Resolves queries through identity validation gates, duration checks, and candidate matching guards.
- **Native Session Actions**: Full MediaSession integration for play, pause, seek, fast-forward, rewind, queue management, and dynamic theme switching.

### 6. Hardware-Accelerated Audio DSP
- **Native Kotlin Equalizer**: 5-band parametric equalizer with studio master presets.
- **Dynamic Processing**: Bass boost exciter, virtualizer, and loudness enhancer.
- **Real-Time Visualizers**: 32-band spectrum analysis with harmonic peak markers, radial glow, and 3D synthwave rendering.

### 7. Multi-Script Lyrics & Translation Engine
- **Synchronized LRC**: Sub-frame synchronized scrolling via LRCLIB, JioSaavn, and InnerTube.
- **Indic Script Transliteration**: Real-time Sanscript engine covering Devanagari, Gurmukhi, Bengali, Gujarati, Telugu, Tamil, Kannada, Malayalam, and Odia.
- **International Transliteration**: Native transliteration for Japanese (Romaji), Korean (Hangul to Roman), Chinese (Pinyin), Cyrillic, Arabic, Greek, Thai, and Hebrew.
- **Semantic Translation**: 3-layer translation lexicon with intelligent schwa-deletion heuristics.

### 8. Decentralized P2P SyncCast
- Peer-to-peer playback synchronization across local Wi-Fi or mobile hotspots using a lightweight WebSocket protocol.
- Automated peer discovery, sub-millisecond clock drift compensation, and cryptographic room verification without external server dependencies.

---

## Building from Source

### Prerequisites
- Flutter SDK: `3.24.0` or higher (Channel stable)
- Android SDK: API Level 26 through API Level 36
- Java Development Kit: JDK 17

### Build Commands
```bash
# Clone the repository
git clone https://github.com/nomad-guy/Noctra.git
cd Noctra

# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Execute test suite
flutter test

# Build release APKs (split by ABI)
flutter build apk --release --split-per-abi
```

Binaries will be generated in `build/app/outputs/flutter-apk/`.

---

## Automated Verification

Noctra enforces comprehensive quality and safety checks:
- **780+ Passing Tests**: Full unit, integration, and regression coverage (`flutter test`).
- **Zero Static Analysis Issues**: Clean analyzer run with zero warnings and zero errors (`flutter analyze`).
- **Architectural Boundary Enforcement**: LOC ceilings and import cycle bans verified by `test/architecture_boundaries_test.dart`.
- **Release Manifest Validation**: Automated on-disk verification of generated APK binaries and SHA-256 digests (`test/release_manifest_verification_test.dart`).

---

## Legal Notice and Statutory Compliance Policy

**Please review this compliance policy carefully before downloading, compiling, contributing to, or operating Noctra.**

### 1. Pure Client-Side User Agent Architecture & Zero Cloud Infrastructure
Noctra is strictly an on-device client application, parser, and user interface. It is architecturally analogous to a local web browser, terminal user agent, or media player.
- **Zero Content Hosting**: Noctra does not host, store, cache on remote servers, re-encode, or distribute any audio recordings, copyrighted music files, lyrical compositions, artwork, or video streams.
- **Zero Centralized Relays**: The maintainers do not operate, manage, finance, or provide streaming servers, proxy backends, cloud caches, or content distribution networks.
- **Local Resolution**: All network transactions occur directly between the user's local device and publicly accessible third-party endpoints, initiated solely upon explicit user command.

### 2. Anti-Circumvention Compliance (17 U.S.C. § 1201)
Noctra complies with all statutory anti-circumvention provisions:
- **Zero DRM Decryption**: Noctra does not bypass, defeat, remove, crack, or circumvent Digital Rights Management (DRM) mechanisms, cryptographic access controls, or subscription paywalls (such as Widevine, FairPlay, or PlayReady).
- **Public Endpoints Only**: All stream resolution relies strictly on unencrypted, publicly accessible HTTP endpoints provided by third-party services to standard web clients.

### 3. Non-Commercial Educational & Interoperability Research Scope
Noctra is published as free and open-source software under the **GNU General Public License v3.0 (GPL-3.0)**, conducted in accordance with:
- **Section 107 of the United States Copyright Act (17 U.S.C. § 107)** regarding Fair Use for research and scholarship.
- **Directive 2009/24/EC of the European Parliament and of the Council (Article 6)** regarding decompilation for interoperability research.
- **Academic Research Focus**: Mobile-edge deep neural ranking architectures, serverless peer-to-peer clock synchronization, hardware-assisted DSP audio processing, and zero-telemetry database design.

Noctra is strictly non-monetized. The maintainers do not sell subscriptions, display advertisements, license proprietary features, or derive commercial profit from this project.

### 4. Third-Party Trademarks & Nominative Fair Use
All third-party corporate names, brand marks, and registered trademarks—including Spotify, Apple Music, YouTube, YouTube Music, JioSaavn, Deezer, MusicBrainz, LRCLIB, Google, and Android—are the property of their respective owners.
Their reference within this codebase and documentation is strictly for identification, technical compatibility, and nominative fair use. Noctra is an independent project and is not endorsed by, sponsored by, or affiliated with any trademark owner.

### 5. Sovereign User Responsibility & Indemnification
- **User Agency**: Users exercise sole and independent control over their operation of the software. Users are solely responsible for ensuring that their use complies with all applicable municipal, state, national, and international laws, copyright regulations, and third-party terms of service in their jurisdiction.
- **Indemnification**: By compiling, downloading, or running this software, users agree to indemnify, defend, and hold harmless the authors, maintainers, and contributors from any claims, liabilities, losses, damages, or legal expenses resulting from the user's operation, network queries, or misuse of the application.

### 6. DMCA & Service Provider Notices
Because Noctra possesses no central server infrastructure and hosts no media files:
- Notices regarding media availability must be directed to the third-party web host serving the content.
- Inquiries regarding the open-source code in this repository may be submitted via GitHub Issues for prompt review.

### 7. Disclaimer of Warranty (GPLv3 § 15)
THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM RESTS WITH THE USER.

### 8. Limitation of Liability (GPLv3 § 16)
IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING FROM THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING LOSS OF DATA, CORRUPTION, OR LOSSES SUSTAINED BY THIRD PARTIES), EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

---

## License

Copyright &copy; 2026 Nomad Guy

This project is Free and Open Source Software licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See the complete [LICENSE](LICENSE) file for legal details.

<p align="center">
  <sub>Engineered by <b>Nomad Guy</b> &bull; <a href="https://github.com/nomad-guy">@nomad-guy</a></sub>
</p>
