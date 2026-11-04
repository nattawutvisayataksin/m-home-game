# Nightly Development Log — LAST LIGHT

## Entry — 3D Audio Buses & SFX (2026-11-04, working session 2)

**Author:** opencode (GLM-5.3-Flash Free)
**Scope:** เฟส B ตามแผนที่ตกลงกับผู้ใช้ — เสียงชุดแรกของโปรเจกต์ 3D: procedural SFX, audio bus layout, AudioDirector ต่อรอบ, และจุดเล่นเสียงครบทุก event สำคัญ เทสต์เขียวทั้งหมด (3D: 4 suites)

### Procedural audio assets
- สคริปต์ใหม่ `scripts/generate_sfx_3d.py` แบบเพลูกแบบเดียวกับสคริปต์ของฉบับ 2D (`generate_sfx.py`)
- สังเคราะห์แบบ deterministic และจบการผลิตทันที ได้ไฟล์เสียง 11 ไฟล์ใน `projects/last-light-3d/assets/audio/`
- รายการเสียง: `turret_shot` / `resonator_pulse` / `tangle_cast` (ป้อมแต่ละแบบเสียงไม่บางเสียง) `hit` (ศัตรูตาย) `leak` (ศัตรูผ่านแนว) `breach` (Shelter แตก) `wave_horn` (เปิดคลื่น) `build` (วางป้อม) `upgrade` (อัปเกรด เป็นเสียงชนะด้วย) `sell` (ขาย) อีกหนึ่งไฟล์คือ ambient `beacon_ambient_3d.wav` วน 16 วิ

### Bus layout + wiring
- สร้าง `projects/last-light-3d/assets/audio/audio_bus_layout.tres` ให้เสียงทุกเสียงมีที่ชี้ผ่าน bus ที่ผูกกับหน้า settings และอ้างอิงผ่าน `project.godot` `[audio] buses/default_bus_layout`
- bus ตั้งไว้ 4 ช่อง: Master / Music / SFX / UI (จากรายการ 2D เลือกเฉพาะที่ใช้)
- ไฟล์ใหม่ `scripts/systems/td_audio_director.gd` ฎหบัตร เพราะรันเป็นเจ้าของเสียง: pool 8 players บน bus SFX รองรับเสียงซ้อน (polyphony 2) ส่วน ambient วนบน bus Music ที่ -12 dB
- ข้อยกเว้น: ไม่เล่นเสียงจากหัวจุกหน้าโหนดตัวเกม — `TDTower` ได้ signal `fired(kind)` เพิ่มมาตอนยิงแล้วให้ `td_run._on_tower_fired` แยกเสียงตามชนิดป้อม และจุดตัดสินของ run คือเสียงที่จะเล่น (วาง อัปเกรด ขาย เปิดคลื่น ตาย ผ่านแนว ชนะ แพ้)
- Headless test ไม่มีอุปกรณ์เสียง — director เปลี่ยนโหมด being disabled โดยไม่พัง (แบบเดียวกับฉบับ 2D)

### Tests & verification
- เทสต์ใหม่ `tests/phase4_audio_test.gd` และเพิ่มใน `scripts/test-3d.ps1` เป็นชุดที่ 4 ตรวจ bus SFX/Music มีและอยู่ใต้ Master, TDSettings เลื่อนค่า bus ได้จริง, run มี AudioDirector, signal `fired` มีอยู่ และการเล่นเสียงบนเวิร์กเบิลจากทุกจุด connection-safe
- `dev-3d.ps1 -Action import` สแกนและ reimport ไฟล์เสียงใหม่ครบ 11 ไฟล์
- `dev-3d.ps1 -Action check` → 0 errors (14 scripts); `test-3d.ps1` → PHASE 1-4 PASSED

### Next
- เฟส C — 3D VFX & Juice: บังคับเอฟเฟกต์ทุกชิ้นมาจาก `TDSettings.get_reduce_flashes()` / `get_reduce_motion()` ทุกครั้งก่อนเกิดเอฟเฟกต์
- เฟส D — Wave pacing data pass: ยังห้ามเปลี่ยนตัวเลข balance จนกว่าจะมี metrics รอบจริงจากผู้เล่นพร้อมอ้างอิง

