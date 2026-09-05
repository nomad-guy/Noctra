# Noctra Architecture

This document describes the **actual** module boundaries of the Noctra
codebase and the dependency rules that keep them intact. It is maintained
alongside the mechanical enforcement in `test/architecture_boundaries_test.dart`
and `tool/cycle_check.py`.

## Layer map

```
lib/
├── core/        Leaf utilities + theme. Imports nothing internal.
├── shared/      Cross-layer visual primitives (e.g. GlassCard) importable by any layer.
├── data/
│   ├── models/       Domain models (Song, Playlist, folders, presets…)
│   ├── sources/      Persistence (NoctraLocalDatabase + part files)
│   └── repositories/ Facade over sources + providers (MusicRepository + parts)
├── services/    Application/infrastructure services (audio, resolvers, ytdlp,
│                lyrics, p2p, updater, ai, metadata, migration, discovery)
├── providers/   Riverpod wiring layer between services/data and UI
└── ui/          Presentation (screens + widgets)
```

## Dependency direction (enforced)

```
core   ← data ← services ← providers ← ui
  └────────────── shared (importable by every layer)
```

Concrete rules (mechanically checked in `test/architecture_boundaries_test.dart`):

1. **LOC**: no source file under `lib/` exceeds 300 lines.
2. **Cycles**: no import cycles between `lib/` Dart files.
3. **`core`** never imports data/services/providers/ui.
4. **`data`** never imports services (single documented exception: repository
   parts may call `services/ytdlp/music_service.dart`, which acts as the remote
   provider data source), nor ui/providers.
5. **`services`** never imports ui/providers.
6. **`ui`** never imports `data/sources` directly — persistence is reached
   through the repository/provider layer.

## State ownership

| Domain          | Authoritative owner                                   | UI projection |
|-----------------|-------------------------------------------------------|---------------|
| Library/favorites/downloads/queue | `MusicRepository` (ChangeNotifier + `NoctraLocalDatabase`) | Riverpod providers |
| Playback        | `AudioPlayerService` (+ `parts/*` mixins)             | `positionStreamProvider` etc. |
| Theme           | `themeModeProvider`                                   | `NoirTheme.getTheme` |
| Downloads location | `downloadLocationProvider` (persisted via repository) | — |

## Why these files moved (slice history)

- `ui/widgets/glass_card.dart` → `shared/widgets/glass_card.dart`: GlassCard is
  a presentation primitive used by both `ui/` and the updater's presentation
  widgets under `services/`. Its old location forced a `services → ui` import;
  `shared/` gives every layer one legal home for cross-cutting visual
  primitives.
- Presentation code that used to construct `NoctraLocalDatabase()` /
  `MusicRepository()` directly now reads the repository through the provider
  (`musicRepositoryProvider`), keeping persistence behind the data boundary.
- `timeOfDayGreeting` moved from `MusicRepository` to
  `core/utils/time_of_day_greeting.dart`: it is pure presentation logic with no
  repository state, and widgets no longer need a data-layer import to render it.

## Enforcement

- `flutter test test/architecture_boundaries_test.dart` — LOC/cycle/layer rules.
- `python tool/cycle_check.py` — standalone cycle scanner for quick checks.
- `python tool/move_glass_card.py` — import-rewrite helper used for the shared/
  relocation (kept for repeatable moves).

## Known seams & future work

- `services/updater/widgets/` holds updater presentation inside the updater
  service module; a full feature-tree extraction would move it under the
  updater feature's presentation area. It currently depends only on `shared/`
  for visuals, so no `services → ui` edge remains.
- Full physical re-organization into `features/*` trees is intentionally NOT a
  folder shuffle: it must follow the strangler pattern, one module at a time,
  keeping the app green after each stage.
