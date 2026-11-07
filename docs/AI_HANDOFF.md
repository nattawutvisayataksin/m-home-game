# LAST LIGHT — AI Handoff Document

อัปเดต: 2026-11-07 — หลัง Localization ไทย/อังกฤษครบทุกหน้า (TD-2 เช็กลิสต์ปิดครบ)
ข้อมูลสำหรับ AI agent (Codex / Copilot / Antigravity / opencode) ที่รับงานพัฒนาต่อภายใน repo นี้
คู่มือย่อฉบับเริ่มงาน: `AGENTS.md` (root) | กติกาข้อนี้ใช้ตามที่เขียนไว้ทั้งหมด

---

## 1) ตำแหน่งปัจจุบันของหน้างาน

คัฟเวอร์เกม: **LAST LIGHT** — สองตัวใน repo เดียว:

| โปรเจกต์ | สถานะ | บทบาท |
| --- | --- | --- |
| `projects/last-light/` (2D, Godot 4.7.2) | เสร็จถึง vertical-slice + metrics ครบ 6 suite | **แช่แข็ง** — ใช้เป็น playable reference + แหล่งเก็บ playtest metrics อย่างเดียว ห้ามแตะยกเว้น metrics |
| `projects/last-light-3d/` (3D, Godot 4.7.2, GL Compatibility) | TD-1 เสร็จโครงร่าง (เล่นได้ครบ loop รวม title menu, upgrade, sell, data .tres) | เกมหลักที่ทุกคนควร commit ต่อ |

Pivot จาก 2D → 3D tower defense ตัดสินโดย Game Director แล้ว (บันทึกใน `docs/ROADMAP.md` Phases TD-0..TD-2) งาน**ห้าม**กลับไปทำ survival-defense แบบมีตัวกลาง

## 2) เอกสารและข้อตกลงที่เหนือกว่าโค้ด

ลำดับหลักเมื่อเจอหัวข้อขัดแย้ง: **GDD → ROADMAP → dev log → comment ในโค้ด**

- `docs/GDD_3DTD.md` — design ของเกม 3D (ป้อม 4 / ศัตรู 4 / economy / camera / inputs) + บทเสริมสเปก asset 3D (poly budget, Blender workflow) ที่ยุบมาจาก TD2_ASSET_PLAN
- `docs/GDD.md` — baseline ของฉบับ 2D ที่แช่แข็ง (ที่มาของ IP + lore + progression) — ใช้เฉพาะกับโปรเจกต์ 2D
- `docs/ROADMAP.md` — เฟส TD-0/TD-1/TD-2 + เงื่อนไขจบของแต่ละเฟส
- `docs/NIGHTLY_DEV_LOG.md` — ประวัติการตั้งใจตัดสินแต่ละเซสชัน (entry เก่ายุบเป็น one-liner ฉบับเต็มดึงจาก git history)
- `docs/MARKETING.md` — copy ที่รับรองให้ใช้กับ media; เลขทุกตัวต้องตรง data `.tres`
- `docs/STORY.md` — ต้นฉบับ lore ไทยอื่น (อ้างอิงใน title menu)
- `docs/PLAYER_MANUAL_3D.md` — คู่มือผู้เล่นฉบับ 3D; `docs/PLAYTEST_PLAN.md` / `docs/RELEASE_CHECKLIST.md` มีหัวข้อ 3D แยกไว้ในไฟล์เดียวกัน
- (2026-11-05 รวมเอกสาร: `HANDOFF.md` → README, `ART_HANDOFF.md` → ART_DIRECTION, `TD2_ASSET_PLAN.md` → GDD_3DTD — ลดจาก 15 เหลือ 12 ไฟล์)

## 3) ตำแหน่งสำคัญในโค้ด (เตรียมอ่านไฟล์ตามนี้)

### projects/last-light-3d (ตัวหลัก)

