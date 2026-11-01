# LAST LIGHT: สัญญาณสุดท้าย

LAST LIGHT เป็นเกม 2D แนว survival defense: ผู้รอดชีวิตเดินเท้าป้องกัน Shelter จากฝูง Hollows เลื่อนซ้าย–ขวา ยิงอัตโนมัติ อัปเกรดปืนระหว่างคลื่น และใช้ Salvage เสริม Barricade ระหว่างรอบ

> สถานะ: Windows prototype พร้อมให้ playtest core loop แนวเอาตัวรอดเดินเท้า; Android ถูกพักไว้จนกว่า gameplay จะผ่าน playtest

## เริ่มอ่าน

1. [START_HERE.md](./START_HERE.md) — สถานะโปรเจกต์และทางเริ่มงาน
2. [GDD.md](./docs/GDD.md) — วิสัยทัศน์และกติกาเกม
3. [STORY.md](./docs/STORY.md) — โลก ตัวละคร และเส้นเรื่อง
4. [ART_DIRECTION.md](./docs/ART_DIRECTION.md) — ภาพ สี และ pipeline
5. [ART_HANDOFF.md](./docs/ART_HANDOFF.md) — ขอบเขตและ prompt ส่งต่องานภาพให้ Codex
6. [ARCHITECTURE.md](./docs/ARCHITECTURE.md) — โครงระบบและโฟลเดอร์
7. [ROADMAP.md](./docs/ROADMAP.md) — ลำดับงานและเกณฑ์ผ่าน
8. [PLAYER_MANUAL.md](./docs/PLAYER_MANUAL.md) — คู่มือผู้เล่น
9. [HANDOFF.md](./docs/HANDOFF.md) — ย้ายเครื่องและตั้งค่าสภาพแวดล้อม
10. [PLAYTEST_PLAN.md](./docs/PLAYTEST_PLAN.md) — เช็กลิสต์ทดสอบด้วยตนเอง
11. [RELEASE_CHECKLIST.md](./docs/RELEASE_CHECKLIST.md) — build/export และ release gates

## เทคโนโลยีและขอบเขต

- **Engine:** Godot 4.7.2 stable; ใช้ 2D และ GL Compatibility
- **เกม:** เล่นคนเดียว PvE, หน้าจอแนวตั้ง 9:16
- **แพลตฟอร์มปัจจุบัน:** Windows; Android development ถูกพักไว้
- **Path ของ Godot project:** `projects\last-light\`
- **Asset workflow:** Pixel-art MCP สำหรับงาน pixel art; Godot MCP สำหรับตรวจ scene/รันเกม; Blender MCP เป็นทางเลือกสำหรับภาพฉากหรือ reference
- สร้าง sprite, music และ SFX ต้นฉบับด้วย Python standard library; ฟอนต์ Noto Sans Thai ใช้ SIL Open Font License

## เปิดเกม

เปิด `projects\last-light\project.godot` ด้วย Godot 4.7.2 หรือจาก PowerShell ที่ root ของ repository:

```powershell
.\scripts\dev.ps1 -Action run
```

สคริปต์ค้นหา Godot จาก `GODOT_PATH` ก่อน แล้วจึงค้นหา `godot` ใน `PATH` จึงไม่ยึดกับตำแหน่งติดตั้งของเครื่องนี้

รันทดสอบอัตโนมัติและสร้าง Windows build:

```powershell
.\scripts\test.ps1
.\scripts\export.ps1 -Platform Windows -Mode release
```

Android export presets ยังอยู่ใน repository แต่ไม่ใช่ขั้นตอนปัจจุบัน; โฟกัสการทดสอบ Windows ก่อน

## ข้อเสนอการพัฒนาขั้นถัดไป

ลำดับถัดไปคือทดสอบ survival-defense loop บน Windows ตาม [PLAYTEST_PLAN.md](./docs/PLAYTEST_PLAN.md) แล้วจึงปรับความสนุก/สมดุลก่อนเพิ่ม content หรือเริ่ม Android
