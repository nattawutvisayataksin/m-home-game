# TD-2 Asset Production Plan — ฉบับเตรียม exec

สถานะ: รอ Blender AI Bridge เปิด — เมื่อ bridge พร้อม สร้างตาม spec นี้ได้ทันทีโดยไม่ต้องคิดใหม่
เจตนา: ป้อม/ศัตรูแต่ละตัวต้อง **อ่านออกจากรูปร่างแม้ไม่มีสี** (GDD_3DTD §readability) — ไม่พึ่งสีอย่างเดียว

---

## 0) กติกาการผลิตร่วม (ทำผ่าน blender-asset-mcp ทุกครั้ง)

- หน่วย: **1 unit = 1 m** ตรงกับ grid ของ greybox (ย่อม slot สุดคือ Ø1.4, ถนนกว้าง 2.6)
- Workflow บังคับ: `get_scene_info` → `begin_operation` → สร้าง → `render_preview` → **อ่านภาพจริง** → แก้ → render ซ้ำ → `validate_game_asset` → `end_operation`
- โพลิกอน: ป้อม ≤ 800 tris, ศัตรู ≤ 400 tris, props ≤ 600 tris — ต่ำให้เฟรมเรตสูงบน GL Compatibility
- Export: **.glb** หนึ่งไฟล์ต่อชิ้น ไปที่ `projects/last-light-3d/assets/models/<group>/<name>.glb` (+ .blend เก็บใน blends/ ของ workspace ที่ bridge กำหนด)
- สีวัสดุจาก MARKETING palette (โลหะเย็น + จุดโฟกัส amber) — ตั้งเป็น material albedo ต่อชิ้นตอนฝั่ง Blender

## 1) ป้อม (3) — เกณฑ์ติดตา: ต้องแยกกันได้จากเงาดำ

| Asset | โครง (แทน greybox cylinder+ผิวเดิม) | สัญญาณระบุชนิด | albedo หลัก |
| --- | --- | --- | --- |
| `towers/field_turret.glb` | ฐานกระบอก Ø1.6 h0.5 + ตัวบน Ø1.1 + ลำกล้องเดี่ยวยาว 1.2 หมุนตามเป้า | **ปืนเดี่ยว** ยาวเด่นทิศหนึ่ง | ฐาน `#3f463c`, ลำกล้อง amber `#e8a95c` |
| `towers/sonic_resonator.glb` | ฐานเดียวกัน + **ขดลวด 2 วงซ้อน** (torus Ø0.9/0.6) + จานกว้าง หน้าตัด 1.2 | **ขดลวด/จาน** บอก splash | ฐานเดียวกัน, ขด `#8ea0b4`, แกน amber emissive เบา |
| `towers/tangle_emitter.glb` | ฐานเดียวกัน + **เสาสั้นมน** + ยอดสปริงแผ่หนามรอบวง (spike ring Ø0.9) | **หนาม/สปริง** บอก slow | ฐานเดียวกัน, สปริง `#75654a`, จุดเรือง `#5a4f8a` (ม่วงอุ่น) |

- ทุกป้อมมีฐานอยู่ที่ `Y=0` แน่นดิน (ไม่ทับ slot disk ที่ height 0.06)
- Level 1/2 ยังไม่ต้องทำ mesh แยกฝั่ง Blender — เพิ่ม `scale` 20%/40% ใน Godot เหมือน greybox เดิม (ระดับเดียวกันทุกชิ้น)

## 2) ศัตรู (4) — ครบกับ archetype และเงาต่างกันตามเท้า

| Asset | รูปทรง | สัญญาณท่าเดิน/ขนาด | albedo |
| --- | --- | --- | --- |
| `enemies/drifter.glb` | ตัวบล็อกโค้ง 1.0×1.6×1.0 (bent box) | ช้า เดินจาง ๆ, ฐานมน | `#9ea395` (ฝุ่นเทา) |
| `enemies/skitter.glb` | แคปซูล 0.7×0.9 + **ตีนเส้นเล็ก 4 ข้าง** (ธีมมด) | เร็ว, เชิงเท้าสั้นบ่า | `#c8b367` |
| `enemies/dasher.glb` | ลำตัว wedge 0.6×1.4×1.4 แหลมหนึ่งด้าน | เร่งเป็นธนูยาว | `#bf6b4d` |
| `enemies/warden.glb` | บอส block 2.4×3.2×2.4 + **แขนเหวี่ยง 2 ข้าง + เสาหนาม rift** บนหัว | ช้า ตัวสูงกว่าป้อม (กล้องมองข้ามแบบไม่ซ่อน) | `#8c333d` + จุด rift emissive `#5a4f8a` |

- Pivot: ที่ระดับพื้น (กึ่งกลาง X/Z, Y=0) — Godot spawn ที่พื้นเสมอ
- ห้าม shape key / animation ใน MVP — เคลื่อนด้วย waypoint จาก `td_enemy.gd` เช่นเดิม ส่วนจังหวะเดินเป็น polish หลัง vertical slice

## 3) ฉาก props

| Asset | สัญญาณรายละเอียด |
| --- | --- |
| `props/shelter.glb` | ไซโล 3.0×2.2×2.2 + เสาสัญญาณ + ตะเกียง amber ติดบน (ยังเข้ากับ logo title) |
| `props/road_tile.glb` | ถนน 4×0.1×4 (แต่งร่องแตกเล็ก) แทน wire BoxMesh strip |
| `props/slot_pad.glb` | จุดวาง Ø1.4 แทน disk cylinder — แยก 2 material (ว่าง / มีป้อม) เพื่อ Godot tint ด้วย colormap |
| `props/ruin_a.glb`, `props/ruin_b.glb` | เศษอาคารมุมฉากสั้น 2 ชิ้น วางขอบนอกเลน — narrative บรรยากาศเกาะ |

## 4) ลำดับ exec เมื่อ bridge พร้อม

1. ทดสอบ bridge ด้วย `get_scene_info` + สร้าง cube ทดลอง → render → อ่าน (ตรวจ round trip ครบใน 1 รอบ)
2. ป้อมทั้งสาม — ชิ้นแรกสำคัญที่สุด: `field_turret` (ผู้เล่นทุกคนวางตัวนี้เป็นตัวแรก)
3. ศัตรู 4 — เริ่ม `drifter` ตามด้วย `warden` (บอสคือหัวเรื่องการวางป้อม)
4. Shelter + road tiles + slot pad + ruins
5. ชิ้นแต่ละชิ้น: `validate_game_asset` **และ** อ่านภาพ render จริง ก่อน export — งบ round trip ไม่เกิน 10 ต่อ asset
6. แทน greybox ใน Godot: `MeshInstance3D` เดิมเปลี่ยนเป็นโหลด `.glb` ผ่าน `load()` หลัง `dev-3d.ps1 -Action import` — เทสต์ต้องยังผ่านตาม node/frame เดิม
7. ปิดเฟส: dev log entry + ROADMAP อัปเดตสถานะ TD-2

## 5) ข้อชี้แนะเสริม (เสนอ ยังไม่บังคับ)

- หาก render_preview ครั้งเดี่ยวมีหลายกล้อง: เลือกมุมเดียวชัด ๆ แล้วซูมจุดสงสัยเท่านั้น — ไม่ต้อง render หนัก
- ทุก asset อยู่ใน **blend แยกไฟล์ต่อชิ้น** ไม่เพิ่ม animation จนหลัง vertical slice
