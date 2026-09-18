# Noctra Architecture & Technical Documentation

> **Noctra** is an authentication-less, privacy-sovereign, audiophile-grade cross-platform music client built with Flutter, Dart 3, Riverpod, and native platform DSP delegates. It features clean layer boundaries, strict $\le$ 300 LOC modularity, an on-device 24-bit audio upscaling engine, 6-tier composite stream resolution, offline universal transliteration, a 120-dimensional neural taste vector space, and zero cloud telemetry.

---

## 1. Clean Layer Architecture & Topology

Noctra enforces strict unidirectional dependency boundaries mechanically verified by `test/architecture_boundaries_test.dart`:

```
core   ←   data   ←   services   ←   providers   ←   ui
  └────────────────────────── shared (importable by any layer)
```

```text
lib/
├── core/         Leaf utilities, themes, and design tokens. Imports nothing internal.
├── shared/       Cross-layer presentation primitives (e.g. GlassCard) importable anywhere.
├── data/
│   ├── models/        Immutable domain models (Song, Playlist, AudioStreamInfo, etc.)
│   ├── sources/       Persistence engines (NoctraLocalDatabase + modular parts)
│   └── repositories/  Authoritative state facades (MusicRepository + parts)
├── services/     Application & infrastructure engines (audio playback, resolvers,
│                 upscaler, lyrics transliteration, p2p sync, updater, ai)
├── providers/    Riverpod reactive wiring layer connecting services/data to UI
└── ui/           Presentation components, responsive screens, and modal sheets
```

### Architectural Constraints (Mechanically Enforced)
1. **Strict LOC Limit**: No source file under `lib/` or `test/` exceeds **300 lines of code** (`python tool/loc_guard.py`).
2. **Zero Cycles**: No cyclic imports exist across `lib/` (`tool/cycle_check.py`).
3. **`core`** never imports `data`, `services`, `providers`, or `ui`.
4. **`data`** never imports `ui` or `providers`.
5. **`services`** never imports `ui` or `providers`.
6. **`ui`** never imports `data/sources` directly — persistence is accessed solely through repositories/providers.

---

## 2. State Ownership & Threading Model

| Domain | Authoritative Owner | Reactive UI Projection |
|---|---|---|
| **Library, Favorites, Downloads, History** | `MusicRepository` (`ChangeNotifier` + `NoctraLocalDatabase`) | `musicRepositoryProvider`, `downloadedSongsProvider` |
| **Active Playback & Queue** | `AudioPlayerService` (+ `parts/*` mixins) | `currentSongStreamProvider`, `positionStreamProvider` |
| **Stream Resolution Telemetry** | `AudioPlayerService._lastResolution` | `streamResolutionStreamProvider` |
| **Theme & Aesthetics** | `themeModeProvider` (`NoirThemeMode`) | `NoctraThemeContext.noctraTokens` |
| **Download Target Directory** | `downloadLocationProvider` (persisted via DB) | Settings UI |

---

## 3. Audio Playback & Dual-Player Crossfade Engine

Playback is managed by a modular singleton `AudioPlayerService` decomposed into cohesive mixins:

```text
AudioPlayerService
 ├── PlayerQueueMixin            (Queue manipulation, reorder, shuffle, LRU history)
 ├── PlayerStreamResolverMixin   (Upscaled cache check, local files, composite CDN resolution)
 ├── PlayerCrossfadeRampMixin    (Logarithmic & exponential volume curves)
 ├── PlayerCrossfadeEngine       (Dual just_audio instances, auto-crossfade, gapless swap)
 ├── PlayerSessionLoaderMixin    (Pre-buffering next track, epoch-guarded session loading)
 ├── PlayerAutoplayMixin         (60-track sliding LRU window, context-aware radio fill)
 └── PlayerNativeEffectsMixin    (Equalizer, Studio Master DSP, Android Media3 routing)
```

- **Dual-Player Crossfade**: Two independent `AudioPlayer` instances execute simultaneous volume ramps (fading out the departing track along an exponential curve while fading in the incoming track along an inverse logarithmic curve), eliminating gap pauses and audio clicks.
- **Normal Audio Routing**: Operates Android's `AudioManager.MODE_NORMAL` to prevent mobile OS ducking or telecom call-quality audio decimation.

---

## 4. On-Device 24-Bit Audio Upscaling Engine

Noctra features a pure-Dart on-device DSP pipeline in `AudioUpscaleService` that restores perceived brightness and high-frequency air lost to lossy compression (MP3/AAC):

