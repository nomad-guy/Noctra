# Noctra v1.0.3 Release Notes

**Autonomous, privacy-first, on-device music intelligence platform.**

This is the official **v1.0.3** release of Noctra. Every artifact in this release is signed with the Noctra production release key, packaged with R8 bytecode optimization, and verified with detached SHA-256 digests and JSON update manifests for the in-app updater.

---

## APK Download Guide

| File | Architecture | Size | Recommended Device Target | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| `Noctra-1.0.3-arm64-v8a.apk` | `arm64-v8a` | 22.9 MB | **Recommended for most users** — modern 64-bit Android devices (Android 8.0+). | `a377827d98f072685db73fff2cd177505e82476ea9482093f4ad5e0d74a35b55` |
| `Noctra-1.0.3-armeabi-v7a.apk` | `armeabi-v7a` | 20.9 MB | Legacy 32-bit ARM devices. | `17c51cb766b947af551554160651e58a4ed58ff5e6219745a3e05dec6cd9b7a5` |
| `Noctra-1.0.3-x86_64.apk` | `x86_64` | 24.4 MB | Android emulators, Chromebooks, Intel/AMD tablets. | `5dbf8ed72789e24638ec867b3e23d77187009452b06e5f923e2cddffb0aa21f9` |
| `Noctra-1.0.3-universal.apk` | Universal | 24.7 MB | Multi-ABI compatibility fallback containing every architecture. | `3d2fe058c1fdb6a67ccf620c00f7d769d13ddc884cc6cc683e5efe8b2fdcff99` |

> Unsure which to pick? Choose **arm64-v8a**. The in-app updater automatically selects the matching ABI and verifies SHA-256 before installation.

### Integrity

`SHA256SUMS.txt` and `noctra-update-manifest.json` on the release page allow full cryptographic verification of every APK:

```bash
sha256sum -c SHA256SUMS.txt
```

### Installation

Android may prompt you to allow installation from the source you downloaded the APK from ("Install unknown apps"). Noctra's integrated in-app updater performs package, signer identity, and SHA-256 integrity verification before handing an APK to the system package installer.

---

## What's New in v1.0.3

### Dynamic High-Resolution Artwork Resolution
- **Multi-Tier Artwork Resolver**: Brand new `SongArtworkResolver` pipeline with instant YouTube HQ thumbnail mapping (<0.1ms), LRU memory cache, Apple Music / iTunes Store Search API (crisp 600x600 HD cover art), and Deezer Track Graph API fallback.
- **Playback Dynamic Artwork Enrichment**: Imported songs playing without artwork automatically resolve high-res cover art in the background, updating Now Playing ambient glow visualizers, mini-player tiles, and Android system lock-screen media items.
- **Folder & Library Auto-Enrichment**: Opening imported playlists automatically fills in missing artwork and updates local storage.
- **Universal Metadata Persistence**: `MusicRepository.updateSongMetadata` matches by both track ID and normalized title + artist, updating custom folders, favorites, downloads, and recently played tracks.

### Offline AksharaEngine & Indic Transliteration
- **Native Indic Transliteration**: Integrated `indic_transliteration_dart: ^2.3.84` for comprehensive Indic script support.
- **Offline Phonetic Matrix Engine**: Zero-dependency `AksharaEngine` using a canonical phonetic matrix covering Devanagari, Gurmukhi, Urdu, and Latin/IAST.
- **Urdu FST Glyph Joining**: Deterministic finite-state transducer handling Perso-Arabic cursive glyph joining, virama merging, and vowelization.
- **Zero Network Latency**: `AksharamukhaService` is now 100% offline and synchronous (<0.15ms execution time), eliminating external network timeouts.
- **Multi-Script Lyric Routing**: Full support across Gurmukhi, Urdu, Bengali, Tamil, Telugu, Kannada, Malayalam, Gujarati, Odia, IAST, and Romanized Latin.

### Touch Responsiveness & Navigation Stabilization
- **Fixed Tab Touch Lock**: Replaced `FadeIndexedStack` with lazy-mounted `IndexedStack` to eliminate pointer capture issues when switching between tabs.
- **AI Radio Loop Guard**: Resolved infinite loop bug where the seed track was re-suggested at the top of recommendations.
- **Navigation Modernization**: Replaced inline view swaps with proper `Navigator.push` route navigation in `FolderDetailView` and removed conflicting `PopScope` handlers.

### Universal Playlist Scraper & Stream Resolver
- **Spotify Embed Extraction**: Full tracklist and metadata extraction from Spotify embed payloads.
- **YouTube `lockupViewModel` Parsing**: Support for modern YouTube playlist data models alongside legacy renderers.
- **Lossless Stream Matching**: `TrackMatchingGuard` containment matching for clean stream resolution without mismatches.

---

## Verified

```
flutter analyze:  0 issues (100% clean)
flutter test:     100% passing across engine, UI state, and network suites
LOC <= 300:       100% compliant across all lib/ files
```
