# NOCTRA — PHASE SM: SPEAKER MESH (MULTI-DEVICE AUDIO SYNC)

**Codename:** Speaker Mesh ("Every phone becomes a speaker")
**Repository:** `nomad-guy/Noctra`
**Prerequisite:** v1.0.8+ stable, P2PSyncService (Jam) audited and green
**Distribution:** GitHub Releases only; LAN-only feature
**Model target:** work in bounded slices, one commit per slice, tests green at every slice boundary

---

# 0. MISSION

Let a user play one song on one device and hear it — *in sync* — from every
phone in the room, each phone optionally outputting to its paired Bluetooth
speaker. The result behaves like one distributed multi-room speaker system:

```text
              Noctra HOST (plays the track)
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
    Phone A       Phone B      Phone C
        │            │            │
   BT speaker    BT speaker    phone speaker
```

This is NOT casting the same audio file over the network. Every device plays
its own local copy of the same track, started at a shared wall-clock anchor.
Network traffic per track is metadata only (song ID + anchor + commands), so
the mesh scales to room-sized groups without saturating Wi-Fi.

---

# 1. NON-NEGOTIABLE CONSTRAINTS

1. **Preserve Jam.** SyncCast/Jam behavior must not regress. Speaker Mesh is a
   NEW transport consumer over the existing discovery/auth/socket engine, not
   a fork of P2PSyncService.
2. **≤300 LOC per file** (repo architecture test enforces this — it failed the
   build once already this session; treat it as a hard gate).
3. **No cloud.** LAN only. No telemetry. No accounts. Reuse Jam's
   room-code + HMAC challenge auth as-is.
4. **Do not weaken playback.** The host's AudioPlayerService must not gain
   mesh-specific hacks. All mesh logic lives in services + presentation.
5. **Graceful degradation everywhere.** A device that can't keep sync
   (slow Wi-Fi, BT latency spikes) must drop to solo mode or leave the mesh —
   never produce overlapping echo audio on the host.
6. **Existing users unaffected.** Feature ships behind a user action
   ("Start Speaker Mesh"); nothing changes for users who never open it.

---

# 2. WHAT ALREADY EXISTS (build on this — do not rebuild)

Audited from the current codebase:

| Existing asset | Reuse for mesh |
|---|---|
| `P2PSyncService` TCP transport (port 8099) | control channel for anchor/command packets |
| UDP beacon discovery (8089/8098) + room codes | mesh room discovery ("meshes near you") |
| HMAC-SHA256 challenge auth, rate limiting, payload caps | join handshake security |
| Heartbeat + liveness timers | member dropout detection |
| Session epoch + sync-sequence counters | stale-packet protection |
| `_isApplyingRemoteSync` re-entrancy guard | pattern for preventing command echoes |
| `AudioPlayerService` precise seek + volume ramps | start-at-anchor primitive |
| Per-device BT output already works (OS routing) | each phone can route mesh output to its BT speaker |

---

# 3. SYNC ARCHITECTURE

## 3.1 The core primitive: anchored playback

Every member executes the same two-step:

```text
1. T0 = agreed wall-clock anchor (host clock, mapped to local clock)
2. load track → seek(anchorOffset) → play at exactly T0
```

Start offset = 0 for a fresh track; mid-track for late joiners.

## 3.2 Clock sync: NTP-style round-trip estimation

Run against the host every ~10 s (and on demand after network jitter):

```text
t1 = host_tx, t2 = member_rx, t3 = member_tx2, t4 = host_rx
offset = ((t2 - t1) - (t4 - t3)) / 2      (host clock minus local clock)
rtt    = (t4 - t1) - (t3 - t2)
```

Keep min-RTT samples (best 5 of last 20), discard >250 ms outliers, expose
`clockOffsetMs` + `rttMs` as metrics. Members with unstable estimates
(rtt jitter > 60 ms) display a warning chip and are excluded from
"quality" reporting but still play.

## 3.3 Roles

```text
HOST    — owns playback decisions (play/pause/seek/skip), broadcasts anchors
MEMBER  — mirrors host state; never originates playback commands
BRIDGE  — (stretch) host-role device with no BT output of its own that
          still participates; v1 does NOT implement dedicated bridge roles
```

Single-host-only in v1. Host migration = explicit "leave mesh" by host
(dissolves session with a clear UX message). Automatic failover is a
documented non-goal for v1.