---

## Entry — 3D Settings Menu + Settings Store + Pause-menu Esc fix (2026-11-04, working session)

**Author:** opencode (GLM-5.3-Flash Free)
**Scope:** Phase TD-2 polish item "Settings Menu (Volume / Accessibility)" — ส่วนแรกของเฟส next-up จาก handoff; แก้ Esc-resume ที่หลุดขณะ pause พร้อมกัน. All suites green (3D: 3 suites, 2D: 6 suites).

### Settings Store (Autoload)
- ไฟล์ใหม่ `scripts/systems/td_settings_store.gd` (`class_name TDSettingsStore`), ลงทะเบียน autoload ชื่อ `TDSettings` ใน `project.godot`
  - เป็น "ศูนย์กลาง" ของค่าตั้งค่า: master/sfx/music volume (dB), reduce_flashes, reduce_motion, large_text — pattern เดียวกับ 2D (`user://settings.cfg` + ConfigFile sections `audio` / `accessibility`)
  - แยกจาก ProfileRepository (progression save) ตามแบบเดิม; apply master bus ผ่าน AudioServer ทันทีที่เปลี่ยน (SFX/Music bus ยังไม่มี — guard ไว้, จะรับค่าอัตโนมัติเมื่อเฟส Audio สร้าง bus)
  - `ui_font_size(base)` คือการเข้าถึงตัวเดียวของ UI ทุกจุดสำหรับ large text (+4px)
  - สัญญาณ `settings_changed(section, key)` ให้ UI ที่สร้างไว้แล้ว rescale ทันที
  - `settings_path` เป็น var รับ override ได้เพื่อเทสต์ใช้ไฟล์แยก (`user://phase3_settings_test.cfg`, ลบทิ้งหลังเทสต์) — ไม่แตะ settings.cfg จริงของผู้เล่นตอนรันเทสต์

### Settings UI (ใช้ร่วม title + pause)
- ไฟล์ใหม่ `scripts/ui/td_settings_panel.gd` (`class_name TDSettingsPanel`): panel สร้างในโค้ด — slider เสียง 3 ช่อง (−40..+6 dB), CheckButton 3 ตัว (reduce flashes/motion, large text), ปุ่มย้อนกลับ + signal `closed`
- เปลี่ยนค่าใช้ได้ทันทีและบันทึกทันที; large text rescale ตัวหนังสือทั้ง title และ pause เดี๋ยวนั้น (ผ่าน self-check ภาพ in-engine)
- Title menu: เพิ่มปุ่ม "ตั้งค่า" + overlay settings; HUD: เพิ่มปุ่ม "ตั้งค่า (Settings)" ใน pause menu + overlay settings (process_mode ALWAYS ทำงานได้ตอน paused)

### Bug ที่เจอและแก้ระหว่างทาง
1. **Esc-resume หลัง pause ไม่เคยทำงานในเกมจริง** — `td_run` เป็น pausable จึงไม่ได้รับ `_unhandled_input` ตอน tree paused (เทสต์เดิมเรียก `toggle_pause()` ตรง ๆ จึงไม่เห็นหาย) → ย้ายการจัดการ Esc ไปที่ HUD (`process_mode = PROCESS_MODE_ALWAYS`): ลำดับ Esc = ปิด settings ก่อน → แล้วจึง toggle pause; `td_run` ตัด KEY_ESCAPE ออก
2. **ColorRect ฉากหลังมืดถูก squish ใน CenterContainer** — ใส่ bg ไว้ใน CenterContainer ทำให้ถูกย่อเหลือ min size ฉากหลังไม่คลุมจอ (pause เดิมก็เป็นแบบนี้ จอแถมยังทะลุไม่มืด) → เปลี่ยน pause/settings overlay เป็น Control host เต็มจอ + bg ลูกแยก + CenterContainer ครอบกล่อง panel เฉพาะเนื้อหา
3. **ข้อความ pause ทะลุผ่าน settings panel** (stylebox โปร่งแสงซ้อนกัน) → ตอนเปิด settings ซ่อน pause overlay ไว้ชั่วคราว (`_pause_was_open`) แล้วคืนตอนปิด
4. Autoload identifier (`TDSettings.`) ใช้ตรง ๆ เขียนในโค้ดไม่ผ่าน `--check-only` ("Identifier not found") → เข้าถึงผ่าน `get_node("/root/TDSettings") as TDSettingsStore` ตาม handoff warning + `dev-3d.ps1 -Action import` หลังเพิ่ม class_name ใหม่

