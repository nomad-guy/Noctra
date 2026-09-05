# Noctra v1.0.2 Release Notes

**Autonomous, privacy-first, on-device music intelligence platform.**

This is the official **v1.0.2** release of Noctra. Every artifact in this release is signed with the Noctra production release key, packaged with R8 bytecode optimization, and verified with detached SHA-256 digests and JSON update manifests for the in-app updater.

---

## APK Download Guide

| File | Architecture | Size | Recommended Device Target | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| `Noctra-1.0.2-arm64-v8a.apk` | `arm64-v8a` | 22.4 MB | **Recommended for most users** — modern 64-bit Android devices (Android 8.0+). | `e1216b2afaf7bfa464dbd0d8d84af77a8000a0b4580cd2632553f45af8f170c3` |
| `Noctra-1.0.2-armeabi-v7a.apk` | `armeabi-v7a` | 20.3 MB | Legacy 32-bit ARM devices. | `4534bf1683fcbfd95fdd8395e739d9915f4a14bd4724478e837ead283be7d34c` |
| `Noctra-1.0.2-x86_64.apk` | `x86_64` | 23.9 MB | Android emulators, Chromebooks, Intel/AMD tablets. | `7b9a96ff5b994ec565ad7cc9f9fa857be5e223807ccbcef8160e1f9f1137d6ad` |
| `Noctra-1.0.2-universal.apk` | Universal | 61.7 MB | Multi-ABI compatibility fallback containing every architecture. | `9d26fa01faecd34c233e5401e022e2e5a308d5ff4e6809d26ba4099d659b0cb7` |

> Unsure which to pick? Choose **arm64-v8a**. The in-app updater automatically selects the matching ABI and verifies SHA-256 before installation.

### Integrity

`SHA256SUMS.txt` and `noctra-update-manifest.json` on the release page allow full cryptographic verification of every APK:

```bash
sha256sum -c SHA256SUMS.txt
```

### Installation

Android may prompt you to allow installation from the source you downloaded the APK from ("Install unknown apps"). Noctra's integrated in-app updater performs package, signer identity, and SHA-256 integrity verification before handing an APK to the system package installer.

---

## What's New in v1.0.2

### In-App Rollback Architecture
- **Seamless Rollback Support**: Users can now easily roll back to previous stable versions directly from the In-App Update Sheet.
- **Rollback Manifest Tracking**: Cached fallback APK snapshots and SHA-256 digest validation prevent broken downgrade loops.

### Offline Mode ("Downloads Only" Mode)
- **One-Tap Offline Toggle**: Added dedicated offline switch on the Home Screen AppBar and Library screen.
- **Dynamic Content Fallback**: When active, Home Trending, Spotify Charts, and Live Vibe feeds automatically resolve to downloaded and local songs with zero network requests.

### Taste Radar & Audio DNA Profile Visualizer
- **Interactive Acoustic Radar**: Custom multi-polygon visualizer mapping 8 acoustic traits: Energy, Valence, Danceability, Acousticness, Instrumentalness, Tempo, Liveness, and Speechiness.
- **Acoustic Archetype Engine**: Classifies user listening habits into dynamic archetypes (e.g. Cyber Synth Architect, Melodic Architect, Nocturnal Dreamer).
- **Audio DNA Sheet**: Accessible from Music Preferences in Settings.

### Smart Playback Speed & Pitch FX
- **Granular Speed Slider**: Full 0.5x to 2.0x playback rate adjustment with pristine audio time-stretching.
- **Instant Preset Chips**: One-tap speed presets: Slowed (0.85x), Chill (0.90x), Normal (1.0x), Nightcore (1.25x), and Fast (1.50x).
- **Player Quick Menu**: Speed & Pitch FX action sheet accessible directly from the player header.

### Swipeable List Gesture Actions
- **Swipe to Play Next**: Swipe track right (Cyan) to insert immediately behind the active song.
- **Swipe to Add to Queue**: Swipe track left (Amber) to append to the end of the current play queue.
- **Tactile Haptic Triggers**: Native haptic feedback on swipe thresholds across Library Songs and Search Results.

### Shareable Song & Lyric Story Cards
- **9:16 Story Card Generator**: Export high-resolution, beautifully styled music story cards for Instagram, Telegram, and WhatsApp stories.
- **5 Dynamic Visual Themes**: Noir Black, Liquid Glass, Amber Glow, Neon Cyber, and Velvet Rose.
- **Native Android Share Intent**: Zero external dependencies; shares directly using Android's native `FileProvider` and chooser sheet.

### Universal Playlist URL Importer
- **Multi-Platform Support**: Directly import Spotify public playlists, YouTube playlists, or plaintext tracklists ("Song - Artist").
- **Automatic Matching**: Resolves metadata and saves songs into custom library folders seamlessly.

### Bluetooth & Output Router Hardening
- **Android 12+ Permission Resolution**: Prompts for `BLUETOOTH_CONNECT` runtime permissions so connected Bluetooth headphones/speakers are reliably enumerated.
- **Accurate Active Sink Detection**: Dynamic priority heuristics for Communication Device -> Bluetooth A2DP -> Wired AUX -> Phone Speaker.
- **Samsung Dual Audio Integration**: Direct launch of Samsung One UI QuickBoard Media Output panel for concurrent dual Bluetooth streaming.

---

## Verified

```
flutter analyze:  0 issues
flutter test:     813 passing (100% test verification)
LOC <= 300:       100% compliant across all lib/ files
```