```
  data/
  enemies/{drifter,skitter,dasher,warden}.tres      # TDEnemyDefinition
  towers/{field_turret,sonic_resonator,tangle_emitter,arc_cannon}.tres   # TDTowerDefinition
  waves/wave_01..08.tres                             # TDWaveDefinition (composition, spawn_interval, health_bonus)
scripts/
  actors/td_enemy.gd       # waypoint walker + slow_factor (reset ทุก physics frame by run)
  actors/td_tower.gd       # first-targeting fire loop; level/can_upgrade/apply_upgrade; MAX_LEVEL=2
  actors/td_projectile.gd  # homing + optional splash (สร้างโดย TDTower._fire, set fields ก่อน add_child)
  gameplay/td_run.gd       # orchestrator: build world, waves via .tres, slot picking, place/upgrade/sell
  data/*.gd                # Resource classes (มีมาตรฐานบังคับให้เป็น typed class)
  systems/run_metrics.gd   # ระบบเก็บ JSON ที่ run ทุกรอบ (schema 1)
  systems/td_settings_store.gd  # autoload "TDSettings": settings.cfg + AudioServer + ui_font_size
  systems/td_session_snapshot.gd # flash save รอบกลางคัน → user://session_snapshot.json (เทสต์ phase6)
  systems/profile_repository.gd # user://profile.json (schema v3, progression ไม่ใช่ settings)
  ui/td_hud.gd             # HUD ครบ + pause menu + settings overlay; รับ Esc แทน td_run
  ui/td_settings_panel.gd  # panel settings ใช้ร่วม title/pause (ปุ่มเสียง + accessibility)
  ui/title_menu.gd         # หน้า main menu (เริ่มภารกิจ, วิธีเล่น, เรื่องราว, ตั้งค่า, ออก)
scenes/
  gameplay/run.tscn        # เส้นเริ่มเดียวที่ map to td_run.gd
  ui/title.tscn            # หน้าแรก (main_scene ใน project.godot)
tests/
  phase1_3d_smoke.gd       # SceneTree test: boot, placement, wave tick, kill bounty, leak, defeat overlay
  phase2_td_data_title_test.gd  # .tres sanity, upgrade/sell accounting, title menu flow
  phase3_settings_test.gd  # settings store + panel, large text, pause settings + Esc order
  dev_title_selfshot.gd    # in-engine screenshot (safe visual check, no desktop capture)
assets/brand/logo_emblem.svg
```

ไอเดียหลักที่ควรรักษาไว้ตอนแก้:
- **td_run เป็น owner ของ "แผนการรบ"** — ป้อมกับศัตรูไม่คุยกันเอง (tower ค้นหาเป้าจาก group "td_enemies"; enemy ไม่รู้จัก tower)
- **legacy slot state** ยังมี parallel arrays เพื่อ compatibility ของ test เดิม แต่การเล่นจริงใช้ `_free_towers` / `_free_tower_positions` และวางบนพื้นได้อิสระ
- ป้อมเก็บระดับอัปเกรดในตัว (`level`) แต่ **ราคาและคูณของอัปเกรดมาจาก TDTowerDefinition** ทุกสตร้าง
- slow/electric effect คำนวณที่ run ทุกเฟรม: รีเซ็ต `slow_factor = 1.0` ก่อน แล้ววนป้อม Tangle ทั้ง slot และ free placement

### projects/last-light (2D — ไม่ต้องสนใจมาก แต่มีเงื่อนไข)

ถ้าจัด worktree เพิ่มแล้วแตะ metrics ให้รู้ว่าไฟล์ profile เก็บที่ `user://phase3_profile_test.json` ฯลฯ
ส่วนที่แตะได้เท่านั้น: `scripts/systems/run_metrics.gd`, `tests/phase6_metrics_test.gd`
ระบบ build/test: `scripts/dev.ps1` (check/run/import), `scripts/test.ps1`

## 4) สถานะเฟสปัจจุบันและไปต่อทางไหน

**TD-0 ✅** (metrics) → **TD-1 ✅** (เสร็จสิ้นพร้อม verify ผ่านอัตโนมัติ) → **TD-2 ✅ (Implementation assets & wiring)**

