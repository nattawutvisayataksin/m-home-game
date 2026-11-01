# Nightly Development Log — LAST LIGHT

**Date:** 2026-11-01 (overnight session)
**Author:** AI agent (autonomous, with Game Director approval)
**Scope:** Fun-first polish pass on Windows prototype; no combat-value/schema/input/progression changes.

## Summary
Improved game feel ("juice"), readability, and dev-tooling robustness without changing
gameplay rules. All automated tests remain green.

## Changes

### Game feel (scripts/gameplay)
- `combat_effect.gd`: added 4 new effect kinds:
  - 3 death burst (expanding ring + particles)
  - 4 muzzle flash
  - 5 upgrade/charge-ready burst (golden ring)
  - 6 breach flash (red lane flash)
- `run.gd`:
  - Enemy hit flash already in enemy.gd; death burst spawned on `destroyed` signal.
  - Muzzle flash on every shot.
  - Upgrade burst on weapon upgrade and when Parts meter fills.
  - Breach flash + subtle screen shake on breach and boss attack.
  - Screen shake decays and is gated by `reduce_flashes` (treated as reduce-motion).
  - Shake state reset on pause/end to avoid stuck offsets.

### Enemy readability (scripts/actors/enemy.gd)
- Added hit flash: sprite modulates to white then back on `take_damage`.
- Added `destroyed(position)` signal for centralized death-burst spawning.

### Art (scripts/generate_pixel_art.py + PNGs)
- Regenerated improved sprites: survivor (helmet/vest/rifle detail), drifter, skitter,
  dasher, rift warden (eyes/teeth detail). Palette and dimensions unchanged, so
  scene references and import settings remain valid.

### Dev tooling (scripts/)
- `dev.ps1`, `test.ps1`, `export.ps1`: `ErrorActionPreference` changed from `Stop` to
  `Continue` so native Godot stderr (e.g. the Android build-tools warning on machines
  without the Android SDK) no longer aborts scripts that otherwise exit 0. Explicit
  exit-code checks are retained.

## Verification
- `.\scripts\dev.ps1 -Action check` → 0 errors, 0 warnings (79 files).
- `.\scripts\dev.ps1 -Action import` → exit 0.
- `.\scripts\test.ps1` → Phase 1 smoke, Phase 3 save, Phase 4 stress all PASSED.

## Notes / deferred
- Android SDK/JDK still not installed; Android export remains deferred per roadmap.
- No human playtest performed; balance numbers unchanged pending real playtest.
- Object pooling for projectiles deferred (stress test already meets 60 FPS target).
- Commit & push performed so the home machine can pull these changes.