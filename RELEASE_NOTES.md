# Noctra v1.0.7 Release Notes

**Authentication-less on-device music intelligence platform.**

This is the official **v1.0.7** release of Noctra. Every artifact in this release is packaged with multi-architecture native builds, verified with detached SHA-256 digests, and automated via GitHub Actions CI/CD workflows.

---

## Native Platform Packages

| Platform | Package File | Architecture | Target / Description |
| :--- | :--- | :--- | :--- |
| **Android** | `Noctra-1.0.7-arm64-v8a.apk` | `arm64-v8a` | **Recommended** — modern 64-bit Android smartphones & tablets (Android 8.0+) |
| **Android** | `Noctra-1.0.7-Universal.apk` | Universal | Multi-ABI fallback containing all native architectures |
| **Android** | `Noctra-1.0.7-armeabi-v7a.apk` | `armeabi-v7a` | Legacy 32-bit ARM smartphones |
| **Android** | `Noctra-1.0.7-x86_64.apk` | `x86_64` | Android emulators, ChromeOS, Windows Subsystem for Android |
| **Android** | `Noctra-1.0.7.aab` | Google Play | Official Android App Bundle |
| **Windows** | `Noctra-1.0.7-Setup-x64.exe` | `x86_64` | Windows 10 & 11 standalone 1-click Inno Setup installer |
| **Linux** | `noctra_1.0.7_amd64.deb` | `amd64 / x86_64` | Debian / Ubuntu / Mint native package (`sudo dpkg -i`) |
| **iOS** | `Noctra-1.0.7.ipa` | `arm64` | Sideloadable via AltStore / SideStore / TrollStore (iOS 14.0+) |

> **Verification**: Check your downloaded packages against `SHA256SUMS.txt` attached on the GitHub Release page:
> ```bash
> sha256sum -c SHA256SUMS.txt
> ```

---

## What's New in v1.0.7

### 1. Android Predictive Back & System Navigation Architecture
- **Resolved Back Freeze Bug**: Completely eliminated the touch freeze and animation desynchronization bug that occurred when backing out of Artist profiles, playlists, and sub-views using system back gestures or the Android back button.
- **`RouteAware` Integration**: `MainNavigationShell` now implements Flutter's official `RouteAware` lifecycle subscribed to a global `appRouteObserver`. Ahead-of-time `canPop` evaluates to `true` whenever child routes sit above the shell, allowing Android's native back gesture handler to smoothly pop the top route without imperative `Navigator.pop()` desynchronization.
- **Native Predictive Back Restored**: Re-enabled `android:enableOnBackInvokedCallback="true"` in `AndroidManifest.xml` for full Android 14+ predictive back slide gestures.

### 2. Seamless 120 FPS UI Transitions & Repaint Boundary Isolation
- **Hardware-Accelerated Slide Transitions**: Configured `CupertinoPageTransitionsBuilder` for Android & iOS in `NoirTheme`, providing buttery-smooth 120 FPS slide animations with background parallax dimming. Desktop platforms use `FadeUpwardsPageTransitionsBuilder`.
- **Repaint Isolation**: Wrapped `IndexedStack` in `MainNavigationShell`, `MiniPlayerDock`, and heavy sliver sections in `ArtistScreen` with `RepaintBoundary` to eliminate cascaded repaints during timeline ticks and list scrolling.
- **O(1) Set Lookups**: Replaced $O(N)$ linear scans with $O(1)$ set lookup `repo.isDownloaded(song.id)` in `ArtistTrackTile`.

### 3. Player Download Spiral Progress Indicator
- Converted `PlayerTrackInfoBar` to a stateful consumer widget with reactive download tracking.
- Replaced the static download icon with a spinning spiral progress indicator (`CircularProgressIndicator`) during active track downloads, seamlessly transitioning to `download_done_rounded` upon completion.

### 4. Website Theme Icon Port
- Updated website navigation header (`Navbar.tsx` and `Navbar.module.css`) to match Noctra's mobile top-bar theme icons:
  - **Noir Black**: Lucide `<Moon size={18} />`
  - **Noir White**: Lucide `<Sun size={18} />`
  - **Liquid Glass**: Liquid glass shard with aurora cyan glow.

### 5. Multi-Platform Assistant & State Hardening
- Introduced `SearchCommand` and `handleSearch` so assistant and media browser queries execute library and online searches without inadvertently triggering playback.
- Added UUID `intentId` tracking and deduplication in `AssistantIntentChannel` and Android `AssistantIntentDelegate` to drop duplicate voice intents on cold start.
- Refined noise token filtering in `SongSimilarityDeduplicator` so legitimate title words like "Original" or "From" are not stripped during deduplication.
- Guarded folder mutations in `MusicRepositoryFolders` to prevent redundant mutation generation increments on no-op operations.