- **TD-2 Assets:** ผลิตโมเดล Low-poly .glb ด้วย Blender 5.2 สำหรับป้อม 4 ตัว, ศัตรู 4 ตัว, Shelter, ต้นไม้, บ้านร้าง และ roadside props; ผูก `model_scene` เข้ากับ resources แล้ว
- **Pause Menu:** ระบบ Esc toggle pause, resume, restart, return to title menu พร้อมใช้งาน
- **Settings Menu (2026-11-04):** Autoload `TDSettings` (`scripts/systems/td_settings_store.gd` → `user://settings.cfg`, แพตเทิร์นเดียวกับ 2D) + panel ใช้ร่วม `scripts/ui/td_settings_panel.gd` ใน title menu และ pause menu — volume master/sfx/music (dB), reduce flashes/motion, large text (rescale สดทันที)
- **Audio Buses & SFX (2026-11-04):** bus layout `assets/audio/audio_bus_layout.tres` (Master/Music/SFX/UI) + procedural SFX 11 ไฟล์จาก `scripts/generate_sfx_3d.py` + `TDAudioDirector` (`scripts/systems/td_audio_director.gd`) ต่อรอบ — เสียงยิงป้อม 3 ชนิดแยก voice, วาง/อัปเกรด/ขาย, wave_horn, hit/leak/breach, ambient; sliders ของ settings คุมเสียงได้ชุดนี้ทันที (bus SFX/Music จึงไม่ต้อง guard แล้ว)
- **3D VFX & Screen Juice (2026-11-04):** ระบบ `TDCombatEffect` (`scripts/actors/td_combat_effect.gd`) จัดการวงแหวนแสง procedural + sparks (hit, death, placed, upgrade, sold, leak, wave, muzzle) พร้อม camera trauma shake และ HUD leak flash overlay (`flash_leak()`); ทุกเอฟเฟกต์เคารพ `reduce_flashes` และ `reduce_motion` จาก `TDSettings`
- **Weapon/Environment pass (2026-11-04):** Field Turret ใช้ laser, Sonic ใช้ rocket, Tangle ใช้ electric slow feedback, Arc Cannon เป็น tower ชนิดที่ 4; เพิ่ม multi-waypoint road, Shelter Core crystal, trees/houses/roadside props และซ่อน fixed slot visuals
- **Localization ไทย/อังกฤษ (2026-11-07):** `assets/localization/translations.csv` (keys,en,th ตามฉบับ 2D) + เลือกภาษาได้จากแผงตั้งค่า (OptionButton) — เปลี่ยนภาษามีผล **ทันที** ที่เมนู/HUD/แผงตั้งค่าที่เปิดอยู่ผ่าน signal `localization/locale`; ค่าบันทึกใน settings.cfg section `localization` **ค่าเริ่มต้น `th`**; TDSettingsStore.get_locale()/set_locale() + fallback stray→th; ข้อความ user-facing ใหม่ห้าม hardcode — ต้อง `tr(KEY)` + เพิ่ม key ใน CSV; เทสต์ phase7
- **Save/Progression Linkage:** ระบบบันทึกและอ่าน ProfileRepository (`user://profile.json`) เชื่อมต่อเข้ากับ `td_run.gd` เรียบร้อยแล้ว (Integrity ได้รับโบนัสตาม Barricade Level, เมื่อจบรอบบันทึกสถิติและแจก Salvage)

### ข้อควรรู้เพิ่มจากงาน 2026-11-04
- Esc ไปอยู่ที่ HUD (`td_hud.gd`, PROCESS_MODE_ALWAYS) — td_run ตัดคีย์ Esc ออกแล้ว; ลำดับการทำงาน: ปิด settings → toggle pause → resume ไล่ลำดับเลเยอร์
- Settings เข้าถึงเสมอผ่าน `get_node("/root/TDSettings") as TDSettingsStore` เท่านั้น — ห้ามเรียกชื่อ autoload ตรง ๆ (ไม่ผ่าน `--check-only`)
- UI ที่มี overlay กึ่งกลาง: ห้ามวาง ColorRect ฉากหลังมืดใน CenterContainer (ถูกย่อเหลือ min size) — ตัวแบบที่ถูกคือ Control host เต็มจอ + bg ลูกแยก + CenterContainer ครอบเฉพาะกล่อง

### งานที่รับต่อได้ทันที (สำหรับ Agent ถัดไป)

1. **Playtest มนุษย์:** ✅ 2026-11-06 — ผู้เล่นใหม่วางป้อมแรก 5 วิ (< 25 วิ) และอธิบาย leak ได้; เกณฑ์จบ TD-2 ผ่านแล้ว
2. **Barricade purchase flow:** ✅ 2026-11-06 — ปุ่มซื้อใน footer ของ title menu (ราคาตามแพตเทิร์น 2D: 30/70, cap Lv2); ผลคือ `integrity = START_INTEGRITY + level×2` ตอน run boot; แก้ deviation ที่ `BARRICADE_COSTS` ใน `title_menu.gd`
3. **Wave pacing data pass:** ✅ 2026-11-06 — ขยายคลื่น 4/5/6/8 (+36% ตัวร่างรวม) + health_bonus คลื่น 8 → 1.2 อ้าง metrics 2 รัน (ชนะ 10/10 ไม่มี leak, เงินเหลือ 660/1130, ไม่เคยอัปเกรด); รอบถัดไปต้องเทียบ metrics ใหม่ว่า leak/upgrade date เริ่มเกิด