## 3.4 Packet vocabulary (all on the existing TCP channel, versioned)

```text
MESH_HELLO / MESH_WELCOME      join handshake (reuses Jam auth challenge)
MESH_CLOCK_PING / MESH_CLOCK_PONG
MESH_ANCHOR   {songId, anchorHostMs, startOffsetMs, epoch, seq}
MESH_CMD      {play|pause|seek|next|prev, params, epoch, seq}
MESH_STATE    {isPlaying, positionMs, volume}   periodic (2 s) reconciliation
MESH_KICK     {reason}
MESH_BYE      {reason}
```

All packets reuse the existing codec caps (≤64 KB, depth ≤64, rate limiting)
and sequence/epoch staleness checks.

## 3.5 The sync loop on each member

```text
on MESH_ANCHOR:
  guard: epoch/seq fresh, not applying remote sync
  localStart = anchorHostMs + clockOffsetMs
  delayToStart = localStart - now
  if delayToStart > 1500ms → schedule play (precise timer)
  elif 0 < delayToStart ≤ 1500ms → busy-wait tail for precision
  elif -2000 ≤ delayToStart < 0 → seek(startOffset + |late|) then play
  else (> 2 s late) → request re-anchor from host (MESH_STATE reconciliation)
```

Post-start drift correction: compare member position vs expected position
every 2 s via `MESH_STATE`; if |drift| > 120 ms, inaudibly correct
(`seek(position ± drift)` during playback; just_audio handles this without
glitches on local files and short MP3/AAC streams). Log every correction.

## 3.6 Bluetooth latency compensation (the hard part)

BT output adds 100–350 ms device-dependent latency that pure clock sync
cannot see. Strategy:

```text
audioLatencyMs = clockSync base
  + BT profile estimate (SBC ≈ 220 ms, AAC ≈ 160 ms, phone speaker ≈ 40 ms)
  + per-device manual trim (Settings slider, −500…+500 ms, persisted)
```

The estimate is applied as a *negative* start offset (BT devices start
early by their latency so sound waves arrive in sync). v1 ships profile
defaults + manual trim; automatic measurement (loopback via mic) is a
documented future item — it requires RECORD_AUDIO permission and careful
UX, so it is explicitly out of v1 scope.

---

# 4. TARGET MODULE LAYOUT (≤300 LOC each)

```text
lib/features/mesh/
├── domain/
│   ├── mesh_role.dart                 (enum + value objects)
│   ├── mesh_anchor.dart               (anchor model + math)
│   ├── mesh_clock.dart                (offset/rtt estimator, pure)
│   └── mesh_latency_profile.dart      (BT latency table + trim)
├── application/
│   ├── mesh_session_controller.dart   (orchestration, state machine)
│   └── mesh_drift_monitor.dart        (periodic reconciliation, pure-ish)
├── infrastructure/
│   ├── mesh_packet_codec.dart         (MESH_* packet mapping over Jam codec)
│   ├── mesh_transport_adapter.dart    (Jam P2P transport seam)
│   └── mesh_clock_probe.dart          (ping/pong exchange impl)
└── presentation/
    ├── mesh_sheet.dart                (join/host UI)
    ├── mesh_member_list.dart          (liveness + quality chips)
    └── mesh_latency_trim_sheet.dart   (per-device trim slider)
```

Integration points (thin adapters, no logic):
- `AudioPlayerService` — mesh calls existing public APIs only
  (playSong/seek/pause/skipNext/setVolume).
- `P2PSyncService` — expose a narrow internal seam: raw packet send/receive
  + auth + discovery reuse. If P2PSyncService cannot expose this cleanly,
  extract a `P2PTransport` interface from it first (strangler pattern),
  keep Jam behavior identical, then build the mesh on the interface.

---

# 5. FEATURE FLOW (v1 UX)

```text
Host: SyncCast sheet → "Speaker Mesh" tab → Start Mesh
  → room code shown (reuse Jam room codes)
Members: discovery list → tap room → auth challenge → join
  → member sees "Synced • 34 ms" chip, host sees member list grow
Host plays/pauses/seeks/skips → all members follow within ~120 ms
Any member: trim slider (Settings → Speaker Mesh → Audio trim)
Host leaves → mesh dissolves with message (v1 behavior)
```

Membership cap: reuse Jam's `maxPeers = 8` for v1.

---

# 6. WHAT v1 DOES **NOT** DO (document honestly)

