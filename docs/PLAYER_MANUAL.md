# คู่มือผู้เล่น — LAST LIGHT (2D Reference, Windows)

> คู่มือฉบับนี้ครอบคลุมโปรเจกต์ 2D (`projects\last-light\`) ที่ถูกเก็บเป็น **playable reference** — เกมหลักปัจจุบันคือ 3D Tower Defense ดู [PLAYER_MANUAL_3D.md](./PLAYER_MANUAL_3D.md)

## เป้าหมาย

ปกป้อง Shelter 09 จากฝูง Hollows ที่บุกลงมาตามถนน กำจัดศัตรูก่อนข้ามแนว และเอาชนะ Rift Warden ในช่วงท้ายภารกิจ

## การควบคุม

| การกระทำ | Windows |
|---|---|
| ขยับซ้าย/ขวา | A/D หรือ ←/→ |
| ยิง | ยิงอัตโนมัติ |
| Emergency Blast | Space เมื่อ Parts เต็ม |
| อัปเกรดอาวุธ | E เมื่อ Parts เต็ม |
| Pause/เล่นต่อ | Esc หรือปุ่ม II |

ที่หน้า Title ใช้ Salvage ซื้อ Barricade Upgrade เพื่อเพิ่ม Integrity เริ่มต้นของรอบถัดไป (สูงสุด 2 ระดับ) และมี Settings สำหรับเสียง, ลดแสงวาบ, ขนาดข้อความ และภาษาไทย/อังกฤษ

## Parts: ป้องกันและอัปเกรด

การกำจัดศัตรูเติม Parts เมื่อครบ 100 เลือกได้หนึ่งทาง:

- **Weapon Upgrade:** เพิ่ม damage และ fire rate; อัปเกรดซ้ำได้สูงสุดเลเวล 6 ต่อรอบ
- **Emergency Blast:** ใช้ Parts กำจัดศัตรูที่เข้าใกล้แนว Shelter

ศัตรูทั่วไปให้ Parts 25 หน่วยต่อการกำจัดหนึ่งตัว; Blast ไม่คืน Parts ให้ตัวเอง

## ผลรอบและความคืบหน้าถาวร

- Salvage ที่ได้ = จำนวนกำจัด + 5 เมื่อชนะ − จำนวน breach (อย่างน้อย 0)
- Salvage ซื้อ Barricade Upgrade ได้: ระดับแรก 30 และระดับสอง 70
- ยอด Salvage สะสม 20 / 75 / 150 ปลดบันทึกเรื่องใน Field Archive
- ผล, สถิติ และ archive เก็บใน `user://profile.json`; settings แยกเก็บใน `user://settings.cfg`
- หากไฟล์หลักเสีย เกมพยายามกู้จาก `.bak`; หาก save จากเกมเวอร์ชันใหม่กว่า ระบบจะไม่เขียนทับไฟล์นั้น

## ศัตรู

- **Drifter:** เคลื่อนลงตรง ๆ
- **Skitter:** ส่ายซ้าย–ขวา
- **Dasher:** ส่งสัญญาณเตือนก่อนพุ่งลงเร็ว
- **Rift Warden:** ปรากฏช่วงท้ายภารกิจ; แถบเตือนระบุเลนที่พุ่งชน ขยับออกจากแนวนั้นก่อนโจมตี Shelter

## แพ้และชนะ

- ศัตรูที่ข้ามแนว Shelter ทำให้ Integrity ลด
- Integrity หมด = ภารกิจล้มเหลว
- เอาชนะ Rift Warden = ภารกิจสำเร็จ
- เลือก Restart เพื่อเริ่มรอบใหม่ หรือ Title เพื่อกลับหน้าแรก

> นี่คือ Windows prototype ที่กำลังปรับ core loop; ยังไม่เริ่ม Android development และยังต้อง playtest ความสนุก/สมดุลก่อนเพิ่มคอนเทนต์
