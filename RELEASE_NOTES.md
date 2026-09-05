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

### Adaptive Dual-Engine Audio Effects Architecture
- **DynamicsProcessing Engine (API 28+)**: Implemented `NoctraDynamicsProcessor` with time-domain IIR filters, 10-band PreEq, and studio limiter (-0.5 dBFS).
- **Universal OEM Compatibility**: `NoctraAudioEffectsEngine` provides automatic fallback to `NoctraLegacyEffects` (NXP Equalizer, BassBoost, Virtualizer, Reverb), preventing AudioFlinger effect chain overload and Dolby Atmos / Dirac muting on Realme, Oppo, Xiaomi, and Samsung devices.
- **48 kHz Opus Prioritization**: Prioritizes transparent 48 kHz Opus streams over 128 kbps AAC for 20 kHz high-frequency extension.

### Liquid Glass Theme Performance Overhaul
- **Hardware-Accelerated Frosted Glass**: Eliminated per-card `BackdropFilter` shaders, replacing them with translucent gradient layers, hairline specular borders, and soft elevation shadows.
- **RepaintBoundary Caching**: Background liquid orbs and gradients are cached in a display list, eliminating background repaint churn during scrolling.
- **Tuned Floating Blur Sigmas**: Optimized navigation bar and bottom sheets for locked 60/120 FPS fluid scrolling.

### App Shell & System Integrations
- **App Icon Change Confirmation**: Added modal popup in Settings alerting users to Android application restart before applying launcher alias changes.
- **Google Assistant App Actions**: Integrated `shortcuts.xml` with `actions.intent.PLAY_MUSIC` and `actions.intent.OPEN_APP_FEATURE` capabilities.
- **Interactive Notification Heart**: Replaced static stop button with live favorite heart toggle in media notification.

### Reliability & Architecture
- **Strict LOC Limit**: All source files strictly <= 300 LOC.
- Real end-to-end resolution deadlines with per-operation recalculation.
- On-device 120-dim MLP recommender + MMR diversity, signal-trained with zero telemetry leaving the device.
- 6-tier composite stream resolution (local -> direct -> JioSaavn -> native -> InnerTube -> YouTube fallback).

---

## Verified

```
flutter analyze:  0 issues
flutter test:     776+ passing (100% test verification)
LOC > 300:        0 files
Release build:    arm64-v8a / armeabi-v7a / x86_64 / universal — all signed
```

## Platforms

- **Android (this release).** Windows, Linux, and iOS builds are prepared at
  the architecture level but require their native toolchains (Visual Studio,
  a Linux desktop toolchain, macOS/Xcode respectively) to compile — see
  `docs/PLATFORM.md`.
