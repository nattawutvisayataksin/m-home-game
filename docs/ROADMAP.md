# Development Roadmap

## หลักการจัดลำดับ

พิสูจน์การยิง/จัด lane/ตัดสินใจใช้เกจก่อนทำ content จำนวนมาก เป้าหมายแต่ละระยะจบด้วย build ที่เปิดตรวจได้ และไม่อ้างว่า Android ผ่านก่อนทดสอบบนอุปกรณ์จริง

## Phase 0 — Pre-production ✅

- เลือก Godot 4.7.2, 2D, portrait 9:16, Windows + Android, solo PvE
- เขียน design baseline, เรื่อง, art direction, architecture, manual และ handoff
- ตั้ง project skeleton และ path แบบ relative

**ผ่านเมื่อ:** project เปิดได้, โครงเอกสารตรงกัน, ไม่มี path เครื่องเฉพาะใน run/check script

## Phase 1 — Greybox prototype

- `Player` เคลื่อน X และ clamp ใน playfield
- อาวุธ auto-fire, projectile ชน enemy, enemy ลงตาม lane
- Beacon Integrity ลดเมื่อศัตรู breach; มี lose state และ restart
- Resonance charge แล้วเลือก Overclock หรือ Pulse; HUD แสดงผลทันที
- wave สั้นหนึ่งชุด ใช้ primitive shapes ไม่มี art dependency

**ผ่านเมื่อ:** core loop เล่นซ้ำได้ 2 นาทีโดยไม่มี softlock; เลือก Pulse แล้วช่วยหยุดภัยทันที, เลือก Overclock แล้วมีผลให้เห็นชัดใน wave ต่อมา; restart reset state ครบ

## Phase 2 — Vertical slice

- เพิ่ม Drifter, Skitter, Dasher และบอส 1 ตัว
- ทำหนึ่งภารกิจ 5–6 นาทีพร้อม telegraph และจังหวะพัก
- เพิ่ม title/pause/result/settings ขั้นต่ำ, feedback SFX/VFX ชุดแรก
- ทำ visual target และทดสอบ art import ที่ 9:16
- เพิ่ม event-driven HUD, input actions, safe area และ reduce shake/flash

**ผ่านเมื่อ:** ผู้เล่นใหม่เข้าใจการควบคุมและเห็นการเลือกใช้เกจ; run จบได้ทั้งชนะและแพ้; visual/audio ไม่บังข้อมูลสำคัญ

## Phase 3 — Progression และ production foundation

- Salvage, meta unlocks ที่ไม่ทำให้ balance พัง, versioned atomic save
- data resources สำหรับ wave/enemy/weapon/upgrade
- test save migration, scene flow และ stress performance
- localization-ready strings ไทย/อังกฤษ

**ผ่านเมื่อ:** ปิด/เปิดเกมแล้ว progress/settings ตรง; save เสียไม่ทำให้เกม crash แบบเงียบ; content เปลี่ยนได้โดยไม่แก้ core code

## Phase 4 — Content + platform

- เพิ่มภารกิจ/บอสตามผล playtest, polish UI/animation/audio
- Windows export preset และ smoke test บน clean machine
- Android SDK/export templates, touch tuning และ device test
- accessibility, crash/error reporting และ release checklist

**ผ่านเมื่อ:** export เปิดบน Windows และ Android target จริง, save/user path ถูกต้อง, UI ไม่ชน safe area, performance ผ่านเกณฑ์ที่กำหนดจากอุปกรณ์จริง

## Playtest metrics ที่ควรเก็บ

- เวลาที่ผู้เล่นใช้จนเข้าใจว่าศัตรูจะ breach
- จำนวน breach/Integrity ที่เหลือในชัยชนะ
- ใช้ charge ไปกับ Overclock/Pulse กี่ครั้ง และเหตุผลที่ผู้เล่นเลือก
- จุดเวลาที่ผู้เล่นตาย/ออกจากเกม และระดับความยากที่รายงาน
- เฟรมเรต/จำนวน entity บน PC และ Android เครื่องอ้างอิง

อย่าปรับ balance ด้วยค่าเฉลี่ยอย่างเดียว: สังเกตผู้เล่นที่ไม่รู้ genre และแยกปัญหา readability, control, difficulty ออกจากกัน

## Risks และวิธีลด

| ความเสี่ยง | ลดความเสี่ยง |
|---|---|
| มือถือเล็ง/เคลื่อนยาก | auto-fire, จำกัดแกน X, ปรับตำแหน่ง/ขนาด touch control และทดสอบถือเครื่องจริง |
| อ่านกระสุนไม่ออก | จำกัดสี/เอฟเฟกต์, telegraph ด้วยรูปร่าง+motion, ลดรายละเอียดพื้นหลัง |
| ทางเลือกเกจไม่สมดุล | telemetry/playtest; ปรับ charge rate และผลของ Overclock/Pulse เป็น data |
| scope บานเป็น roguelite ใหญ่ | ล็อก MVP หนึ่ง arena/หนึ่งภารกิจ/หนึ่งบอสก่อนเพิ่ม meta/content |
| Android export ช้า | ตรวจ SDK/templates ตั้งแต่ Phase 1–2 แต่คง Windows เป็นเครื่องพัฒนาและ debug หลัก |
| asset tool ให้ผลไม่สม่ำเสมอ | อนุมัติ visual target ก่อนสร้างทั้งชุด; ตรวจทุก asset ใน Godot scene |
