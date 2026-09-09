# Noctra v1.0.8 Release Notes

**Authentication-less on-device music intelligence platform.**

This is the official **v1.0.8** release of Noctra. Every artifact is packaged with multi-architecture native builds, verified with detached SHA-256 digests, and published via GitHub Releases with a machine-readable update manifest consumed by the in-app updater.

---

## Native Platform Packages

| Platform | Package File | Architecture | Target / Description |
| :--- | :--- | :--- | :--- |
| **Android** | `Noctra-1.0.8-arm64-v8a.apk` | `arm64-v8a` | **Recommended** — modern 64-bit Android smartphones & tablets (Android 8.0+) |
| **Android** | `Noctra-1.0.8-Universal.apk` | Universal | Multi-ABI fallback containing all native architectures |
| **Android** | `Noctra-1.0.8-armeabi-v7a.apk` | `armeabi-v7a` | Legacy 32-bit ARM smartphones |
| **Android** | `Noctra-1.0.8-x86_64.apk` | `x86_64` | Android emulators, ChromeOS, Windows Subsystem for Android |
| **Windows** | `Noctra-1.0.8-Setup-x64.exe` | `x86_64` | Windows 10 & 11 standalone 1-click Inno Setup installer |
| **Linux** | `noctra_1.0.8_amd64.deb` | `amd64 / x86_64` | Debian / Ubuntu / Mint native package (`sudo dpkg -i`) |
| **iOS** | `Noctra-1.0.8.ipa` | `arm64` | Sideloadable via AltStore / SideStore / TrollStore (iOS 14.0+) |

> **Verification**: Check your downloaded packages against `SHA256SUMS.txt` attached on the GitHub Release page:
> ```bash
> sha256sum -c SHA256SUMS.txt
> ```

> **Note**: Android artifacts are built and attached with this release. Windows/Linux/iOS packages are produced by their respective platform CI jobs when toolchains are available (see `docs/PLATFORM.md` for the current build matrix).

---

## What's New in v1.0.8

### 1. Search Accuracy — Missing Songs & Artists Found

The most user-visible fix in this release. If songs or artists previously "didn't come" in search, this is the release that fixes it.

- **Accented artists now match plain queries**: `Halo Beyonce` finds Beyoncé's tracks; `bjork` finds Björk. Both directions work, including decomposed (NFD) Unicode spellings.
- **Typos stop hiding songs**: one-letter misses like `midnight ciy` still find *Midnight City*. Fuzzy matching is disabled for tokens shorter than four letters so it never invents false matches.
- **Apostrophe variants agree**: `Don't` and `Dont` are the same word to the ranker.
- **Spotify link searches fixed**: pasting a track link that resolves but doesn't match a provider row now falls back to a title search instead of returning nothing.
- **Artist pages**: artist-profile ordering accepts accent and one-edit spelling variants of the queried name.
- **Slow networks**: YouTube Music and iTunes search timeouts raised 2.5s → 3.5s, so weak connections stop silently dropping whole provider result buckets.
- **Verified against reality**: a live-network test suite queries the real providers for every reported-missing song (Kahin Deep Jalay, Mere Hamsafar, Khuda Aur Mohabbat, Ruposh, Jhoom, Awargi, Sidney Gish, …) and asserts they come back; all also re-verified on a physical device with zero crashes.

### 2. Playback Wrong-Track Guard Fixed

The native stream-resolution matching guard split accented words in two (`Beyoncé` → `beyon ce`) before its punctuation filter, which could reject the correct stream during playback resolution. Diacritic folding now happens before punctuation stripping, so accented library metadata resolves against plain-text provider candidates — and genuinely different artists are still rejected.

### 3. AI Libraries & Recommendations

- **AI folders/mixes open instantly** from locally curated tracks — no more network wait before the view appears.
- **Remix works**: re-orders the already-resolved pool deterministically instead of re-running network resolution.
- **No more rebuild storms**: curation results are memoized on a content signature, so Home/Library rebuilds stop re-running the nine-vibe scoring pipeline on every frame.

### 4. UI Fixes

- Synthwave spectrum visualizer recolors with the active theme (Noir Black/White accent, Liquid Glass glass-blue).
- Mini player now appears inside library and artist pages.
- Fixed playback position/progress stuck at 1:10 with the play/pause button desynced.

### 5. Website Overhaul

- **Mobile navigation restored** — real hamburger menu + slide-down panel (links were previously just hidden on phones).
- **3D backdrop**: pauses when the tab is hidden, honors reduced-motion, lighter GPU cost on phones.
- **Accessibility**: proper dialog semantics + focus management on the changelog modal.
- **SEO/PWA**: robots.txt, sitemap, web manifest, absolute social-preview image URLs, FAQ structured data.

---

## Upgrade Notes

Install over any previous version — the package name and signing identity are unchanged, so Android offers a direct in-place upgrade (or use the in-app updater's one-tap flow). No data migration is involved; library, downloads, playlists, and settings are preserved.

---

## Integrity

Every Android APK in this release is signed with the official Noctra release keystore and its SHA-256 digest is recorded in `SHA256SUMS.txt` and in the updater's `release.json` manifest. The in-app updater independently re-verifies both the checksum and the signing certificate continuity before offering an update.