### Tests & verification
- เทสต์ใหม่ `tests/phase3_settings_test.gd` (+ ลงใน `scripts/test-3d.ps1` = 3 suites): autoload มีจริง, master bus apply จริง, save/load round-trip บนไฟล์ test แยก, `ui_font_size` สองโหมด, signal tags ถูก section/key, title panel เปิด/ปิดและ large text rescale สด, pause settings เปิด → Esc ปิด settings (ยัง paused) → Esc สองครั้ง resume
- Visual check ด้วย in-engine selfshot เท่านั้น (สคริปต์ชั่วคราว ลบทิ้งแล้ว ไม่ capture desktop): title settings panel กึ่งกลาง/ไม่มีทะลุ, large-text variant, pause settings บนฉาก 3D — ตรวจภาพจริงทั้งสาม
- `dev-3d.ps1 -Action check` → 0 errors (13 scripts) | `test-3d.ps1` → PHASE 1–3 PASSED | `test.ps1` → PHASE 1..6 PASSED (2D ไม่ถูกแตะ)

### สำหรับเฟสถัดไป (จากแผนที่ตกลงกับผู้ใช้)
- เฟส B Audio Buses & SFX: สร้าง bus Music/SFX แล้วค่า volume จาก settings store จะผูกเข้าเอง; ทุกเสียงดีดผ่าน bus เพื่อให้ slider คุมได้ทันที
- เฟส C VFX & Juice: อ่าน `reduce_flashes` / `reduce_motion` จาก store ก่อนเกิดเอฟเฟกต์ทุกชิ้น
- เฟส D Wave pacing: ปรับ .tres ด้วย metrics จาก `user://metrics/` เท่านั้น

---

## Entry — TD-2 Complete Low-Poly Asset Suite & Pause Menu (2026-11-03, working session)

**Author:** AI agent (Antigravity)
**Scope:** Full low-poly .glb generation via Blender 5.2 (towers, enemies, shelter), data .tres wiring, Pause Menu implementation (Esc), 3D test suite expansion. All suites green.

### Deliverables
- **Asset Generation (Blender 5.2):** สร้างสคริปต์ `scripts/generate_assets.py` ผลิต low-poly GLB assets ตามสเปก `docs/TD2_ASSET_PLAN.md` ครบถ้วน:
  - Towers (3/3): `field_turret.glb`, `sonic_resonator.glb`, `tangle_emitter.glb`
  - Enemies (4/4): `drifter.glb`, `skitter.glb`, `dasher.glb`, `warden.glb`
  - Props (1): `shelter.glb`
- **Data & Runtime Wiring:**
  - ผูก `model_scene` เข้ากับทุก `.tres` ใน `data/towers/` และ `data/enemies/`
  - อัปเดต `td_run.gd` ให้ instantiate `shelter.glb` แทน greybox box
  - รัน Godot asset re-import ผ่าน `dev-3d.ps1 -Action import`
- **Pause Menu (Esc) & In-Game Navigation:**
  - เพิ่มหน้าต่าง Pause Menu ใน `td_hud.gd` (Resume, Restart, Return to Main Menu)
  - ผูกปุ่ม `KEY_ESCAPE` ใน `td_run.gd` ให้เรียก `toggle_pause()` จัดการ `get_tree().paused`
  - เพิ่มปุ่ม "Main Menu" ใน Result Overlay เมื่อจบเกม (ชนะ/แพ้) เพื่อให้ผู้เล่นกลับหน้าแรกได้
