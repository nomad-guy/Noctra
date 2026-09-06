# Contributing to Noctra

Thank you for your interest in contributing to **Noctra**! We welcome bug reports, feature proposals, documentation enhancements, and pull requests from developers around the globe.

To maintain our high bar of engineering quality, audiophile performance, and code readability, please review the guidelines below before submitting a pull request.

---

## Code of Conduct

All contributors and maintainers are expected to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please report any unacceptable behavior directly to the project maintainers via GitHub.

---

## Architectural Rules & Code Standards

Every contribution to Noctra must adhere to the following invariants:

1. **Strict $\le 300$ LOC Constraint**:
   * No single Dart, Kotlin, or C++ file may exceed **300 lines of code**.
   * Monolithic components must be modularly decomposed into focused delegates, mixins, or sub-widgets.
   * This constraint is strictly enforced by `test/architecture_boundaries_test.dart` in CI.
2. **Zero Circular Dependencies**:
   * Layers follow a strict unidirectional data flow: UI $\rightarrow$ Providers $\rightarrow$ Services $\rightarrow$ Repositories $\rightarrow$ Data Sources.
3. **Clean Static Analysis**:
   * `flutter analyze` must pass with **0 issues, 0 warnings, and 0 errors**.
4. **Offline-First & Privacy Sovereignty**:
   * Noctra never transmits user listening data, search history, or personal identifiers.
   * Remote network requests must be strictly limited to audio stream resolution, lyrics fetching, and metadata querying.

---

## Getting Started & Local Development

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0` / Stable channel)
* Android Studio or VS Code with Flutter extensions
* Java JDK 17 (for Android builds)
* Platform-specific toolchains:
  * **Windows**: Visual Studio 2022 C++ Desktop Development & Inno Setup
  * **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`
  * **macOS / iOS**: Xcode 15+

### Setting Up the Repository
```bash
# Clone the repository
git clone https://github.com/nomad-guy/Noctra.git
cd Noctra

# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Execute test suite
flutter test
```

---

## Development Workflow

1. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   # or for bug fixes:
   git checkout -b fix/issue-description
   ```
2. **Implement Your Changes**:
   * Write clean, idiomatic Dart.
   * Add unit or widget tests covering new behavior.
   * Keep files $\le 300$ lines.
3. **Verify Locally**:
   ```bash
   flutter analyze
   flutter test
   ```
4. **Commit Following Conventional Commits**:
   * `feat: add swipe-to-queue gesture in library`
   * `fix: handle null artwork url in transfer manifest`
   * `docs: update cross-platform installation guide`
5. **Open a Pull Request**:
   * Provide a concise description of the motivation and changes.
   * Link any related issues (`Fixes #123`).

---

## Cross-Platform Releases

Production cross-platform native packaging (Windows `.exe`, Linux `.deb`, Android `.apk`/`.aab`, iOS `.ipa`) is automated via GitHub Actions and triggered exclusively via version tags (`v*`).

To learn more about Noctra's build pipeline, see [.github/workflows/cross_platform_build.yml](.github/workflows/cross_platform_build.yml).
