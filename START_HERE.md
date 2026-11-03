# START HERE — LAST LIGHT

## เป้าหมาย

เดิม: สร้างเกม 2D survival-defense ที่ผู้เล่นเดินเท้าป้องกัน Shelter จากฝูงศัตรู เลื่อนซ้าย–ขวา ยิงอัตโนมัติ อัปเกรดอาวุธระหว่างคลื่น และเสริม Barricade ระหว่างรอบ

**อัปเดต (2026-11-03):** Game Director ตัดสินพัฒนาต่อเป็น **3D Tower Defense (วางป้อมล้วน, low-poly stylized จาก Blender)** คง IP LAST LIGHT — โปรเจกต์ 3D ใหม่อยู่ที่ `projects\last-light-3d\` ดู [docs/GDD_3DTD.md](./docs/GDD_3DTD.md) และ ROADMAP หัวข้อ "3D Tower Defense pivot" ฉบับ 2D ถูกเก็บเป็น playable reference และเพิ่ม **RunMetrics** สำหรับเก็บ playtest data อัตโนมัติ (บันทึกไว้ที่ `user://metrics/`)

## สถานะปัจจุบัน

- ✅ เปลี่ยน visual direction จากยานเป็นผู้รอดชีวิต/ฝูงติดเชื้อและแนว Shelter
- ✅ อัปเกรดปืนซ้ำได้สูงสุดเลเวล 6 ในรอบ และเสริม Barricade ระหว่างรอบได้ 2 ระดับ
- ✅ profile schema v3 migration พร้อม automated gameplay/save/stress tests
- ⏳ รอ Windows playtest; Android และ export ถูกพักไว้

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
| เช็กลิสต์ทดสอบจริง | [docs/PLAYTEST_PLAN.md](./docs/PLAYTEST_PLAN.md) |
| Release gates | [docs/RELEASE_CHECKLIST.md](./docs/RELEASE_CHECKLIST.md) |

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
.\scripts\test.ps1
```

Godot project อยู่ที่ `projects\last-light\project.godot` เสมอ save ของเกมอยู่ใน `user://` ไม่เขียนลง `res://` หรือโฟลเดอร์ asset. ตอนนี้ยังไม่ต้องตั้ง Android SDK/JDK หรือ export; ทดสอบ core loop บน Windows ก่อน

## แนวทางการทำงาน

1. ทำ prototype core loop ให้ครบก่อนทำ content จำนวนมาก
2. ใช้ InputMap actions และ resource data แทนการผูก gameplay กับปุ่มหรือค่าที่ hardcode
3. ทำ HUD แบบ responsive; gameplay field คงสัดส่วน 9:16
4. ใช้ asset ที่สร้างเองหรือมีสิทธิ์ใช้เท่านั้น และเก็บไฟล์ต้นฉบับแยกจาก export
5. ยืนยันความสนุกและความชัดเจนของ core loop บน Windows ก่อนเพิ่มคอนเทนต์หรือเริ่ม Android
