# Noctra v1.0.1 Release Notes

**Autonomous, privacy-first, on-device music intelligence platform.**

This is the official **v1.0.1** release of Noctra. Every artifact in this release is signed with the Noctra production release key, packaged with R8 bytecode optimization, and verified with detached SHA-256 digests and JSON update manifests for the in-app updater.

---

## APK Download Guide

| File | Architecture | Size | Recommended Device Target | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| `Noctra-1.0.1-arm64-v8a.apk` | `arm64-v8a` | 22.3 MB | **Recommended for most users** — modern 64-bit Android devices (Android 8.0+). | `01b459b7b0bd5974e06bff1697dac22a6c5bb00269b38533c7a2f062f25b706c` |
| `Noctra-1.0.1-armeabi-v7a.apk` | `armeabi-v7a` | 20.2 MB | Legacy 32-bit ARM devices. | `d60a03b5ca8be891755cd0f1ad5d207d4383f7ba14c475e87a9587b14cbae666` |
| `Noctra-1.0.1-x86_64.apk` | `x86_64` | 23.8 MB | Android emulators, Chromebooks, Intel/AMD tablets. | `66a05018d03d46c307fde9584c3fc21e5ca58bd9667355d18e3c5a6caacc78bc` |
| `Noctra-1.0.1-universal.apk` | Universal | 61.3 MB | Multi-ABI compatibility fallback containing every architecture. | `1cf3ca8a2f05121cd1a9cdbe6c41da46c19e9c33ac15f8f649114557b1f78284` |

> Unsure which to pick? Choose **arm64-v8a**. The in-app updater automatically selects the matching ABI and verifies SHA-256 before installation.

### Integrity

`SHA256SUMS.txt` and `noctra-update-manifest.json` on the release page allow full cryptographic verification of every APK:

```bash
sha256sum -c SHA256SUMS.txt
```

### Installation

Android may prompt you to allow installation from the source you downloaded the APK from ("Install unknown apps"). Noctra's integrated in-app updater performs package, signer identity, and SHA-256 integrity verification before handing an APK to the system package installer.

---

## What's New in v1.0.1

### System-Wide Localization Architecture
- **8 Fully Supported Languages**: Complete dictionary parity across English (`en`), Hindi (`hi`), Punjabi (`pa`), Urdu (`ur`), Kannada (`kn`), Tamil (`ta`), Marathi (`mr`), and Odia (`or`).
- **Dynamic Reactive Updates**: Instant UI string updates without restarting the application or losing navigation, audio playback, or search states.
- **Bi-Directional Script & RTL Support**: Native Right-To-Left layout mirroring and bidirectional typography for Urdu (`ur`).
- **Zero Emojis**: Complete compliance with professional, clean UI typography across all localizations.

### Bottom Sheets & UI Internationalization
- Fully localized Media Controls, Mini Player, Sleep Timer, Audio Output Cast Sheet, Jam Studio P2P controls, Library Folders, Search Catalogs, Neural Audio Stems, and In-App Update Sheet.

### Android Voice Assistant Hardening
- Strengthened Android `MediaSession` external controller callbacks allowing Google Assistant and Gemini to control playback, volume, skipping, and track querying.

### Reliability & Architecture
- **Strict <= 300 LOC Invariant**: Maintained 100% compliance across all source files in `lib/` and `android/`.
- **Zero Static Analyzer Issues**: `flutter analyze` clean with 0 warnings.
- **100% Automated Test Coverage**: Complete test suite passing including key parity verification and release manifest integrity.

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
