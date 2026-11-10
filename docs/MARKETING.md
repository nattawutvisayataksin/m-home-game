# LAST LIGHT — Marketing Kit

แหล่งรวมข้อความสื่อสารสำหรับหน้าร้าน itch.io / Steam และสื่อโซเชียล
ตัวเลข gameplay ในข้อความนี้ต้องสอดคล้องกับ `docs/GDD_3DTD.md` เสมอ (ห้ามคิดเลขเอง)

---

## 1) Positioning

- **Genre:** 3D Tower Defense, wave-based, free-placement lane defense
- **One-liner (TH):** ตั้งป้อม รับฝูง คุมคืนสุดท้าย — เปลี่ยนเศษเหล็กเป็นแนวรบ ปกป้อง Shelter 09 จนรุ่งสาง
- **One-liner (EN):** Rig the last line. Build towers from salvage, hold Shelter 09 through the night, and face the Rift Warden at dawn.
- **Taglines สำรอง:**
  - "แสงสุดท้าย คือแนวรบของเรา"
  - "Every part you scrap is a tower that saves the dawn."
- **Pillars ที่ต้องโผล่ในทุกสื่อ:**
  1. ตัดสินใจจากทรัพยากร — Parts ทุกชิ้นคือการเลือกว่า walkway ไหนต้องรอด
  2. คืนเดียว 8 คลื่น — เซสชันสั้นที่มี arc ครบ (เริ่มง่าย จบด้วยบอส)
  3. ป้อม 4 แบบ + อัปเกรด/ขาย — ทุกป้อมขายคืนได้ 70% จึงกล้าทดลอง

## 2) Store copy

### Short (itch.io blurb, ~60 คำ)

> เกาะชายฝั่งหลังคืนไร้ดาว ฝูง Hollows ยกมาตามถนนทุกคืนเพื่อล้ำแนวรบของ Shelter 09
> คุณคือริน — วิศวกรคุมแนว: เปลี่ยนเศษ Salvage เป็นป้อมยิง เครื่องคลื่น และสายพันเท้า ตั้ง อัปเกรด ขายคืนได้ 70% ระหว่างเดินยิงคุมหน้าเองด้วยปืนเล็ก
> รอดครบ 8 คลื่นจนตัวจริงของคืนออกมา: Rift Warden — แล้วเอา Salvage ที่ได้ไปหุ้มฐานที่มั่นเพื่อคืนถัดไป

### Long (Steam About, ~150 คำ, โครง 3 ย่อหน้า)

> **LAST LIGHT** เป็น tower defense มุมมอง isometric แบบ fixed camera — กระดูกงูของแผนการรบคือแนวป้อม และ **ริน** นักลงสนามที่คุมเอง (WASD + ยิงเอง) เดินคุมหน้าคู่เส้นทางได้อิสระบนพื้นสนามจริง ไม่มีตารางเลน
>
> แต่ละคืนคือ 1 รอบภารกิจ: เก็บ Parts จากการกำจัดฝูง Hollows แล้ววางป้อมโดยใช้พื้นสนามจริง (ไม่มีตารางเลน) — Field Turret เลเซอร์ยิงเดี่ยว, Sonic Resonator จรวดระเบิดวงกว้าง, Tangle Emitter ไฟฟ้าชะลอ, Arc Cannon ระยะไกลระเบิดแรง ป้อมอัปเกรดได้ 2 ระดับ ขายคืน 70% เสมอ และ**ชี้ที่ป้อมกด T สลับโหมดเลือกเป้าต่อป้อม**: หัวแถว / ท้ายแถว / แข็งสุด / อ่อนสุด
>
> 8 คลื่นปิดด้วย Rift Warden บอสที่บังคับให้คุณรื้อแผนตั้งแต่กลุ่มกลาง ชนะแล้วปลดล็อก **ที่ราบริฟท์** — ถนนยาวโค้งมากกว่า — และทุกคืนส่ง Salvage กลับหน้าเมนูเข้าแผง "ฐานที่มั่น": อัปเกรดถาวร +2 Shelter Integrity ต่อระดับ ใช้กับคืนถัด ๆ ไป

### Feature list (bullets หน้าร้าน)