- **Test Verification:**
  - เพิ่ม assertion ตรวจสอบว่า definition ทุกชิ้น (towers ทั้ง 3 ตัว, enemies ทั้ง 4 ตัว) มี `model_scene != null`
  - เพิ่มเทสต์ `toggle_pause()` ตรวจสอบสถานะ pause/unpause และ HUD overlay toggle
  - `dev-3d.ps1 -Action check` → 0 errors
  - `test-3d.ps1` → Phase 1 + Phase 2 PASSED
  - `test.ps1` → Phase 1..6 PASSED (2D untouched & safe)

---

## Entry — TD-1 finish + title menu + marketing/handoff kit (2026-11-03, working session)

**Author:** AI agent
**Scope:** Data migration (.tres), tower upgrade/sell, 3D title menu, brand logo, marketing kit, AI-handoff docs. All suites green.

### TD-1 closed out (implementation complete, pending live-play verification)
- Balance data moved to `.tres`: `data/enemies/*.tres` (4), `data/towers/*.tres` (3), `data/waves/wave_01..08.tres` via typed Resource classes in `scripts/data/` (`TDEnemyDefinition` / `TDTowerDefinition` / `TDWaveDefinition`). `td_run.gd` no longer carries unit balance — it preloads definitions and wires them.
- Economics stayed as named constants in `td_run.gd` (START_PARTS 120, START_INTEGRITY 10, WAVE_CLEAR_BONUS 20, INTEGRITY_BONUS 5, SELL_REFUND_RATIO 0.7) — session config, not unit balance.
- Tower upgrade/sell: `td_tower.gd` gained `level` (max 2), `can_upgrade()`, `apply_upgrade()` (damage ×1.5^lv, rate ×0.8^lv, range +0.6/lv, slow ×0.85^lv — factors live in TDTowerDefinition). `td_run.gd` routes LMB on occupied slot → upgrade, RMB → sell (refund 70% of invested; invested tracking accumulates upgrade costs). Slot state is parallel arrays (`_slot_towers/_disks/_occupied/_invested`). Metrics got `tower_upgraded` / `tower_sold` events.
- Title menu added (`scenes/ui/title.tscn` + `scripts/ui/title_menu.gd`, main scene switched): เริ่มการรบ / วิธีการเล่น / เรื่องราว / ออกจากเกม, bbcode content panels, Esc closes, Thai-first copy from STORY.md.

### Branding
- Vector logo `projects/last-light-3d/assets/brand/logo_emblem.svg` (+ copy in `docs/art/`): amber lantern over the Shelter 09 silhouette with a signal beam, dark badge; rendered as the title-screen emblem.

### Tests
- `phase1_3d_smoke.gd` updated for the .tres structure (spawn interval from wave definition, slot-tower registration).
- New `phase2_td_data_title_test.gd`: .tres sanity (ids, positive stats, upgrade costs, wave composition keys must exist in ENEMY_DEFS), upgrade accounting (cost charged, invested accumulates, range grows, level cap respected), sell accounting (70% refund, slot reusable), title menu flow (panels toggle, one at a time, `_start_mission()` reaches the run with baseline economy).
- Visual check: title screen verified via **in-engine viewport capture** (`tests/dev_title_selfshot.gd`) — logo/subtitle/tagline/buttons and the how-to panel all render correctly. This is now the standard way to do visual checks on this machine (a desktop capture attempt caught one of the user's unrelated windows again; that image was discarded and whole-desktop captures are banned for good).

### Marketing + handoff
- `docs/MARKETING.md`: positioning/taglines (TH+EN), itch/Steam store copy, feature bullets, brand palette + logo usage rules, channel plan, trailer hooks, launch checklist.
- `AGENTS.md` (root) + `docs/AI_HANDOFF.md`: repo map, commands, conventions, scope guards, known TODOs, decided vs. open questions — prepared for Codex / Copilot / Antigravity.

### Final verification
- `.\scripts\dev-3d.ps1 -Action check` → 0 errors (10 scripts).
- `.\scripts\test-3d.ps1` → PHASE 1 + PHASE 2 PASSED.
- 2D suites untouched this session (no `projects/last-light/` code changes).

### Next up
- Live play-verify TD-1 (wave pacing/economy) and record findings + metrics-driven balance notes.
- TD-2 Blender asset pass once the AI Bridge is reachable.
- Pause menu, settings/accessibility for the 3D build.

---

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