### ข้อควรรู้เพิ่มจากงาน 2026-11-05
- Flash save อยู่ที่ `user://session_snapshot.json` (schema 1) — ระบบจะ **ไม่ทับ snapshot ที่มีอยู่** เมื่อ run ใหม่ยังไม่มีความคืบหน้า (`_has_run_progress()`); ปิดหน้าต่างกลางคลื่นจะถอยไป replay คลื่นที่กำลังเล่น (`wave_number - 1`) ไม่มีเงินลงทุนป้อมหาย
- Dasher dash cycle ถูกกั้นด้วยเทสต์ว่าความเร็วเฉลี่ยรวมของรอบเท่า `speed` เดิม — ห้ามแก้ค่าใน `dasher.tres` ให้เฉลี่ยไม่เท่าเดิมเว้นแต่มี playtest มาอ้าง
- `play_sfx(key, pitch_jitter, base_pitch)` มี pitch override สำหรับเหตุการณ์พิเศษ

### ข้อควรรู้เพิ่มจากงาน 2026-11-07
- **Localization:** UI ทุกสตริงผู้ใช้อ่าน ต้องผ่าน `tr(KEY)` — keys อยู่ใน `projects/last-light-3d/assets/localization/translations.csv` (เพิ่ม key ใหม่แล้วต้องรัน `dev-3d.ps1 -Action import` ให้ .translation คอมไพล์); ปุ่มเลือกภาษาใน `td_settings_panel.gd`; locale ไป section `localization/locale` ของ settings.cfg (ค่าเริ่มต้น `th`); เทสต์ phase7 รันผ่าน store ด้วย TEST_PATH แยกจากไฟล์จริง
- HUD เก็บค่าแสดงล่าสุดไว้ (`_status_*`, `_enemies_count`, `_preview_text`, `_result_*`) และ registry `_locale_texts` — ถ้าเพิ่ม UI ไดนามิกใหม่ใน HUD ให้ follow แพตเทิร์นเดียวกันจึงจะ locale-switch ได้ทันที
- **เทสต์ผูกกับภาษา:** `phase7_localization_test.gd` เทสต์ด้วย locale อังกฤษ/ไทยสลับ — ถ้าเบอร์แก้สตริง CSV ให้เทสต์ตาม; ค่าเริ่มต้น locale = th ตามกติกา "ภาษาเป็นไทยก่อน" (ตัดสินแล้ว)

