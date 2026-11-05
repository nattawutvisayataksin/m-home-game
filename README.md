# LAST LIGHT: สัญญาณสุดท้าย

LAST LIGHT เป็นเกม 3D Tower Defense หลัก: ผู้เล่นวางป้อมป้องกัน Shelter 09 จากฝูง Hollows ที่เดินตามเลน, จัดการ wave, อัปเกรด/ขายป้อม, และเก็บ Salvage สำหรับ progression

> สถานะ: เกมหลัก 3D Tower Defense (`projects/last-light-3d`) อยู่ใน TD-2 implementation-ready state; โปรเจกต์ 2D (`projects/last-light`) ถูกเก็บไว้เป็น playable reference เท่านั้น ห้ามแตะนอกจากระบบ metrics

## เริ่มอ่าน

1. [START_HERE.md](./START_HERE.md) — สถานะโปรเจกต์และทางเริ่มงาน
2. [docs/GDD_3DTD.md](./docs/GDD_3DTD.md) — กติกาและ design หลักของเกม 3D
3. [docs/GDD.md](./docs/GDD.md) — baseline 2D reference ที่แช่แข็ง (ใช้สำหรับ lore/progression/history)
4. [docs/STORY.md](./docs/STORY.md) — โลก ตัวละคร และเส้นเรื่อง
5. [docs/ART_DIRECTION.md](./docs/ART_DIRECTION.md) — ภาพ สี และ pipeline
6. [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — โครงระบบและโฟลเดอร์
7. [docs/ROADMAP.md](./docs/ROADMAP.md) — ลำดับงานและเกณฑ์ผ่าน
8. [docs/PLAYER_MANUAL_3D.md](./docs/PLAYER_MANUAL_3D.md) — คู่มือผู้เล่น 3D
9. [docs/PLAYER_MANUAL.md](./docs/PLAYER_MANUAL.md) — คู่มือผู้เล่น 2D reference
10. [docs/AI_HANDOFF.md](./docs/AI_HANDOFF.md) — ข้อตกลงและตำแหน่งงานต่อเนื่องสำหรับ AI
11. [docs/PLAYTEST_PLAN.md](./docs/PLAYTEST_PLAN.md) — เช็กลิสต์ทดสอบด้วยตนเอง
12. [docs/RELEASE_CHECKLIST.md](./docs/RELEASE_CHECKLIST.md) — build/export และ release gates

## เทคโนโลยีและขอบเขต

- **Engine:** Godot 4.7.2 stable; ใช้ 3D + GL Compatibility สำหรับเกมหลัก, 2D reference เก็บไว้แยก
- **เกมหลัก:** 3D tower defense, วางป้อมล้วน, มุมมอง isometric fixed
- **แพลตฟอร์มปัจจุบัน:** Windows; Android development ถูกพักไว้
- **Path ของ Godot project:** `projects\last-light-3d\` (เกมหลัก), `projects\last-light\` (reference only)
- **Asset workflow:** Blender low-poly models + Godot import; procedural SFX generation ด้วย Python; ฟอนต์ Noto Sans Thai ใช้ SIL Open Font License

## เปิดเกม

เปิด `projects\last-light-3d\project.godot` หรือจาก PowerShell ที่ root ของ repository:

```powershell
.\scripts\dev-3d.ps1 -Action run
```

สคริปต์ค้นหา Godot จาก `GODOT_PATH` ก่อน แล้วจึงค้นหา `godot` ใน `PATH` จึงไม่ยึดกับตำแหน่งติดตั้งของเครื่องนี้

เกม 2D reference เปิดด้วย:

```powershell
.\scripts\dev.ps1 -Action run
```

รันทดสอบอัตโนมัติและสร้าง build:

```powershell
.\scripts\test-3d.ps1
.\scripts\export.ps1 -Platform Windows -Mode release
```

Android export presets ยังอยู่ใน repository แต่ไม่ใช่ขั้นตอนปัจจุบัน; โฟกัสการทดสอบ Windows ก่อน

## ข้อเสนอการพัฒนาขั้นถัดไป

จาก Game Director (2026-11-03): เปลี่ยนทิศทางเป็น **3D Tower Defense** — คง IP เดิม, เริ่มโปรเจกต์ใหม่ `projects\last-light-3d\` ตาม [docs/GDD_3DTD.md](./docs/GDD_3DTD.md) และ [docs/ROADMAP.md](./docs/ROADMAP.md) (หัวข้อ "3D Tower Defense pivot") ส่วน 2D reference ถูกเก็บไว้เพื่อ baseline, playtest metrics, และการอ้างอิง lore
