# LAST LIGHT: สัญญาณสุดท้าย

เกมยิงเอาตัวรอดแนวตั้งแบบ 2D: ฝูงศัตรูเคลื่อนจากฟากฟ้าลงสู่แนวป้องกัน ผู้เล่นขยับซ้าย–ขวา ยิงต่อเนื่อง และเลือกใช้พลังที่สะสมเพื่อ **อัปเกรดอาวุธ** หรือ **ปล่อยคลื่นป้องกันฉุกเฉิน**

> โปรเจกต์อยู่ในช่วง pre-production: มี GDD, เนื้อเรื่อง, art direction, สถาปัตยกรรม และ Godot project skeleton แล้ว แต่ยังไม่มีระบบเกมหรือ asset สำหรับเล่นจริง

## เริ่มอ่าน

1. [START_HERE.md](./START_HERE.md) — สถานะโปรเจกต์และทางเริ่มงาน
2. [GDD.md](./docs/GDD.md) — วิสัยทัศน์และกติกาเกม
3. [STORY.md](./docs/STORY.md) — โลก ตัวละคร และเส้นเรื่อง
4. [ART_DIRECTION.md](./docs/ART_DIRECTION.md) — ภาพ สี และ pipeline
5. [ARCHITECTURE.md](./docs/ARCHITECTURE.md) — โครงระบบและโฟลเดอร์
6. [ROADMAP.md](./docs/ROADMAP.md) — ลำดับงานและเกณฑ์ผ่าน
7. [PLAYER_MANUAL.md](./docs/PLAYER_MANUAL.md) — คู่มือผู้เล่นฉบับร่าง
8. [HANDOFF.md](./docs/HANDOFF.md) — ย้ายเครื่องและตั้งค่าสภาพแวดล้อม

## เทคโนโลยีและขอบเขต

- **Engine:** Godot 4.7.2 stable; ใช้ 2D และ GL Compatibility
- **เกม:** เล่นคนเดียว PvE, หน้าจอแนวตั้ง 9:16
- **แพลตฟอร์มเป้าหมาย:** Windows และ Android
- **Path ของ Godot project:** `projects\last-light\`
- **Asset workflow:** Pixel-art MCP สำหรับงาน pixel art; Godot MCP สำหรับตรวจ scene/รันเกม; Blender MCP เป็นทางเลือกสำหรับภาพฉากหรือ reference
- ไม่ต้องติดตั้ง addon หรือ dependency เพิ่มในช่วง pre-production

## เปิด project skeleton

เปิด `projects\last-light\project.godot` ด้วย Godot 4.7.x หรือจาก PowerShell ที่ root ของ repository:

```powershell
.\scripts\dev.ps1 -Action run
```

สคริปต์ค้นหา Godot จาก `GODOT_PATH` ก่อน แล้วจึงค้นหา `godot` ใน `PATH` จึงไม่ยึดกับตำแหน่งติดตั้งของเครื่องนี้

## ข้อเสนอการพัฒนาขั้นถัดไป

เริ่มจาก prototype ที่มีผู้เล่นหนึ่งลำ, ศัตรูสามชนิด, กระสุน, แถบป้องกัน, พลังสะสมหนึ่งเกจ และบอสหนึ่งตัว ก่อนเพิ่มเนื้อเรื่อง/อุปกรณ์ถาวร โปรดใช้เกณฑ์วัดใน [ROADMAP.md](./docs/ROADMAP.md) เป็นตัวตัดสิน ไม่เพิ่มระบบใหม่ก่อนที่ core loop จะสนุกและอ่านสถานการณ์ออก