- ป้อม 4 แบบ + อัปเกรด 2 ระดับ + ขายคืน 70% — แก้แนวได้กลางคืน ผิดพลาดไม่ใช่ game over
- **โหมดเลือกเป้าต่อป้อม (T):** หัวแถว / ท้ายแถว / แข็งสุด / อ่อนสุด — อ่านเกมแล้วเลือกเอง
- **ริน — hero คนเดียวของเกม:** auto-deploy ทุกคืน, เดินสายคุมหน้า ยิงที่จุด/ด้านหน้า, เรียกกลับได้ (H)
- **สองแผนที่ + เรียกคลื่นเชื่อมได้**: กดเปิดคลื่นถัดไปกลางคลื่นเดิม = เสี่ยงเงินไหลเร็ว
- **แผงฐานที่มั่น (progression ถาวร):** Salvage ทุกคืนสะสมเป็นเกราะเริ่มคืนถัดไป
- ภาษาไทยก่อน พร้อมสลับ English ได้ในแผงตั้งค่า (UI + คู่มือ + เรื่องราว)
- low-poly stylized ที่รันได้บนเครื่องธรรมดา (Godot 4, GL Compatibility)

### EN store copy (2026-11-10 — ร่างเตรียมขึ้น; อนุมัติขั้นสุดท้ายโดยผู้กำกับก่อนเผยแพร่จริง)

**Short (itch.io EN blurb, ~60 คำ):**

> On a coast gone dark since the starless night, the Hollows march down the old roads every night to break Shelter 09's line. You are Rin — the holding engineer: turn salvaged parts into lasers, rocket salvos and wire entanglements. Place anywhere, upgrade, sell back 70%. Rain fire while she covers the ground herself, survive one eight-wave night, then put your salvage into the base's permanent armor for the next.

**Long (Steam EN About, ~160 คำ):**

> **LAST LIGHT** is a fixed-camera isometric tower defense: your towers are the backbone of the plan, and Rin, your on-field operative, fights beside them with WASD movement and aimed strikes. Placement is free — put a turret anywhere the salvage can reach.
>
> Each night is one mission: scrap the Hollows for Parts, then choose between the Field Turret (fast laser shots), the Sonic Resonator (wide-area splash), the Tangle Emitter (an electric slow field) and the Arc Cannon (long-range bursts). Each tower upgrades twice and sells back 70% — and pointing at a tower and pressing T changes which enemy it targets: first, last, strongest or weakest.
>
> Eight waves close with the Rift Warden. Clearing map 1 unlocks Rift Fields, a longer winding route, and every night's salvage feeds the base panel on the title screen — permanent Barricade armor, +2 Shelter Integrity per level, for the nights after.

**EN feature bullets:**

- 4 towers with free placement, two upgrade levels, always 70% sell-back
- Per-tower targeting modes (T): first / last / strongest / weakest
- Rin, your single hero: auto-deploys, WASD + aimed strikes, recall with H
- Two nights (maps) after victory — chain the next wave early for faster money at greater risk
- Permanent base-panel progression from battlefield salvage
- Thai-first UI with instant English switch in settings
- Low-poly stylized visuals that run on modest PCs (Godot 4, GL Compatibility)

## 3) Visual / Logo

- **ต้นฉบับเวกเตอร์:** `projects/last-light-3d/assets/brand/logo_emblem.svg` (copy ที่ `docs/art/logo_emblem.svg`)
- **ภาพหน้าร้าน:** `docs/marketing/menu_title.png` + `showcase_battle.png` — **re-capture 2026-11-10** จาก build จริง (มีแผงฐานที่มั่นบนเมนู, ริน+การ์ด+HUD ฉากรบ คลื่น 1 มีการต่อสู้จริง) ผ่าน `projects/last-light-3d/tests/dev_marketing_capture.gd` (in-engine capture เท่านั้น) — เปลี่ยนเมนู/ฉากเพิ่มเมื่อไรให้ recapture ด้วย
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

- [ ] เลขทั้งหมดใน copy ตรงกับ data `.tres` (cost 80/120/60/140, 8 waves, refund 70%)
- [ ] copy ภาษาอังกฤษ (หัวข้อ EN store copy) ผ่านการอนุมัติผู้กำกับขั้นสุดท้าย
- [ ] ตัวหนังสือไทยไม่ตัดกัน (ตรวจที่ 1280x720 และ 1920x1080)
- [ ] GIF/ภาพมาจาก build จริงที่ metrics บันทึกอยู่ (ไม่ใช่ build debug ที่แกตัวเลข)
- [ ] ชื่อเรื่อง/ชื่อ IP สะกดตรงกันในทุก asset: LAST LIGHT, Shelter 09, ริน, มีรา, Hollows, Rift Warden
