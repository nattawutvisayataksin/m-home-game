# LAST LIGHT — AI Handoff Document

อัปเดต: 2026-11-05 — หลัง flash save / dasher / HUD clarity pass
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
- **Save/Progression Linkage:** ระบบบันทึกและอ่าน ProfileRepository (`user://profile.json`) เชื่อมต่อเข้ากับ `td_run.gd` เรียบร้อยแล้ว (Integrity ได้รับโบนัสตาม Barricade Level, เมื่อจบรอบบันทึกสถิติและแจก Salvage)

### ข้อควรรู้เพิ่มจากงาน 2026-11-04
- Esc ไปอยู่ที่ HUD (`td_hud.gd`, PROCESS_MODE_ALWAYS) — td_run ตัดคีย์ Esc ออกแล้ว; ลำดับการทำงาน: ปิด settings → toggle pause → resume ไล่ลำดับเลเยอร์
- Settings เข้าถึงเสมอผ่าน `get_node("/root/TDSettings") as TDSettingsStore` เท่านั้น — ห้ามเรียกชื่อ autoload ตรง ๆ (ไม่ผ่าน `--check-only`)
- UI ที่มี overlay กึ่งกลาง: ห้ามวาง ColorRect ฉากหลังมืดใน CenterContainer (ถูกย่อเหลือ min size) — ตัวแบบที่ถูกคือ Control host เต็มจอ + bg ลูกแยก + CenterContainer ครอบเฉพาะกล่อง

### งานที่รับต่อได้ทันที (สำหรับ Agent ถัดไป)

1. **Playtest มนุษย์:** ต้องมีผู้เล่นจริง — เงื่อนไขจบ TD-2 คือผู้เล่นใหม่วางป้อมแรก < 25 วินาที และอธิบาย leak ได้ (แผนทดสอบใน `PLAYTEST_PLAN.md` หัวข้อ 3D)
2. **Barricade purchase flow:** profile schema รองรับ `barricade_level` (สูงสุด 2, +2 Integrity/level) แต่ยังไม่มีปุ่มซื้อด้วย Salvage ใน title menu — ทดสอบวางปุ่มเพิ่มใน title_menu.gd ตามแพตเทิร์น 2D
3. **Wave pacing data pass:** หลัง playtest มนุษย์ รันเล่นจริงเพื่อเก็บ metrics ใน `user://metrics/` และปรับ wave `.tres` เฉพาะเมื่อมีข้อมูลอ้างอิง (ปัจจุบันเตะกติกา "ห้ามแก balance ไม่มี metrics")

### ข้อควรรู้เพิ่มจากงาน 2026-11-05
- Flash save อยู่ที่ `user://session_snapshot.json` (schema 1) — ระบบจะ **ไม่ทับ snapshot ที่มีอยู่** เมื่อ run ใหม่ยังไม่มีความคืบหน้า (`_has_run_progress()`); ปิดหน้าต่างกลางคลื่นจะถอยไป replay คลื่นที่กำลังเล่น (`wave_number - 1`) ไม่มีเงินลงทุนป้อมหาย
- Dasher dash cycle ถูกกั้นด้วยเทสต์ว่าความเร็วเฉลี่ยรวมของรอบเท่า `speed` เดิม — ห้ามแก้ค่าใน `dasher.tres` ให้เฉลี่ยไม่เท่าเดิมเว้นแต่มี playtest มาอ้าง
- `play_sfx(key, pitch_jitter, base_pitch)` มี pitch override สำหรับเหตุการณ์พิเศษ
- ข้อควรรู้เดิมจากงาน 2026-11-04 ทั้งหมดยังใช้อยู่

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
