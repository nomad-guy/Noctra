# Noctra v1.1.0

**Release date:** 2026-09-16
**Previous release:** v1.0.9

## Highlights

The recommender finally learns from everything you do — favoriting,
downloading, playlist adds, search picks and repeat-one loops all train the
AI now (previously every one of those signals was silently dropped). Plus a
deep-audit pass over playback volume handling fixed the last of the
"sound cuts / stuck at low volume" bugs, and several performance
optimizations landed across the app.

## AI Recommendations

- **All taste signals wired**: the signal tracker had handlers for favorite,
  download, playlist-add, search-select and replay — but nothing called
  them. Now: ❤️ (mini player, player bar, assistant, context menu),
  completing a download, adding to a folder/playlist, tapping a search
  result, and Repeat One loops all train the model.
- **Session momentum stabilized**: the model's session-context feature
  sorted 32 taste axes by magnitude before compressing to 8 — destroying
  which axes moved, so the same listening shift fed the network different
  noise on every call. It now uses 8 fixed thematic buckets (tone, energy,
  mood, vocals, texture, cultural, percussion, modern).
- **Signals stay real-time offline**: audio-feature lookups no longer gate
  taste updates (they had up to 6s of network timeouts per event; now 900ms
  with neutral fallback).

## Playback & Volume

- Volume slider no longer cancels in-flight fades (it used to kill sleep
  fades mid-ramp and race track-change fade-ins).
- Sleep timer fades from the canonical volume, not whatever the player's
  live level happened to be — the old no-op fade that "restored" silence.
- Phone-call ducking can no longer strand a track at 20% volume across a
  track change or an `unknown`-type interruption end.
- Previous at queue start wraps around like Next.
- Restore only reuses the persisted position when it belongs to the restored
  song — no more resuming mid-track in the wrong song after queue edits.
- Download failures now reject CDN error pages (expired tokens previously
  wrote unplayable files to disk), with a red retry icon in the library.

## Performance

- AI Studio feed: shared play-queue built once instead of O(n²) per rebuild.
- Manifest artist/genre/language weights update incrementally per play
  instead of a full 500-entry × 3-map rebuild on every track change.
- Image decode downsampling applied to the last tiles missing it (Jam queue,
  recently-played sheet, AI Studio rows) — lower bitmap memory on lists.

## Engineering

- Analyzer: 0 issues · **972 tests passing** · architecture rules enforced
  (≤300 LOC per file; taste signals route through composition-layer
  callbacks so no data → services/ai import cycle exists).

## Downloads

| Platform | File | Notes |
|---|---|---|
| Android (most phones) | `Noctra-1.1.0-arm64-v8a.apk` | Android 8.0+ |
| Android (older 32-bit) | `Noctra-1.1.0-armeabi-v7a.apk` | legacy ARM |
| Android (emulators/x86) | `Noctra-1.1.0-x86_64.apk` | x86_64 |
| Android (any device) | `Noctra-1.1.0-Universal.apk` | compatibility fallback |
| Android (Play-style) | `Noctra-1.1.0.aab` | sideload via bundletool |
| Windows | `Noctra-1.1.0-Setup-x64.exe` | installer, per-user |
| Linux | `noctra_1.1.0_amd64.deb` | Debian/Ubuntu |
| iOS | `Noctra-1.1.0.ipa` | sideload via AltStore/Sign tools |

SHA-256 checksums for every artifact ship in `SHA256SUMS.txt`. Verify before
installing: `sha256sum -c SHA256SUMS.txt` (or `certutil -hashfile <file>
SHA256` on Windows).

## Upgrade notes

- Installs cleanly over v1.0.9 (same signing identity, higher version code).
- No data migration: library, downloads, settings and the trained model all
  carry over untouched.
