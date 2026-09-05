# Noctra v1.0.1 Release Notes

**Autonomous, privacy-first, on-device music intelligence platform.**

This is the official **v1.0.1** release of Noctra. Every artifact in this release is signed with the Noctra production release key, packaged with R8 bytecode optimization, and verified with detached SHA-256 digests and JSON update manifests for the in-app updater.

---

## APK Download Guide

| File | Architecture | Size | Recommended Device Target | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| `Noctra-1.0.1-arm64-v8a.apk` | `arm64-v8a` | 22.3 MB | **Recommended for most users** — modern 64-bit Android devices (Android 8.0+). | `87868a26316785e100bce85f0ae83d2ed98d00cc91a42a0c4a1d792a63318580` |
| `Noctra-1.0.1-armeabi-v7a.apk` | `armeabi-v7a` | 20.2 MB | Legacy 32-bit ARM devices. | `4602d69a2dedb8d9cb67e907785bb8ee666c48a0183a84e261b8d9fd63f0a237` |
| `Noctra-1.0.1-x86_64.apk` | `x86_64` | 23.8 MB | Android emulators, Chromebooks, Intel/AMD tablets. | `2cd0dfa993fda623fb3892d199044cda049d74c18132c600a2944b469d47021a` |
| `Noctra-1.0.1-universal.apk` | Universal | 61.3 MB | Multi-ABI compatibility fallback containing every architecture. | `2fd2cad0f7fcf2fdd641c8d4b8cead7fbc34a2c2bb68fbe20cf63e33a8688ed6` |

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
