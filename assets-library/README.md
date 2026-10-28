# assets-library — คลัง asset พร้อมใช้ (ยังไม่ต่อกับ Godot project)

> ไฟล์ที่นี่เป็น "คลังกลาง" — อยู่นอก `projects/my-game/` เพื่อไม่กระทบเกมที่กำลังรัน/เทสต์
> จะใช้จริง: คัดลอกไป `projects/my-game/assets/` แล้วผูกใน scene (Godot จะ import ให้เอง)

## sprites/items — ไอเทมกลางสนาม 16×16 (sweetie16, outline `#1a1c2c`)

| ไฟล์ | ไอเทม | กลไกที่วางแผนไว้ (DESIGN.md §ระบบพิเศษ — ยังไม่ implement) |
|---|---|---|
| `item_speed.png` | ⚡ บูสต์ความเร็ว | วิ่งเร็วขึ้นช่วงสั้น ๆ |
| `item_heavy.png` | ⚫ บอลหนัก | บอลหนักขึ้นชั่วคราว / เตะพุ่งแรงกว่าเดิม |
| `item_decoy.png` | 👻 อำพราง | สร้างตัวหลอก ทำคู่แข่งสตีล/ตามบอลพลาด |
| `item_gate.png` | 🚪 โรเลิ่ลลิงเกต | ประตูกั้นขยับขวางบอลช่วงสั้น ๆ |

- วาดด้วย **pixelart-mcp (ฟรี)** ตาม workflow: silhouette → flat → shade → outline → spaa → lint
- พาเลตต์ **sweetie16** ตรงตาม DESIGN.md §ภาพกราฟิก
- `previews/*_x8.png` = ภาพซูม 8 เท่าไว้ดูเท่านั้น — **อย่า**เอาไปผูกใน Godot (ใช้ไฟล์ 16×16 ที่โฟลเดอร์หลัก)
- ปุ่มใช้ไอเทมตาม DESIGN.md: P1 = `X`, P2 = `J` (เตรียมไว้)

## textures/pitch_grass_tile.png — พื้นสนามหญ้า 32×32 (tile ต่อกันได้)

- แถบหญ้าแนวตั้ง 8px สลับเขียวอ่อน `#38b764` / เขียวเข้ม `#257179` + จุดรบกวนเบา ๆ
- ต่อแนวนอน/แนวตั้งแบบ seamless — เอาไว้เป็นพื้นหลังสนาม (TextureRect/Sprite ตั้ง texture repeat)
- เส้นสนาม/กรอบประตูยังอยู่ใน arena scene เดิม (tile นี้เป็นเฉพาะพื้นหญ้า)
