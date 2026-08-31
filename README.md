<div align="center">

# NOCTRA

### The Autonomous, Privacy-First & 100% Free Music Intelligence Player

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-0052CC.svg?style=for-the-badge)](https://www.gnu.org/licenses/gpl-3.0)
[![FOSS](https://img.shields.io/badge/Type-100%25%20FOSS-00C853.svg?style=for-the-badge)](#-license)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry-7C4DFF.svg?style=for-the-badge)](#-privacy-first--free-to-use)
[![No Ads](https://img.shields.io/badge/Monetization-Zero%20Ads%20%2F%20No%20Login-FF6D00.svg?style=for-the-badge)](#-privacy-first--free-to-use)
[![Flutter](https://img.shields.io/badge/Engine-Flutter%20%7C%20Kotlin%20DSP-02569B.svg?style=for-the-badge&logo=flutter)](https://flutter.dev)

<p align="center">
  <b>Noctra</b> is a modern, high-fidelity music streaming client engineered for audiophiles and privacy purists.<br/>
  It features an <b>on-device two-stage neural recommender (MLP + MMR)</b>, <b>SQLite telemetry</b>, <b>hardware-accelerated DSP audio effects</b>, and a dual <b>Noir liquid-glass aesthetic</b>.
</p>

[Download Latest APK](https://github.com/nomad-guy/Noctra/releases/latest) • [Report a Bug](https://github.com/nomad-guy/Noctra/issues) • [Changelog](CHANGELOG.md) • [Legal & Compliance](#%EF%B8%8F-strict-legal-disclaimer--compliance-policy)

</div>

---

## 🔒 Privacy-First & Free to Use

Noctra is built on the fundamental principle that listening to music should be private, ad-free, and unrestricted.

- **100% Free to Use**: No subscriptions, no paid tier paywalls, no in-app purchases, and no artificial feature locks.
- **Zero Advertisements**: Enjoy uninterrupted, gapless playback without commercial interruptions or audio interstitials.
- **Authentication-Less**: No accounts, emails, phone numbers, or passwords required. Open the app and start listening instantly.
- **Zero Cloud Telemetry**: Your listening history, taste profile, and habits never leave your physical device. All metrics are stored locally in an encrypted SQLite database.

---

## 🌟 Core Features

### 🧠 On-Device Neural Recommendation Engine
- **Stage 1 (Candidate Retrieval)**: Dynamically queries ~100 candidate tracks across local SQLite history, curated libraries, and live charts.
- **Stage 2 (Tiny Neural MLP Ranker)**: A 3-layer Dense Neural Network ($80 \rightarrow 32 \rightarrow 16 \rightarrow 1$) evaluates user embeddings, track features, and contextual signals to compute $P(\text{meaningful engagement})$ in under **1 millisecond** with zero battery drain.
- **Stage 3 (MMR Diversity Reranker)**: Maximal Marginal Relevance ($\lambda = 0.75$) with strict artist caps ensures high-relevance recommendations without playlist fatigue.
- **Online Behavioral Gradient Learning**: Adapts dynamically to micro-signals ($-1.0$ for fast skips, $+1.0$ for full completions, $+1.5$ for replays, $+3.0$ for favorites) with a **14-day exponential half-life recency decay**.

### 🎧 Audiophile-Grade Sound & Hardware DSP
- **Lossless 320kbps CD Quality**: Resolves bit-perfect high-bitrate audio streams directly on-device.
- **Native Android Hardware DSP**: 5-band millibel Equalizer mapped directly to native audio sessions (`android.media.audiofx.Equalizer`).
- **Studio Master Modes**: One-tap DSP presets for *3D Spatial Virtualizer*, *Concert Hall Reverb*, and *BassBoost Exciter*.

### ⚡ Real-Time Synced Lyrics & Dynamic Discovery
- **Millisecond Time-Coded Lyrics**: Word-by-word synchronized LRC playback with intelligent Roman-to-Devanagari transliteration.
- **100% Dynamic Artist Discovery**: Real-time Wikipedia REST API integration for high-resolution artist portraits and biographical summaries.
- **Spotify-Style Onboarding**: Multi-step first-run selector for Languages, Genres, and Artists to immediately seed the neural recommendation space.

### 🌐 P2P SyncCast Jam Studio
- **Decentralized Party Mode**: Stream and synchronize playback across multiple devices on the same local Wi-Fi or mobile hotspot using a low-latency WebSocket protocol with automatic reconnect.

---

## 🏗️ System Architecture

```text
┌──────────────────────────────────────────────────────────┐
│                   USER LISTENING EVENTS                  │
│  Fast Skip (-1.0) | Partial (+0.4) | Full (+1.0) | Fav (+3.0)  │
└────────────────────────────┬─────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────┐
│         ON-DEVICE IMPLICIT SIGNAL TRACKER (SQLITE)       │
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

---

## 📦 Getting Started & Installation

### Option 1: Direct APK Download
Download the latest signed release APK from [GitHub Releases](https://github.com/nomad-guy/Noctra/releases/latest).

### Option 2: Build from Source
```bash
# 1. Clone the repository
git clone https://github.com/nomad-guy/Noctra.git
cd Noctra

# 2. Install Flutter packages
flutter pub get

# 3. Verify test suite (10/10 green)
flutter test

# 4. Build release APK
flutter build apk --release
```

---

## ⚖️ Strict Legal Disclaimer & Compliance Policy

Please read this section carefully before downloading, compiling, or using Noctra.

### 1. Client-Side Only Architecture & Zero Media Hosting
Noctra is strictly a **client-side media browser, parser, and player**. 
- Noctra **does not own, host, store, cache on remote servers, re-encode, or redistribute** any copyrighted music, audio streams, lyrics, or video files.
- All media stream URLs, lyric timestamps, Wikipedia biographical extracts, and metadata are dynamically queried, fetched, and parsed **purely on the end-user's local device** from public web endpoints upon explicit user interaction.

### 2. Non-Commercial & Educational Purpose
Noctra is developed and distributed solely as a **Free and Open Source Software (FOSS)** research and educational tool demonstrating:
- Client-side on-device neural network ranking without server telemetry.
- Hardware-level digital signal processing on mobile operating systems.
- Decentralized peer-to-peer clock synchronization over local networks.

The maintainers do not monetize, sell, license, or profit from the operation of this application in any manner.

### 3. Trademark & Intellectual Property Disclaimers
- All product names, logos, brand names, trademarks, and registered trademarks (*including Spotify, YouTube, YouTube Music, JioSaavn, Wikipedia, and others*) are the property of their respective trademark holders.
- The use of these names and marks within the codebase, documentation, or user interface is strictly for **nominal identification, reference, and technical interoperability** purposes under Fair Use. Noctra is not affiliated with, endorsed by, sponsored by, or officially associated with any of these entities.

### 4. End-User Compliance & Responsibility
- End users are solely responsible for ensuring that their use of Noctra complies with applicable copyright laws, intellectual property regulations, and the terms of service of third-party platforms in their respective legal jurisdictions.
- The developers and contributors of Noctra disclaim any responsibility or legal liability for unauthorized use, misuse, copyright infringement, or violations of third-party platform terms by end users.

### 5. Disclaimer of Warranty & Limitation of Liability
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS **"AS IS"** AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

---

## 📄 License

Noctra is Free and Open Source Software (FOSS) released under the **GNU General Public License v3.0 (GPL-3.0)**.  
You are free to run, study, modify, and redistribute this software in accordance with the terms of the license.

Full license text is available in the [LICENSE](LICENSE) file.

---

<div align="center">
  <sub>Crafted with engineering discipline and privacy by <b>Nomad Guy</b> • <a href="https://github.com/nomad-guy">@nomad-guy</a></sub>
</div>
