# Changelog

## v1.1.5 (2026-09-01)

### 🎵 Audio & Playback
- Improved stream resolver pipeline with 6-tier fallback (Local → Direct → JioSaavn → Native → InnerTube → YouTube Web Search)
- New `YoutubeWebSearchResolver` for songs that fail all other tiers
- Deep YTMusic result parsing: handles `musicTwoRowItemRenderer`, `musicShelfRenderer`, and flexColumn fallback
- Increased NativeKotlinResolver timeout from 4s to 6s
- Fixed songs not playing due to incomplete videoId extraction

### 🎨 Dynamic Launcher Icon
- Proper activity-alias system with `.default` alias owning the LAUNCHER entry
- Theme-aware launcher icons: Noir Black, Noir White, AMOLED, Liquid Glass
- Deferred icon swap — applies when app goes to background to avoid process kill
- `WidgetsBindingObserver` integration for lifecycle-aware icon updates

### 🌐 Internationalization (8 languages)
- Full i18n system: English, Hindi, Punjabi, Urdu, Kannada, Tamil, Marathi, Odia
- Language switcher in Settings with all 8 languages
- Updated all UI strings to use `NoctraLocalization.tr()`

### 🧠 Neural Recommendation Engine v2
- Expanded from 88→120 input dimensions
- 4-layer MLP: 120→64→32→16→1 (was 88→40→20→1)
- New feature dimensions: audio features (8d), temporal encoding (8d), listening patterns (8d), cross-platform metadata (8d)
- Deezer audio features integration (zero API key): energy, danceability, valence, tempo
- MusicBrainz enhanced: ISRC lookup, artist credits, rate limiting

### 🎨 Theme System
- Liquid Glass theme brightened — visible sapphire blue (#162E4A) instead of near-black
- Dynamic `MaterialApp` theme — both `theme:` and `darkTheme:` update simultaneously
- Splash screen uses theme tokens instead of hardcoded colors

### 🎵 Audio Router
- Multi-output audio routing implementation
- Dual Bluetooth/speaker output support

### 🐛 Bug Fixes
- Fixed Python syntax error in `backend/routes/api_routes.py`
- Fixed line length violations in test files
- Fixed widget test for updated localization (Spanish/French → Punjabi/Kannada)
- Removed unused imports across codebase
- Fixed `deprecated_member_use` for `onReorder` in queue sheet

### ✅ Quality
- 320/320 tests passing
- 0 flutter analyze issues
- Comprehensive test coverage for search, resolver, lyrics, and neural engine
