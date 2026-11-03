# LAST LIGHT — AI Handoff Document

อัปเดต: 2026-11-03
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

- `docs/GDD_3DTD.md` — design ของเกม 3D (ป้อม 3 / ศัตรู 4 / economy / camera / inputs)
- `docs/GDD_2D_Survival.md` — ถูกอ้างถึงเป็นที่มาของ IP + lore + progression ของ 2D
- `docs/ROADMAP.md` — เฟส TD-0/TD-1/TD-2 + เงื่อนไขจบของแต่ละเฟส
- `docs/NIGHTLY_DEV_LOG.md` — ประวัติการตั้งใจตัดสินแต่ละเซสชัน (มีประวัติ context แบบตามเวลา)
- `docs/MARKETING.md` — copy ที่รับรองให้ใช้กับ media; เลขทุกตัวต้องตรง data `.tres`
- `docs/STORY.md` — ต้นฉบับ lore ไทยอื่น (อ้างอิงใน title menu)

## 3) ตำแหน่งสำคัญในโค้ด (เตรียมอ่านไฟล์ตามนี้)

### projects/last-light-3d (ตัวหลัก)

```
data/
  enemies/{drifter,skitter,dasher,warden}.tres      # TDEnemyDefinition
  towers/{field_turret,sonic_resonator,tangle_emitter}.tres   # TDTowerDefinition (upgrade_costs, factors)
  waves/wave_01..08.tres                             # TDWaveDefinition (composition, spawn_interval, health_bonus)
scripts/
  actors/td_enemy.gd       # waypoint walker + slow_factor (reset ทุก physics frame by run)
  actors/td_tower.gd       # first-targeting fire loop; level/can_upgrade/apply_upgrade; MAX_LEVEL=2
  actors/td_projectile.gd  # homing + optional splash (สร้างโดย TDTower._fire, set fields ก่อน add_child)
  gameplay/td_run.gd       # orchestrator: build world, waves via .tres, slot picking, place/upgrade/sell
  data/*.gd                # Resource classes (มีมาตรฐานบังคับให้เป็น typed class)
  systems/run_metrics.gd   # ระบบเก็บ JSON ที่ run ทุกรอบ (schema 1)
  ui/td_hud.gd             # HUD ครบ (แต่งจริงเริ่มจาก label/buttons)
  ui/title_menu.gd         # หน้า main menu (เริ่มภารกิจ, วิธีเล่น, เรื่องราว, ออก)
scenes/
  gameplay/run.tscn        # เส้นเริ่มเดียวที่ map to td_run.gd
  ui/title.tscn            # หน้าแรก (main_scene ใน project.godot)
tests/
  phase1_3d_smoke.gd       # SceneTree test: boot, placement, wave tick, kill bounty, leak, defeat overlay
  phase2_td_data_title_test.gd  # .tres sanity, upgrade/sell accounting, title menu flow
  dev_title_selfshot.gd    # in-engine screenshot (safe visual check, no desktop capture)
assets/brand/logo_emblem.svg
```

ไอเดียหลักที่ควรรักษาไว้ตอนแก้:
- **td_run เป็น owner ของ "แผนการรบ"** — ป้อมกับศัตรูไม่คุยกันเอง (tower ค้นหาเป้าจาก group "td_enemies"; enemy ไม่รู้จัก tower)
- **slot ตามสนาม = state แบบ parallel arrays** (`_slot_towers` / `_slot_disks` / `_slot_occupied` / `_slot_invested`) — index ตรงกับ `SLOTS` เสมอ
- ป้อมเก็บระดับอัปเกรดในตัว (`level`) แต่ **ราคาและคูณของอัปเกรดมาจาก TDTowerDefinition** ทุกสตร้าง
- slow aura คำนวณที่ run ทุกเฟรม: รีเซ็ต `slow_factor = 1.0` ก่อนแล้ววนป้อม Tangle ทาบรัศมี — ไม่ให้ tower จัดการเอง

### projects/last-light (2D — ไม่ต้องสนใจมาก แต่มีเงื่อนไข)

ถ้าจัด worktree เพิ่มแล้วแตะ metrics ให้รู้ว่าไฟล์ profile เก็บที่ `user://phase3_profile_test.json` ฯลฯ
ส่วนที่แตะได้เท่านั้น: `scripts/systems/run_metrics.gd`, `tests/phase6_metrics_test.gd`
ระบบ build/test: `scripts/dev.ps1` (check/run/import), `scripts/test.ps1`

## 4) สถานะเฟสปัจจุบันและไปต่อทางไหน

**TD-0 ✅** (metrics) → **TD-1 ✅** (เสร็จสิ้นพร้อม verify ผ่านอัตโนมัติ) → **TD-2 ✅ (Implementation assets & wiring)**

- **TD-2 Assets:** ผลิตโมเดล Low-poly .glb ครบถ้วน (Towers 3 ตัว, Enemies 4 ตัว, Shelter prop) ด้วย Blender 5.2 และผูก `model_scene` เข้ากับทุก `.tres` ใน `projects/last-light-3d/data/` เรียบร้อยแล้ว
- **Pause Menu:** ระบบ Esc toggle pause, resume, restart, return to title menu พร้อมใช้งาน
- **Save/Progression Linkage:** ระบบบันทึกและอ่าน ProfileRepository (`user://profile.json`) เชื่อมต่อเข้ากับ `td_run.gd` เรียบร้อยแล้ว (Integrity ได้รับโบนัสตาม Barricade Level, เมื่อจบรอบบันทึกสถิติและแจก Salvage)

### งานที่รับต่อได้ทันที (สำหรับ Open Code / Agent ถัดไป)

1. **Wave pacing data pass (Playtest iteration):** ทดลองรันเล่นเกมจริงผ่าน `.\scripts\dev-3d.ps1 -Action run` เพื่อดู visual และความรู้สึกในการเล่นจริง บันทึก feedback เรื่อง pacing/economy และปรับแต่ง `.tres` หากพบความไม่สมดุล
2. **Audio Buses & SFX:** นำระบบเสียง (AudioDirector / audio buses) จาก 2D มาประยุกต์ใส่ใน 3D (เสียงยิงป้อม, เสียงคลื่นกระทบ, เสียง ambient)
3. **3D VFX & Juice:** เพิ่ม visual feedback (flash, impact, projectile trail, boss rift glow) โดยคำนึงถึงตัวเลือก reduce-motion และ reduce-flash ตาม GDD
4. **Settings Menu (Volume / Accessibility):** พัฒนาหน้าตั้งค่าสำหรับเสียงและตัวช่วยการเข้าถึงในหน้า Title Menu และ Pause Menu

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
