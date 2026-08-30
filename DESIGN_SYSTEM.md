# Noctra UI/UX Design System & Experience Architecture

Noctra combines Spotify's familiar layout with a Glassmorphic Noir Aesthetic (Noir White & Noir Black), instant song search, 1-tap download, and an on-device Python ML intelligence bridge.

---

## 1. Brand Identity & Logo

The Noctra logo fuses a lunar crescent (reflecting late-night listening) with an audio soundwave pulse, finished with glassmorphic rim lighting and luxury obsidian typography.

- **Colors**: Obsidian (`#080808`), Crisp White (`#FFFFFF`), Muted Slate (`#8E8E93`)
- **Tone**: Sophisticated, Minimalist, Nocturnal, Editorial

---

## 2. Dual Noir UI/UX Experience

The UI is built with frosted glass surfaces (`backdrop-filter: blur(20px)`), subtle translucent borders, and high-contrast typography, making album art and playback controls visually prominent.

| Attribute | Noir White | Noir Black |
| :--- | :--- | :--- |
| **Canvas** | `#F7F7F7` (Clean Editorial Off-White) | `#080808` (Deep Infinite Obsidian) |
| **Glass Card** | `rgba(255, 255, 255, 0.75)` + `#E5E5E5` 1px border | `rgba(18, 18, 18, 0.70)` + `rgba(255, 255, 255, 0.08)` 1px border |
| **Text Primary** | `#0A0A0A` | `#F5F5F5` |
| **Text Secondary** | `#666666` | `#8E8E93` |
| **Accent Action** | High-contrast Carbon `#121212` | Crisp Monochromatic White `#FFFFFF` |
| **Glass Blur** | `20px` Gaussian Blur | `24px` Gaussian Blur |

---

## 3. Spotify-Inspired Simplified Navigation & Features

The app is structured around a 4-tab navigation with a persistent floating glass mini-player:

```text
+------------------------------------------------------------+
| NOCTRA                      [ Search / Paste URL... ]      |
+------------------------------------------------------------+
|                                                            |
|  Made For You (AI Knowledge Graph Mix)                     |
|  +----------+ +----------+ +----------+                    |
|  | Midnight | | Lo-Fi    | | Dark     |                    |
|  | Driving  | | Echoes   | | Synth    |                    |
|  +----------+ +----------+ +----------+                    |
|                                                            |
|  Top Trending Hits & Local Downloads                       |
|  +------------------------------------------------------+  |
|  | [Art] Track Name - Artist       03:42  [1-Tap DL]    |  |
|  +------------------------------------------------------+  |
|  | [Art] Track Name - Artist       04:15  [1-Tap DL]    |  |
|  +------------------------------------------------------+  |
|                                                            |
+------------------------------------------------------------+
| [Art] Current Track - Artist        Prev  Play/Pause  Next |
+------------------------------------------------------------+
|    Home         Search         AI Studio       Library     |
+------------------------------------------------------------+
```

### Key UX Highlights:
1. **Instant Search & 1-Tap Download**:
   - Search queries scan local library immediately.
   - If not in local library, queries or pasted URLs fetch audio via `yt-dlp` in background with instant download and ID3 metadata tagging.
2. **Floating Glass Mini-Player**:
   - Stays accessible across all screens.
   - Tap to expand into a full-screen blurred now-playing sheet with waveform visualizer and vibe tags.
3. **Adaptive Vibe Chips**:
   - One-tap chips (`#MidnightVibe`, `#HighEnergy`, `#ChillLoFi`, `#Acoustic`) instantly steer the queue.
4. **Transparent "Why This?" Proof**:
   - Each AI-recommended song displays a subtle badge explaining why it was chosen based on listening history and graph relations.

---

## 4. Python ML & yt-dlp Sidecar Engine

To keep the Flutter frontend ultra-lightweight while unlocking powerful ML ranking and audio extraction:

```text
+-------------------------+          HTTP Socket / REST          +---------------------------+
|     FLUTTER CLIENT      | <----------------------------------> |    PYTHON LOCAL SIDECAR   |
|  - Riverpod State       |                                      |  - yt-dlp Audio Downloader|
|  - Glassmorphic UI      |                                      |  - Compact Embedding ML   |
|  - Media3 / ExoPlayer   |                                      |  - SQLite Graph Sync      |
+-------------------------+                                      +---------------------------+
```

1. **`yt_dlp` Worker (`backend/services/youtube_service.py`)**:
   - Extracts audio stream URL / downloads high-bitrate MP3/Opus with album artwork directly to device storage.
2. **Python ML Intelligence (`backend/services/ai_rag_service.py`)**:
   - Computes lightweight compact audio embeddings and graph relations.
   - Generates recommendation scores based on user feedback.