```text
Lossy Input Track (MP3 / AAC / M4A)
         │
         ▼
Native Audio Decoder (audio_decoder native library)
         │
         ▼
24-Bit Linear PCM Buffer
         │
         ▼
Background Dart Isolate (Zero UI Thread Blocking)
 ├── 1. Spectral Analysis & Dynamic Nyquist Estimation
 ├── 2. Harmonic Reconstruction (Quadratic Non-Linear Exciter)
 ├── 3. Dual-Channel Stereo Isolation (Independent Left/Right State)
 ├── 4. Dynamic Band Extension (High-Shelf Air Filter: 12 kHz - 22 kHz)
 └── 5. True 24-Bit Soft Limiter (Hyperbolic Tangent Saturation Guard)
         │
         ▼
True Lossless 24-Bit PCM WAV File Export
         │
         ▼
Cached to Disk (/NoctraUpscaled/{songId}.wav)
         │
         ▼
Automatic Resolution: Prioritized for bit-perfect playback over network streams
```

---

## 5. 6-Tier Composite Stream Resolution Pipeline

Every playback request resolves through a 6-tier fallback pipeline with strict host whitelisting and timeout bounds:

```text
Incoming Song Request
       │
       ▼
[Cached 24-bit Upscaled WAV?] ────► YES ──► Play Bit-Perfect Lossless WAV
       │ NO
       ▼
[Local Download Vault Cache?] ────► YES ──► Play Local File
       │ NO
       ▼
[Direct Validated HTTPS CDN?] ────► YES ──► Play Direct Stream
       │ NO
       ▼
[JioSaavn 320kbps CD Decrypt?] ───► YES ──► Play Decrypted 320kbps Stream
       │ NO
       ▼
[Native Android Kotlin Resolver] ─► YES ──► Play Native Extractor Stream
       │ NO
       ▼
[InnerTube REST JSON Extractor] ──► YES ──► Play Opus / AAC Stream
       │ NO
       ▼
[YouTube Web Search Fallback] ────► YES ──► Play Search Fallback Stream
       │ NO
       ▼
ResolutionException (User-Friendly Alert)
```

---

## 6. Universal Lyrics & Transliteration Engine

- **Brahmic Sanscript Matrix**: Zero-dependency offline transliteration across Devanagari, Gurmukhi, Bengali, Gujarati, Telugu, Tamil, Kannada, Malayalam, and Odia.
- **Asian Script Transliteration**: Chinese Hanzi $\to$ Pinyin with tonal accents, Japanese Kanji/Kana $\to$ Romaji, and Korean Hangul $\to$ Revised Romanization.
- **Persistent Script Preference**: Selected transliteration script remains active across continuous track changes.
- **Word-Level Sync Preservation**: Preserves exact inline timestamps `<mm:ss.xx>` during transliteration without corrupting lyric synchronizers.

---

## 7. On-Device Neural Intelligence Engine

- **120-Dimensional Taste Vector**: Captures acoustic features (energy, acousticness, tempo, danceability) and behavioral signals (skips, replays, full plays, favorites, playlist adds).
- **Online Weight Convergence**: Cosine similarity re-ranking runs on-device in sub-millisecond cycles.
- **60-Track Sliding LRU Window**: Autoplay queue manager enforces a 60-track sliding exclusion buffer, eliminating repetitive artist sequences and loop fatigue.

---

## 8. Quad Signature Aesthetic & Design Tokens

Noctra features four first-class design themes accessed via semantic tokens (`context.noctraTokens`):

1. **Noir Black**: Deep OLED Obsidian (`#070709`) with high-contrast titanium text (`#FFFFFF`, `#A8A8B2`, `#7C7C86`).
2. **Noir White**: Clean gallery porcelain (`#F4F4F6` canvas, `#FFFFFF` surfaces, `#060608` typography).
3. **Liquid Glass**: Sapphire depth canvas (`#162E4A`) with aurora cyan accents and real-time backdrop blur.
4. **Material U**: Native Android 12+ dynamic color extraction flowing from system wallpaper, with a branded seed fallback.

---

## 9. Security & Anti-SSRF Whitelisting

- **Strict Host Whitelisting**: Connections restricted to verified audio CDN domains (`aac.saavncdn.com`, `googlevideo.com`, `lrclib.net`, etc.).
- **Anti-SSRF Protection**: Rejects all private IP ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`), loopback (`127.0.0.1`, `localhost`), link-local (`169.254.0.0/16`), and non-HTTPS protocols.
- **Hop-by-Hop Redirect Validation**: Follows HTTP redirects only after independently re-verifying the target URL against the security whitelist.

---

## 10. Automated Verification

- `python tool/loc_guard.py` — Strict $\le 300$ LOC limit enforcement across all Dart and Android source files.
- `flutter test test/architecture_boundaries_test.dart` — Layer direction, zero cycles, and boundary rules.
- `flutter analyze` — Static type safety and strict linter rules.
- `flutter test` — Comprehensive test suite with 990+ automated tests passing.
