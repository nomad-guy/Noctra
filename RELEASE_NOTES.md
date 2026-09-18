# Noctra v1.1.2

**Release date:** 2026-09-18
**Previous release:** v1.1.1

## Highlights

Noctra v1.1.2 refines audio fidelity, lyrics transliteration, and visual contrast across the entire app. Lossless upscaled tracks now automatically resolve for instant bit-perfect playback with dedicated `24-BIT UPSCALED` gold badges. The lyrics view now persists user-selected transliteration scripts across track transitions. Faded tertiary and secondary text colors have been boosted across all themes, and 8 critical engine stability fixes from the static architecture audit are incorporated.

## Audio Upscaler & Lossless Auto-Play (v1.1.2)

- **Automatic Lossless Auto-Play**: Once a track is upscaled, Noctra automatically resolves and plays the bit-perfect 24-bit PCM WAV locally without manual file selection.
- **24-BIT UPSCALED Badge**: Live resolution telemetry displays a prominent gold badge in the player info bar; tapping opens the upscale details sheet.
- **Immediate Playback Action**: The upscale sheet now includes a 1-tap "Play Upscaled Track" button upon completion.
- **Stereo Isolation**: Enhanced DSP channel separation prevents stereo crosstalk during harmonic reconstruction.

## Universal Lyrics & Visual Contrast (v1.1.2)

- **Persistent Transliteration Script**: Switching between Romanized, Devanagari, or Hanzi scripts persists throughout the listening session across track changes.
- **Visual Contrast Fix**: Significantly boosted secondary and tertiary text contrast across Noir Black, Noir White, Liquid Glass, and Material U themes.

# Noctra v1.1.1

## Audio Upscaler (New)

- Long-press any song → **"Upscale to Lossless"** → Noctra rebuilds the
  harmonics that lossy compression (MP3/AAC) strips out and exports a true
  lossless 24-bit WAV, playable anywhere.
- The DSP chain (harmonic reconstruction + dynamic high-band extension + soft
  limiting) runs entirely on-device in a background isolate — the UI never
  freezes, even for long tracks.
- Streamed tracks are downloaded automatically first; results are cached and
  re-exportable.
- Honest scoping: this is DSP enhancement, not neural ML, and the output is
  lossless WAV rather than FLAC (no viable pure-Dart FLAC encoder exists yet).

## Material U Theme (New)

- Fourth theme alongside Noir Black, Noir White and Liquid Glass.
- Colors flow from your wallpaper via Android 12+ dynamic color; on devices
  without dynamic color a branded seed palette keeps everything coherent.
- Follows the system light/dark setting automatically. Selectable in Settings,
  the sidebar theme card, the app-bar cycle button, and voice commands.
- Matching launcher icon + in-app logo tinted with the Material You palette.

## Slow / Low-Network Mode

- **Search works on 2G now**: request timeouts scale with measured network
  quality (up to 3× on poor connections) instead of quitting at the TLS
  handshake and returning empty results.
- **First good provider wins**: search returns as soon as one provider
  delivers enough results; stragglers only fill gaps.
- **Transient failures retry** with exponential backoff + jitter.
- **Smart streaming policy is real**: mobile data or a weak connection
  automatically streams Opus 128k; good Wi-Fi gets 320k — live switching.
- **Offline search**: previously-seen queries still return results in
  airplane mode (30-day disk cache, fault-isolated records).

## Home Declutter

- Settings → **Home Layout**: toggle each home section on/off. Hidden
  sections are not built and don't fire their startup network requests.

## Performance & Battery

- Global image cache clamped to 400 images / 48 MiB (was 1000 / 100 MiB) —
  artwork-heavy long sessions no longer balloon native memory.
- Skeleton shimmer animations pause when covered by another layer instead of
  ticking frames for invisible pixels.

## Website

- Full redesign: new design system mirroring the app's three original themes,
  rebuilt Navbar/Hero/Features/Footer, live GitHub release integration,
  platform-aware download CTA, and a Three.js backdrop that follows the theme
  switcher.

## Engineering

- Analyzer: 0 issues · **988 tests passing** (16 new: upscaler DSP, Material U
  theme, network quality, home layout) · architecture rules enforced (≤300
  LOC per file, platform code stays in its layer).

## Downloads

| Platform | File | Notes |
|---|---|---|
| Android (most phones) | `Noctra-1.1.1-arm64-v8a.apk` | Android 8.0+ |
| Android (older 32-bit) | `Noctra-1.1.1-armeabi-v7a.apk` | legacy ARM |
| Android (emulators/x86) | `Noctra-1.1.1-x86_64.apk` | x86_64 |
| Android (any device) | `Noctra-1.1.1-Universal.apk` | compatibility fallback |
| Android (Play-style) | `Noctra-1.1.1.aab` | sideload via bundletool |
| Windows | `Noctra-1.1.1-Setup-x64.exe` | installer, per-user |
| Linux | `noctra_1.1.1_amd64.deb` | Debian/Ubuntu |
| iOS | `Noctra-1.1.1.ipa` | sideload via AltStore/Sign tools |

SHA-256 checksums for every artifact ship in `SHA256SUMS.txt`. Verify before
installing: `sha256sum -c SHA256SUMS.txt` (or `certutil -hashfile <file>
SHA256` on Windows).

## Upgrade notes

- Installs cleanly over v1.1.0 (same signing identity, higher version code).
- No data migration: library, downloads, settings and the trained model all
  carry over untouched.
