# AGENTS.md — คำแนะนำสำหรับ AI coding agents

คู่มือฉบับย่อสำหรับอะไรก็ตามที่มาช่วยแก้โค้ดใน repo นี้ (Codex / Copilot / Antigravity / opencode)
ฉบับเต็ม: `START_HERE.md` + `docs/AI_HANDOFF.md` | เอกสาร design เด็ดขาด: `docs/GDD.md`, `docs/GDD_3DTD.md`

## Repo map (สั้น ๆ)

```
docs/            GDD, ROADMAP, NIGHTLY_DEV_LOG, MARKETING, AI_HANDOFF, STORY
projects/
  last-light/      เกม 2D survival-defense (Godot 4.7) — playable reference + playtest metrics
  last-light-3d/   เกม 3D tower defense (Godot 4.7, GL Compatibility) — เกมหลักที่กำลังพัฒนาต่อ
scripts/         dev.ps1 / test.ps1 (2D), dev-3d.ps1 / test-3d.ps1 (3D)
```

## คำสั่งที่ใช้ได้

| ทำ | คำสั่ง |
| --- | --- |
| ตรวจ parse (2D / 3D) | `.\scripts\dev.ps1 -Action check` / `.\scripts\dev-3d.ps1 -Action check` |
| รันเกม (2D / 3D) | `.\scripts\dev.ps1 -Action run` / `.\scripts\dev-3d.ps1 -Action run` |
| import scan (3D) | `.\scripts\dev-3d.ps1 -Action import` — ต้องรันทุกครั้งหลังเพิ่ม `class_name` ใหม่ (global class cache) |
| เทสต์ทั้งหมด (2D: 6 suites / 3D: 6 suites) | `.\scripts\test.ps1` / `.\scripts\test-3d.ps1` |

Godot 4.7.2 ต้องอยู่ใน PATH หรือตั้ง env `GODOT_PATH` ไว้ก่อน มิฉะนั้นสคริปต์จะ throw

## Coding conventions (ต้องปฏิบัติทุกข้อ)

1. **Tab indent** ทุกไฟล์ `.gd` — ถ้าไฟล์สังเกตุได้ว่าใช้อย่างอื่น ให้สอดคล้องกับไฟล์นั้นแล้วบอกใน commit message
2. **Static typing**: ประกาศ type ของพารามิเตอร์และ return ทุกฟังก์ชัน; `const` ของข้อมูลก้อนใหญ่ระบุ type ให้ชัด
3. **ตัวเลข balance ต้องอยู่ใน data `.tres`** — `projects/last-light-3d/data/{enemies,towers,waves}/` ผ่าน class ใน `scripts/data/` (`TDEnemyDefinition` / `TDTowerDefinition` / `TDWaveDefinition`); สคริปต์ gameplay ห้าม hardcode
4. **เทสต์เป็น SceneTree script** ที่ `tests/` — รันง่าย, พิมพ์ `PHASE ... PASSED`, exit nonzero เมื่อพัง; ห้ามเขียนเทสที่ต้อง await realtime
5. **UI สร้างในโค้ด** (ไม่แตะ .tscn เยอะ) — ผ่าน container building เหมือน `td_hud.gd` / `title_menu.gd`
6. **ห้าม commit** โฟลเดอร์ `.godot/`, ภาพ selfshot ตรวจสอบ, หรือไฟล์ screenshot ชั่วคราว
7. **dev log**: งานที่เปลี่ยน behavior ของเกมต้องเขียน entry ที่ `docs/NIGHTLY_DEV_LOG.md` (ดู format ในไฟล์, ภาษาไทยก็ได้)

## Guardrails / scope rules

- **ห้ามแตะตัวเลข balance ใน data .tres** โดยไม่มี playtest metrics อ้างอิง — ปรับด้วยข้อมูล ไม่ใช่ความรู้สึก
- **โปรเจกต์ 2D (`projects/last-light/`) อย่าแตะ** นอกจากระบบ metrics (`scripts/systems/run_metrics.gd`, `tests/phase6_metrics_test.gd`) — มันคือ reference build ที่เก็บสถิติอยู่
- **ห้ามเพิ่ม hero/active player unit** ในโปรเจกต์ 3D — เกมนี้ตัวผู้เล่นวางป้อมล้วนตาม GDD_3DTD
- งานเรื่อง origin / IP: ใช้เรื่องจาก `docs/STORY.md` (Shelter 09, ริน, มีรา, Hollows, Rift Warden) — อย่าสร้างตัวละคร/ชื่อใหม่
- Visual check เฉพาะสิ่งที่ปลอดภัย: ใช้ in-engine capture (`root.get_texture().get_image()`) ผ่าน `tests/dev_title_selfshot.gd` เป็นแบบอย่าง — **ห้าม capture หน้าจอเดสก์ท็อปโดยรอบ** ผู้ใช้งานเครื่องนี้มีหน้าต่างส่วนตัวเปิดอยู่

## Known TODO / งานค้าง (เลือกจากนี้ได้เลย)

1. **TD-1 exit:** verify `.tres` ครบถ้วนผ่านการเล่นจริง; เทสต์ phase8 กลุ่ม coverage คลื่นต่อคลื่น (ผ่านแล้วเมื่อ 2026-11-09)
2. **Iteration:** ✅ 2026-11-09 — เป้า "leak > 0 ในคลื่น 5–7, upgrade ถูกใช้" ถึงแล้วด้วย metrics sim รอบใหม่: map 1 ใช้ชุด `data/waves/map_01/` (per-map wave override ผ่าน `TDMapLayout.wave_paths`), map 2 คง default ชนะ 11/12; การเทียบรายหน้าดู NIGHTLY_DEV_LOG 2026-11-09 — หลังนี้แตะ wave อีกต้องมี playtest มนุษย์รอบใหม่เป็นข้อมูล
3. **TD-2:** Blender low-poly assets ✅ (ผ่าน Blender AI Bridge; asset suite ครบ ป้อม/ศัตรู/props)
4. Settings (volume/accessibility) ✅ 2026-11-04; flash save บนโปรเจกต์ 3D ✅ 2026-11-05; **Localization ไทย/อังกฤษ ✅ 2026-11-07** (translations.csv + เลือกภาษาใน settings, เปลี่ยนสดทุกหน้า, เทสต์ phase7)
5. **Playtest มนุษย์ TD-2** ✅ 2026-11-06 — เกณฑ์ผ่าน (วางป้อมแรก 5 วิ < 25 วิ, อธิบาย leak ได้) ครั้งแรก; รอรอบใหม่บน wave set 2026-11-09 + Splitter
6. **งานเสนอชุดถัดไป (ต้องได้ Game Director รับก่อน):** targeting mode ต่อป้อม (GDD §5 "หลัง vertical slice"), โหมดภาษาอังกฤษต่อยอดใน marketing copy, **Hero prototype รอตัดสิน** (dev-gated คีย์ H — อนุมัติ/ตัดทิ้ง ดู GDD_3DTD §11), leak คลื่น 1 บน map 2 รอผู้กำกับเลือกแนวทาง (ช่องวางต่อ coverage / wave ของ map 2)