### ข้อควรรู้เพิ่มจากงาน 2026-11-06
- **เส้นทาง (PATH_POINTS) เป็น zigzag ตั้งฉากทั้งหมด** (spawn (-11,7) → shelter (8,-7), ระยะรวม ~49 ม. = ยาวขึ้น ~10% จากเดิม) — แก้ layout อย่าลืม: จานมุมอัตโนมัติผ่าน `_corner_patch_radius` (มุมฉาก r 1.86) และ curb หุบปลายผ่าน `_corner_inset`/`PATH_POINTS.size() - 2` ใน `_add_path_detail`; ถ้าเพิ่ม/ลดจุด ให้เช็ก SLOTS 12 จุด + เสาไฟ/กั้นถนนที่ hardcode อยู่ใน `_paint_path_shelter_and_slots()` ว่าไม่ตกกลางถนน
- จานมุม/แถบถนน **แชร์วัสดุเดียวกัน** (`_road_material_a/b` สร้างใน `_paint_path_shelter_and_slots()`) — ถ้าเปลี่ยนสีถนนแก้ที่นี่ที่เดียว
- กฎกล้อง scatter: `_open_ground` รับ `z_min/z_max` แล้ว — tall props (ต้นไม้ z ≤ 8.5, บ้าน z ≤ 6.0) ห้ามตกโซนใกล้กล้อง (4,17,15) ไม่งั้นกลายเป็นก้อนยักษ์กลางจอ; selfshot ตรวจด้วย `tests/dev_run_selfshot.gd`
- **สถิติป้อมต่อระดับ (งาน 2026-11-06):** `TDTowerDefinition` ใช้ arrays `level_damage/level_fire_interval/level_range/level_splash/level_slow` (index 0..2) เป็น authoritative — **factor fields ถูกลบไปแล้ว** (สคริปต์ที่อ้าง `upgrade_damage_factor` ฯลฯ จะพัง); base fields เป็น mirror ของ level 0 ไว้ให้เทสต์เดิม; ทุกเส้นทางอัปเกรดต้องผ่าน `TDRun._apply_upgrade_level()` ที่เดียว
- **Wave chaining:** `start_wave()` เรียกได้กลางคลื่น — ผสม spawn queue พร้อม meta ต่อ entry (`_spawn_queue_meta`); โบนัสจ่ายต่อคลื่นผ่าน `_waves_in_flight`/`_pending_wave_numbers`; HUD `set_combat_state(is_combat, can_chain)` — caller ที่ต่อ playtest/wave logic ใหม่ต้องคุมสองอาร์กให้ตรง
- **Title menu ปรับปรุง (2026-11-06):** gradient + ปุ่ม StyleBoxFlat (`_menu_style`) + footer (`_build_footer`) — คอลัมน์กึ่งกลางยืดถึง offset_bottom 316 กับฟุตเตอร์ที่ -76 อย่าทับกัน; ภาพใน `docs/marketing/` (menu_title, showcase_battle) จับจาก in-engine capture ต้อง re-capture เมื่อเมนู/ฉากเปลี่ยน
- ข้อควรรู้เดิมจากงาน 2026-11-05 และ 2026-11-04 ทั้งหมดยังใช้อยู่

## 5) กติกาสากลของ repo (อ่าน AGENTS.md แล้วสรุปเพิ่มที่นี้)

- Godot 4.7.2, tabs, static typing, UI ในโค้ด, balance ใน .tres, SceneTree tests, dev log entry ต่องาน
- **ห้าม capture หน้าจอเดสก์ท็อปของผู้ใช้** (มีหน้าต่างส่วนตัวเปิดตลอด) — ใช้ in-engine capture ตาม `tests/dev_title_selfshot.gd`
- **ห้าม commit** `.godot/`, ภาพ selfshot, log ชั่วคราว; ห้ามแก้ balance ไม่มี metrics อ้างอิง
- class_name ใหม่ → รัน `.\scripts\dev-3d.ps1 -Action import` ก่อนรันเทสต์ มิฉะนั้นจะเจอ "Could not find type X"
- ความเสี่ยงที่เคยเจอ: เขียนไฟล์ยาวเร็วแล้วมี text รีเร็วถอยเบี้ยว (garbled Thai) — เขียนครั้งเดียวสมบูรณ์ แล้ว grep ตรวจหาอักษรแปลกปลอมเสมอ, รัน check ทันที
- Commit ให้มีหัวข้อตามงานจริง (`feat:`, `docs:`, `test:`, `fix:`), push ไป `origin/main`
- เครื่องผู้ใช้: Windows, PowerShell, Godot 4.7.2 ใน PATH; เทสต์รันทุกรอบผ่านสคริปต์ (ไม่ใช่ `godot` เรียกเอง)

## 6) สิ่งที่ตัดสินใจแล้ว / ตัดสินไม่ได้

**ตัดสินแล้ว (ปิดปากทุกกรณี)**
- ป้อมวันจะเป็นทหารตัวเกม (hero) ไม่มีส่วนคุม
- แบรนด์ยังใช้ IP หลัก: Shelter 09, ริน, มีรา, Hollows, Rift Warden, Parts/Salvage
- ปล่อยโปรเจกต์ 2D ไว้เป็น reference ตลอดชีวิตหน้างาน (ไม่ลบ)
- ภาษาเป็นไทยก่อน (title menu + story + marketing เป็นไทยสำเร็จ), อังกฤษแทรกเฉพาะคำศัพท์ IP

**ยังเปิดรับข้อเสนอ (อย่าตัดสินเดี่ยว ๆ ถ้ามีเหตุผลดี)**
- UI theme แบบแบรนด์ (กำลัง graybox), resolution/scaling เพิ่ม
- ราคา/ตัวเลข balance ทุกช่อง — ขอ metrics ก่อนเสมอ
- การเลือก API เชื่อม leaderboard ปลายทาง (ยังไม่คาดการในเฟสนี้)