- No automatic host failover
- No bridge/repeater role
- No automatic BT-latency measurement (manual trim + profile table only)
- No cross-network (internet) meshing — LAN only
- No guarantee of sample-accurate sync (target: ±120 ms perceived sync,
  which is the empirically acceptable threshold for distributed speakers;
  sample-accurate distributed playback is a research problem, not a phase)
- iOS: same implementation should work (mDNS/TCP available), but **do not
  claim iOS support until real-device tested**

---

# 7. IMPLEMENTATION SLICES (each = inspect → implement → test → build → commit)

## Slice SM-0 — Baseline & seams
- Run full analyzer/tests; record baseline.
- Extract `P2PTransport` seam from P2PSyncService (strangler, zero behavior
  change for Jam). Jam regression tests must stay green.

## Slice SM-1 — Clock sync core
- `MeshClock` (pure): offset/RTT math, min-RTT window, outlier rejection.
- Unit tests: synthetic t1–t4 samples, jitter, outliers, zero samples.

## Slice SM-2 — Packets & transport
- `MeshPacketCodec` + `MeshTransportAdapter` over the SM-0 seam.
- Tests: codec round-trip, staleness (epoch/seq), oversized/malformed input.

## Slice SM-3 — Anchored playback engine
- `MeshAnchor` math + member execution path (schedule/seek-late/re-anchor).
- Tests: all four delay branches; late-join mid-track; re-anchor loop.
- Integration harness: two fake players + fake transport, assert both
  "start" within N ms on a virtual clock.

## Slice SM-4 — Session controller + host commands
- `MeshSessionController` state machine (idle/hosting/member).
- Host: play/pause/seek/next/prev broadcast anchors/commands.
- Member: mirror + drift correction loop (`MeshDriftMonitor`).
- Tests: command echo suppression (`_isApplyingRemoteSync` pattern), member
  dropout (heartbeat timeout → list update), host leave → dissolve.

## Slice SM-5 — UI + latency trim
- Mesh sheet, member list, trim slider (persisted per device).
- Latency profile table + trim applied to anchor execution.
- Widget tests for the sheet; unit tests for trim math.

## Slice SM-6 — Real-device hardening
- 2+ physical Android devices, one BT speaker:
  sync quality log capture (drift histogram from MeshDriftMonitor logs),
  BT latency reality check vs profile table, mid-track join, member leaving
  with Wi-Fi off, host skips under load, 8-member cap behavior.
- Tune drift threshold (120 ms) and BT table from measurements.
- Do NOT ship claims beyond what this slice actually verified.

## Slice SM-7 — Release
- Docs (feature doc + PLATFORM.md capability row), changelog entry,
  workflow-built release. Feature flag remains "user-initiated only".

---

# 8. ACCEPTANCE CRITERIA

- [ ] Jam/SyncCast behavior unchanged (existing P2P test suite green)
- [ ] Analyzer 0 issues; full test suite green at every slice
- [ ] Clock estimator: unit-tested offset/RTT math with outlier handling
- [ ] Two-device demo: same track audible on both devices within ±120 ms
- [ ] Late joiner syncs mid-track correctly
- [ ] Member dropout detected within one heartbeat window; UI updates
- [ ] Host leaving dissolves cleanly (no zombie sessions)
- [ ] Per-device BT trim persists and audibly improves sync
- [ ] All files ≤300 LOC; no platform leaks outside approved boundaries
- [ ] Feature requires explicit user action; zero impact when unused

---

# 9. RISKS & MITIGATIONS

| Risk | Mitigation |
|---|---|
| Wi-Fi multicast/broadcast blocked on some routers | Jam already ships UDP discovery; mesh inherits its behavior — document router caveats instead of solving them |
| BT latency variance between phones | profile table + manual trim; measure in SM-6 |
| just_audio seek glitches during drift correction | correct at low frequency (2 s), only when >120 ms; log every correction for tuning |
| Phone sleep kills member player | mesh sheet keeps a foreground service via existing playback service; document battery impact |
| Two accounts on one GitHub (auth confusion) | n/a to code; ops note only |

---

# 10. OUT OF SCOPE (explicitly)

Cloud relay, internet meshing, sample-accurate DSP sync, crossfade-during-
mesh, mesh over Hotspot without LAN, iOS claims without device testing,
automatic latency measurement (RECORD_AUDIO).
