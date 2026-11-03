# LAST LIGHT — Marketing Kit

แหล่งรวมข้อความสื่อสารสำหรับหน้าร้าน itch.io / Steam และสื่อโซเชียล
ตัวเลข gameplay ในข้อความนี้ต้องสอดคล้องกับ `docs/GDD_3DTD.md` เสมอ (ห้ามคิดเลขเอง)

---

## 1) Positioning

- **Genre:** 3D Tower Defense, wave-based, single-screen lane defense
- **One-liner (TH):** ตั้งป้อม รับฝูง คุมคืนสุดท้าย — เปลี่ยนเศษเหล็กเป็นแนวรบ ปกป้อง Shelter 09 จนรุ่งสาง
- **One-liner (EN):** Rig the last line. Build towers from salvage, hold Shelter 09 through the night, and face the Rift Warden at dawn.
- **Taglines สำรอง:**
  - "แสงสุดท้าย คือแนวรบของเรา"
  - "Every part you scrap is a tower that saves the dawn."
- **Pillars ที่ต้องโผล่ในทุกสื่อ:**
  1. ตัดสินใจจากทรัพยากร — Parts ทุกชิ้นคือการเลือกว่า walkway ไหนต้องรอด
  2. คืนเดียว 8 คลื่น — เซสชันสั้นที่มี arc ครบ (เริ่มง่าย จบด้วยบอส)
  3. ป้อม 3 แบบ + อัปเกรด/ขาย — ทุกป้อมขายคืนได้ 70% จึงกล้าทดลอง

## 2) Store copy

### Short (itch.io blurb, ~60 คำ)

> เกาะชายฝั่งหลังคืนไร้ดาว ฝูง Hollows ยกมาตามถนนทุกคืนเพื่อล้ำแนวรบของ Shelter 09
> คุณคือริน เปลี่ยนเศษ Salvage เป็นป้อมยิง เครื่องคลื่น และสายพันเท้า — ตั้ง อัปเกรด ขายคืน
> รอดครบ 8 คลื่นจนตัวจริงของคืนออกมา: Rift Warden

### Long (Steam About, ~150 คำ, โครง 3 ย่อหน้า)

> **LAST LIGHT** เป็น tower defense มุมมอง isometric แบบ fixed camera ที่ตัด hero unit ออกทั้งหมด — แผนการรบของคุณคือทั้งหมดที่คุณมี
>
> แต่ละคืนคือ 1 รอบภารกิจ: เก็บ Parts จากการกำจัดฝูง Hollows ตัดสินใจว่าจะวาง Field Turret ยิงเร็ว Sonic Resonator ระเบิดวงกว้าง หรือ Tangle Emitter ที่ช้าทุกสิ่งในรัศมี ป้อมอัปเกรดได้ 2 ระดับ และขายคืน 70% เสมอ จึงแก้แนวรบได้กลางคืน
>
> 8 คลื่นจบด้วย Rift Warden บอสที่ไม่ได้ทนแค่ตัวเลข — มันบังคับให้คุณรื้อแผนที่ตั้งไว้ตั้งแต่คลื่นแรก ระบบเก็บ playtest metrics ติดตั้งในเกมตั้งแต่วันแรก เพราะเราต้องการสถิติจริงในการปรับสมดุล

### Feature list (bullets หน้าร้าน)

- เป้าเคลื่อนที่แบบ "first" + slow aura + splash — สามกลไกที่ต้องวางคู่กันจึงจะอยู่รอด
- อัปเกรดสูงสุด 2 ระดับ/ป้อม, ขายคืน 70% — ความผิดพลาดไม่ใช่ game over
- คลื่นที่ 8 ปิดด้วยบอสตัวเดียว Warden (ราคากำลังบอส: Parts ล้นถ้าชนะ)
- ภาษาไทยก่อน (UI + story) พร้อมเวลาอ่านสั้นที่เหมาะกับเซสชันกลางคืน
- low-poly stylized ที่รันได้บนเครื่องธรรมดา (Godot 4, GL Compatibility)

## 3) Visual / Logo

- **ต้นฉบับเวกเตอร์:** `projects/last-light-3d/assets/brand/logo_emblem.svg` (copy ที่ `docs/art/logo_emblem.svg`)
- **สัญลักษณ์:** ตะเกียงเรือนแสงบนเพลาสัญญาณ + ไซโล Shelter 09 เป็นเงา 2 มิติ ล้อมด้วยแอมเบอร์ halo — คือ "แสงสุดท้ายที่ต้องถูกปกป้อง"
- **Palette ของแบรนด์** (ใช้ตรงกับทั้ง UI และงานสื่อสาร):
  - พื้นมืด `#141826` / `#0d1118`
  - แสงอำพัน `#ffd98a` → `#e8a95c` (จุดโฟกัสเสมอ)
  - โลหะเย็น `#8ea0b4` (โครงสร้าง/ตัวอักษรรอง)
  - กรอบเสื่อมสภาพ `#75654a`
- **Wordmark:** ใช้ Noto Sans Thai (headings เว้น weight 600+, ไม่ทำ italic กับตัวไทย) — ตัวอังกฤษ "LAST LIGHT" ตั้ง tracking +0.08em ให้จมเข้ากับตัวไทย
- **ข้อห้าม:** ห้ามกลับสีพื้นเป็นสว่าง, ห้ามลด opacity ของตะเกียงลงต่ำกว่า 100% เพราะจะสู่แนวความคิด "แสงสุดท้าย"

## 4) Channel plan

| ช่องทาง | จังหวะ | ของที่ต้องมี |
| --- | --- | --- |
| itch.io | ทำ greybox เล่นได้ + metrics ครบ → open playtest | build, หน้า page จาก section 2, GIF 10 วินาที (วางป้อม→คลื่นแรก) |
| Steam | หลัง TD-2 asset pass + ฟีเจอร์ meta ครบ (save, settings, accessibility) | store page, caps: header 460x215 + main capsule, ภาพ screenshot 6 ภาพ |
| โซเชียล (phased) | หลังมี gameplay GIF | devlog สั้น รายสัปดาห์ อิง dev log จริงใน repo |

## 5) Trailer / GIF hooks (เมื่อ TD-2 เสร็จ)

1. เปิด: กล้องค้างที่ถนนว่าง + เสียงวิทยุของมีรา 1 ประโยค
2. วางป้อม 3 ชนิดเร็ว ๆ (montage จาก menu → wave 1)
3. จุดไคลแมกซ์: warden เดินเข้ารัศมีทุกป้อมพร้อมกัน (คอมโบ slow + splash)
4. จบ: จอชนะ + copy "แสงสุดท้าย คือแนวรบของเรา"

## 6) Launch checklist

- [ ] เลขทั้งหมดใน copy ตรงกับ data `.tres` (cost 80/120/60, 8 waves, refund 70%)
- [ ] ตัวหนังสือไทยไม่ตัดกัน (ตรวจที่ 1280x720 และ 1920x1080)
- [ ] GIF/ภาพมาจาก build จริงที่ metrics บันทึกอยู่ (ไม่ใช่ build debug ที่แกตัวเลข)
- [ ] ชื่อเรื่อง/ชื่อ IP สะกดตรงกันในทุก asset: LAST LIGHT, Shelter 09, ริน, มีรา, Hollows, Rift Warden
