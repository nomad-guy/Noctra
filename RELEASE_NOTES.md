# Noctra v1.0.9

**Release date:** 2026-09-12
**Previous release:** v1.0.8

## Highlights

The four bugs you reported are fixed: playlists longer than 100 songs now
import completely, Windows settings no longer reset when you close the app,
tracks no longer start silently after switching, and the app finally tells
you what's wrong inside it — plus a one-tap Download Full Library.

## Fixes

### Playlist imports: no more 100-song cap
- Spotify imports now page through the **entire** playlist (up to 2,000
  tracks) via Spotify's private web API instead of trusting the embed page
  that silently truncates at ~100 songs.
- YouTube imports follow InnerTube continuation tokens through the whole
  playlist (the initial page payload only embeds the first ~100 videos).
- Duplicate-safe: tracks found by both paths are merged on title+artist.

### Windows settings persistence
- Fade transitions, crossfade seconds, autoplay delay, shuffle, loop mode,
  and volume now **persist across restarts**. They were previously in-memory
  only — Android's process recycling masked it, but on Windows every app
  close reset them to defaults.
- The settings screen and the audio service now agree on defaults (the fade
  toggle previously defaulted differently in each).

### Audio output stability
- **Silent track starts fixed.** Every transition prepares the player at
  volume zero, and the fade-in path used to skip restoring volume when the
  fade setting was off — so tracks played silently until you touched the
  volume slider. Volume restoration is now guaranteed on every track start,
  fades on or off.
- Your preferred volume is restored on every launch.

### Diagnostics & log system (new)
- Runtime errors — widget build failures, unhandled async exceptions — are
  captured automatically into a 2,000-entry log.
- **Settings → Diagnostics & Logs**: live counts, log viewer, clear, and
  **Export .txt** through the native save dialog. Attach it to bug reports.

### Download Full Library (new)
- **Settings → Downloads → Offline Library**: shows "X of Y songs saved
  offline" and downloads every remaining track sequentially with live
  progress and a Stop button.

## Engineering

- **Speaker Mesh groundwork**: clock-sync estimator (NTP-style, min-RTT
  filtering), anchor planner, Bluetooth latency profiles with per-device
  trim, mesh packet protocol with replay protection, drift monitor with
  echo-exit policy, and a WebSocket transport with HMAC challenge auth —
  proven by loopback integration tests over real sockets. Jam/P2P untouched.
  User-facing mesh UI lands in the next release.
- Analyzer: 0 issues · **968 tests passing** (33 new) · architecture rules
  enforced (≤300 LOC per file, platform boundaries hold).

## Downloads

| Platform | File | Notes |
|---|---|---|
| Android (most phones) | `Noctra-1.0.9-arm64-v8a.apk` | Android 8.0+ |
| Android (older 32-bit) | `Noctra-1.0.9-armeabi-v7a.apk` | legacy ARM |
| Android (emulators/x86) | `Noctra-1.0.9-x86_64.apk` | x86_64 |
| Android (any device) | `Noctra-1.0.9-Universal.apk` | compatibility fallback |
| Android (Play-style) | `Noctra-1.0.9.aab` | sideload via bundletool |
| Windows | `Noctra-1.0.9-Setup-x64.exe` | installer, per-user |
| Linux | `noctra_1.0.9_amd64.deb` | Debian/Ubuntu |
| iOS | `Noctra-1.0.9.ipa` | sideload via AltStore/Sign tools |

SHA-256 checksums for every artifact ship in `SHA256SUMS.txt`. Verify before
installing: `sha256sum -c SHA256SUMS.txt` (or `certutil -hashfile <file>
SHA256` on Windows).

## Upgrade notes

- Installs cleanly over v1.0.8 (same signing identity, higher version code).
- First launch after upgrade: playback settings apply from persisted state;
  if you had changed fade/crossfade/volume before, they now stick.
