# Noctra v1.0.0 Release Notes

**Autonomous, privacy-first, on-device music intelligence platform.**

This is the first stable **signed** public release of Noctra. Prior APKs were
debug-signed test builds; every artifact in this release is signed with the
Noctra production release key, so future updates can be verified against a
stable signing identity.

---

## APK Download Guide

| File | Architecture | Recommended Device Target |
| :--- | :--- | :--- |
| `Noctra-1.0.0-arm64-v8a.apk` | `arm64-v8a` | **Recommended for most users** — modern 64-bit Android phones/tablets (Android 8.0+). |
| `Noctra-1.0.0-armeabi-v7a.apk` | `armeabi-v7a` | Older 32-bit ARM devices. |
| `Noctra-1.0.0-x86_64.apk` | `x86_64` | Android emulators, Chromebooks, Intel/AMD tablets. |
| `Noctra-1.0.0-universal.apk` | Universal | Fallback containing every ABI; works anywhere but is larger. |

> Unsure which to pick? Choose **arm64-v8a**. The in-app updater selects the
> matching ABI automatically and verifies SHA-256 before install.

### Integrity

`SHA256SUMS.txt` and the `noctra-update-manifest.json` on the release page let
you verify every APK:

```bash
sha256sum -c SHA256SUMS.txt
```

### Installation

Android may ask you to allow installation from the source you downloaded the
APK from ("Install unknown apps"). Noctra cannot bypass this — it is an
Android security requirement. Noctra's own in-app updater performs SHA-256 +
package + signer verification before it ever hands an APK to the installer.

---

## What's New in v1.0.0

### AI Libraries That Actually Open
- **Instant folder/mix opens** — curated local picks are shown immediately;
  a slow network no longer blocks the collection from opening.
- **Offline remix** — Remix re-orders the resolved pool deterministically
  instead of re-running the same network search on every tap.
- **Curation performance** — one shared embedding pool per data state and
  memoized AI playlists/folders stop repeated whole-library scoring on every
  UI rebuild.

### Architecture & Maintainability
- Mechanically enforced boundaries: ≤300 LOC per file, no import cycles,
  layer-direction rules (`test/architecture_boundaries_test.dart`).
- Shared `widgets` layer; UI no longer touches the database or constructs
  repositories directly.
- Platform capability registry; Android channel adapters and path logic
  isolated behind service boundaries.

### Reliability Carried Forward
- Real end-to-end resolution deadlines with per-operation recalculation.
- On-device 120-dim MLP recommender + MMR diversity, signal-trained from real
  listening behavior with no telemetry leaving the device.
- 6-tier composite stream resolution (local → direct → JioSaavn → native →
  InnerTube → YouTube fallback) with host/SSRF/HTTPS hardening.
- Signed, ABI-aware, resumable in-app updates.
- Themes: **Noir Black**, **Noir White**, **Liquid Glass**.

---

## Verified

```
flutter analyze:  0 issues
flutter test:     753 passing (1 skipped: live-network lyric suite)
LOC > 300:        0 files
Release build:    arm64-v8a / armeabi-v7a / x86_64 / universal — all signed
```

## Platforms

- **Android (this release).** Windows, Linux, and iOS builds are prepared at
  the architecture level but require their native toolchains (Visual Studio,
  a Linux desktop toolchain, macOS/Xcode respectively) to compile — see
  `docs/PLATFORM.md`.
