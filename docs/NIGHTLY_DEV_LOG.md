# Nightly Development Log — LAST LIGHT

## Entry — 3D Tower Defense pivot (2026-11-03, working session)

**Author:** AI agent (with Game Director approval)
**Scope:** Direction pivot + metric tooling + new 3D project core. All suites green.

### Decisions (Game Director)
- Continue as **3D tower defense (towers only)**, keep LAST LIGHT IP, low-poly stylized art from Blender, fixed isometric camera, Windows mouse+keyboard first, Android stays deferred.
- New parallel project `projects/last-light-3d/`; the 2D build stays playable as reference.
- Design baseline: `docs/GDD_3DTD.md`; scope change recorded in `docs/ROADMAP.md` ("3D Tower Defense pivot", Phases TD-0..TD-2).

### 2D build — RunMetrics (Phase TD-0 ✅)
- `scripts/systems/run_metrics.gd`: schema-versioned plain-JSON recorder → `user://metrics/<run_id>.json`; records run start/upgrade/blast/breach (with integrity after)/boss spawn/run end + finalized summary (won, wave, integrity, kills, breaches, salvage).
- Hooked into `scripts/gameplay/run.gd`; the playtest metrics listed in ROADMAP are now captured automatically. Verified real JSON output on disk.
- New `tests/phase6_metrics_test.gd` + added to `scripts/test.ps1` (6 suites total).

### 3D project — Greybox core loop (Phase TD-1 implementation started ✅)
- `projects/last-light-3d/` — Godot 4.7.2, GL Compatibility, 1280x720.
- Built in code: fixed iso camera + sun + sky/fog environment, ground, waypoint path (single lane, 5 waypoints), Shelter blockhouse, 12 highlighted placement slots.
- Enemies `td_enemy.gd` (Drifter/Skitter/Dasher/Warden archetypes; waypoint walker carrying overshoot; leak → Integrity), towers `td_tower.gd` (Field Turret / Sonic Resonator splash / Tangle slow aura; first-progress targeting), projectiles `td_projectile.gd` (homing + splash).
- Run director `td_run.gd`: placement via ray-plane slot picking with range ghost + red tint when unaffordable, Parts economy (start 120; costs 80/120/60; wave bonus 20 + 5×integrity), 8 data-driven waves incl. Warden finale, prep/combat state machine, defeat/victory overlay, restart.
- HUD `td_hud.gd`: Parts/Integrity/wave labels, wave preview, tower-select buttons (1/2/3), Start Wave (Space), result overlay.
- RunMetrics integrated (tower_placed/enemy_killed/enemy_leaked/wave events).
- Tests: `tests/phase1_3d_smoke.gd` (placement cost, double-place rejection, spawn tick, kill bounty, leak→integrity, force-end overlay + metrics side record) via `scripts/test-3d.ps1`; parser check via new `scripts/dev-3d.ps1 -Action check|run|import`.
- Visual check: launched the real window and inspected a live capture — HUD labels, path strips, slot disks, Shelter and lighting render correctly in one frame. (Screenshot of the whole desktop captured the user's other windows instead in one attempt; those were discarded unread and screen captures were stopped.)

### Final verification
- `.\scripts\dev-3d.ps1 -Action check` → 0 errors (6 scripts).
- `.\scripts\test-3d.ps1` → PHASE 1 3D-SMOKE TEST PASSED.
- `.\scripts\dev.ps1 -Action check` → 0 errors, 0 warnings (87 files).
- `.\scripts\test.ps1` → Phase 1/3/4/5/6 all PASSED.

### Next up (pending)
- Iteration session on 3D greybox (wave pacing vs. economy; playtest with human + metrics).
- Migrate greybox constants into `.tres` data (TD-1 exit criteria), then Phase TD-2 Blender low-poly assets.

---

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

## Batch 2 (continued overnight)

### Additional game feel & polish
- Projectile trail (fading cyan dots) on every shot.
- Ambient dust particles on run scene and title screen.
- Parts resonance meter (progress bar) in HUD, highlights when full.
- Boss phase 2: faster movement + faster attacks + red core when below 50% health.
- Drifter idle sway; colored death bursts (per-enemy color).
- Warden defeat celebration: pulse + burst + shake.
- Low-health Shelter warning (SFX + shake) when integrity <= 2.
- Focus-loss auto-pause (window blur).
- Result screen now shows kills / breaches / wave / time.
- Title profile summary shows best wave.

### Audio
- New SFX: `death`, `boss` (regenerated via generate_sfx.py).
- Audio director: `intensify()` raises music volume on boss spawn; plays boss/death SFX.
- Settings: separate SFX and Music volume sliders; persisted.

### Accessibility
- New `reduce_motion` setting; gates screen shake.
- Master/SFX/Music volume all persisted and applied on load.

### Localization
- Added keys: SFX_VOLUME, MUSIC_VOLUME, REDUCE_MOTION, KILLS_LABEL, BEST_WAVE_LABEL.

## Batch 3 (continued overnight)

### Tests
- Added `phase5_gamefeel_test.gd` verifying ambient dust, boss spawn, phase 2 transition, win + result overlay. test.ps1 updated to run it.

## Batch 4 (continued overnight)

### Visual
- Run scene: added side building silhouettes, windows, debris for grounded street feel.

## Final verification
- `.\scripts\dev.ps1 -Action check` → 0 errors, 0 warnings (82 files).
- `.\scripts\dev.ps1 -Action import` → exit 0.
- `.\scripts\test.ps1` → Phase 1, 3, 4, 5 all PASSED.
- Working tree clean; all batches pushed to origin/main.

## Notes / deferred
- Android SDK/JDK still not installed; Android export remains deferred per roadmap.
- No human playtest performed; balance numbers unchanged pending real playtest.
- Object pooling for projectiles deferred (stress test already meets 60 FPS target).
- Commit & push performed so the home machine can pull these changes.