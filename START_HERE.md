# START HERE — LAST LIGHT

## เป้าหมาย

สร้างเกม 2D vertical survival shooter สำหรับ Windows และ Android ที่เข้าใจได้ในไม่กี่วินาที เล่นหนึ่งรอบได้ในไม่กี่นาที และมีการตัดสินใจเด่นหนึ่งอย่าง: ใช้พลังที่เต็มเกจเพื่อเสริมอาวุธระยะยาว หรือรักษาแนวด้วยคลื่นป้องกันทันที

## สถานะปัจจุบัน

- ✅ ตัดสินใจ engine, ภาพรวม gameplay, แพลตฟอร์ม และผู้เล่นเป้าหมายแล้ว
- ✅ เขียน GDD, story, art direction, architecture, roadmap และคู่มือร่าง
- ✅ สร้าง Godot project skeleton ที่เปิดได้และกำหนด path แบบ relative
- ⏳ ยังไม่ได้สร้าง gameplay, art/audio จริง, Android export preset หรือ build สำหรับแจกจ่าย

## แหล่งข้อมูลหลัก

| เรื่อง | เอกสาร |
|---|---|
| วิสัยทัศน์และกติกาที่เป็นข้อตกลง | [docs/GDD.md](./docs/GDD.md) |
| เรื่องและตัวละคร | [docs/STORY.md](./docs/STORY.md) |
| ภาพและ asset | [docs/ART_DIRECTION.md](./docs/ART_DIRECTION.md) |
| scene, scripts, data และ save | [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) |
| งานเรียงลำดับและ Definition of Done | [docs/ROADMAP.md](./docs/ROADMAP.md) |
| วิธีเล่นและ controls | [docs/PLAYER_MANUAL.md](./docs/PLAYER_MANUAL.md) |
| ตั้งเครื่องอื่น | [docs/HANDOFF.md](./docs/HANDOFF.md) |

เมื่อเอกสารขัดกัน ให้ GDD เป็นแหล่งตัดสินด้าน design, Architecture เป็นแหล่งตัดสินด้าน implementation และบันทึกการเปลี่ยนแปลงที่มีผลต่อ scope ไว้ใน Roadmap

## เริ่มทำงานในเครื่องนี้

```powershell
.\scripts\dev.ps1 -Action check
.\scripts\dev.ps1 -Action run
```

ตรวจ parser/import หลังเพิ่ม resource หรือ scene:

```powershell
.\scripts\dev.ps1 -Action import
.\scripts\dev.ps1 -Action check
```

Godot project อยู่ที่ `projects\last-light\project.godot` เสมอ ส่วน save ของเกมเมื่อมีระบบแล้วต้องอยู่ใน `user://` ไม่เขียนลง `res://` หรือโฟลเดอร์ asset

## แนวทางการทำงาน

1. ทำ prototype core loop ให้ครบก่อนทำ content จำนวนมาก
2. ใช้ InputMap actions และ resource data แทนการผูก gameplay กับปุ่มหรือค่าที่ hardcode
3. ทำ HUD แบบ responsive; gameplay field คงสัดส่วน 9:16 เพื่อความยุติธรรมบน PC และมือถือ
4. ใช้ asset ที่สร้างเองหรือมีสิทธิ์ใช้เท่านั้น และเก็บไฟล์ต้นฉบับแยกจาก export
5. ทดสอบด้วย build จริงบน Windows และ Android ก่อนประกาศว่า platform นั้นพร้อม
