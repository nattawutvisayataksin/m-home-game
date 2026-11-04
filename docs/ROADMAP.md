# Development Roadmap

## หลักการจัดลำดับ

พิสูจน์การเอาตัวรอดและป้องกัน Shelter ก่อนทำ content จำนวนมาก เป้าหมายแต่ละระยะจบด้วย build ที่เปิดตรวจได้ และไม่อ้างว่าแพลตฟอร์มผ่านก่อนทดสอบจริง

**ลำดับความสำคัญปัจจุบัน:** ทำ combat loop ให้สนุกและอ่านง่ายบน Windows ก่อน ยังไม่ทำ Android-specific development, export หรือ device tuning จนกว่าจะยืนยัน core loop จาก playtest

## Phase 0 — Pre-production ✅

- เลือก Godot 4.7.2, 2D, portrait 9:16, solo PvE; Windows เป็นแพลตฟอร์มทดสอบปัจจุบัน
- เขียน design baseline, เรื่อง, art direction, architecture, manual และ handoff
- ตั้ง project skeleton และ path แบบ relative

**ผ่านเมื่อ:** project เปิดได้, โครงเอกสารตรงกัน, ไม่มี path เครื่องเฉพาะใน run/check script

## Phase 1 — Greybox prototype ✅

- ผู้รอดชีวิตเคลื่อน X และ clamp ใน playfield
- อาวุธ auto-fire, projectile ชน infected, ศัตรูบุกจากถนนเข้าหาแนว Shelter
- Shelter Integrity ลดเมื่อศัตรู breach; มี lose state และ restart
- Parts charge แล้วเลือก Weapon Upgrade หรือ Emergency Blast; HUD แสดงผลทันที
- wave สั้นหนึ่งชุด ใช้ primitive shapes ไม่มี art dependency
- integration test ครอบคลุม title → run, movement, auto-fire/hit, Parts, weapon upgrade, Emergency Blast, defeat/restart

**ผ่านเมื่อ:** core loop เล่นซ้ำได้ 2 นาทีโดยไม่มี softlock; ผู้เล่นเข้าใจการ breach และเห็นผลของการอัปเกรดปืน/Blast; restart reset state ครบ

**ตรวจยืนยันใน prototype:** input/auto-fire, projectile collision, Parts, weapon upgrade/Blast, defeat และ restart ผ่าน automated smoke test; Godot headless scene startup ผ่าน. ยังต้อง playtest จริงเพื่อยืนยันความสนุกและสมดุล 2 นาที

## Phase 2 — Vertical slice ✅ (implementation)

- เพิ่ม Drifter, Skitter, Dasher และบอส 1 ตัว
- ทำหนึ่งภารกิจสูงสุด 5 นาทีพร้อม telegraph และบอส
- เพิ่ม title/pause/result/settings ขั้นต่ำ, feedback SFX/VFX ชุดแรก
- ทำ visual target และทดสอบ art import ที่ 9:16
- เพิ่ม event-driven HUD, input actions, safe area และ reduce shake/flash

**ทำแล้ว:** Drifter/Skitter/Dasher/Rift Warden, mission clock 5 นาที, wave escalation, title/settings/pause/result, Windows keyboard controls, pixel-art target ต้นฉบับและ import, procedural VFX, ambient loop/SFX, boss telegraph และ health bar, ไทย/อังกฤษ, reduce flash/large text, integration smoke test

**รอ external playtest:** ปรับความยากและจังหวะบอสจากข้อมูลผู้เล่นใหม่; ยืนยัน readability บน Windows ก่อน

**ผ่านเมื่อ:** ผู้เล่นใหม่เข้าใจการควบคุมและเห็นการเลือกใช้ Parts; run จบได้ทั้งชนะและแพ้; visual/audio ไม่บังข้อมูลสำคัญ

## 3D Tower Defense pivot — active (2026-11-03)

จากคำตัดสิน Game Director: พัฒนาต่อเป็นเกม **3D tower defense วางป้อมล้วน** คง IP/เหตุของ Shelter 09 และ Hollows; สร้างในโปรเจกต์ใหม่ `projects\last-light-3d\` ขนานกับ 2D (2D คงสถานะ playable เพื่อ reference และเก็บ playtest baseline)

- **ตัวเลือกที่ล็อกแล้ว:** low-poly stylized (Blender), วางป้อมล้วน ไม่มี hero unit, กล้อง isometric fixed, Windows mouse+keyboard ก่อน, Android ยังพัก
- **Design baseline:** [GDD_3DTD.md](./GDD_3DTD.md) เป็นแหล่งตัดสินด้าน design ของโปรเจกต์ 3D ต่อจากนี้; [GDD.md](./GDD.md) คงเป็น baseline ของฉบับ 2D เดิม

### Phase TD-0 — Playground/Metric readiness ✅

- ระบบ `RunMetrics` บันทึก user://metrics/ แบบ plain JSON (schema version ผูกทุกไฟล์): wave/reason จบรอบ, integrity และ breach timeline, kill, Parts choice timeline (upgrade/blast), สถานะช่วง boss
- test automation เดินตาม PLAYTEST_PLAN metrics ที่ ROADMAP ระบุได้ โดยไม่ต้องเปิด Editor
- **ทำแล้ว:** phase6_metrics_test.gd และการบันทึก event จาก run จริงของฉบับ 2D (เครื่องมือใช้ร่วมวางแผน 3D)

### Phase TD-1 — Greybox 3D TD core loop (✅ implementation เสร็จ 2026-11-03; ผ่านเมื่อ core loop เล่นซ้ำได้ 2 คลื่นโดยไม่ softlock — รอ verify ผ่านการเล่นจริง)

- Scene 3D: กล้อง isometric fixed, แสง/ฟ้า/ฉากประกอบขั้นต้น, เส้นทาง waypoint หนึ่งเส้น
- ศัตรู primitive เดินตามเส้นทาง (Drifter/Skitter/Dasher ปรับจากค่าใหม่ TD), leak → Integrity
- ป้อม 3 ชนิด (Turret / Resonator / Tangle) วางบน slot, targeting first, auto-fire, Parts economy
- Wave spawner data-driven, next-wave preview, prep/run state แยกชัด, HUD ขั้นต่ำ (Parts/Integrity/wave/start wave)
- ตัวเลขทั้งหมดเป็น data (ค่าเริ่มใน script constants ได้ใน greybox แต่ต้องเก็บไว้ที่เดียว) และเขียน smoke test headless
- **ทำแล้ว:** ตัวเลข enemy/tower/wave ย้ายไป data `.tres` 15 ไฟล์ (`data/{enemies,towers,waves}/` + Resource classes ใน `scripts/data/`) พร้อม upgrade ระดับ 2 / ขายคืน 70% และหน้า title menu (เริ่มเกม / วิธีเล่น / เรื่องราว / ออก); ตัวเลขเศรษฐกิจของ session (start Parts/Integrity, wave bonus, refund ratio) ยังเป็น constants กลุ่มเดียวใน `td_run.gd` โดยชัดแจ้งว่าไม่ใช่ unit balance

### Phase TD-2 — Vertical slice (Blender low-poly + polish) (✅ Core Assets & Architecture complete; in-progress polish)

- Asset low-poly จริงจาก Blender: ป้อม/ศัตรู/Shelter/ฉากถนน; import pipeline + import check
- Boss Rift Warden + telegraphs, audio buses ผูกเดิม, VFX 3D ให้เคารพตัวเลือก reduce-motion และ reduce-flash
- Localization ไทย/อังกฤษ, save linkage จาก ProfileRepository (barricade level)
- Playtest มนุษย์ ผ่านเมื่อ: ผู้เล่นใหม่วางป้อมแรก < 25 วินาที และอธิบาย leak ได้
- **ทำแล้ว (2026-11-03):** สร้างโมเดล Blender low-poly (.glb) ครบชุด (ป้อม 3, ศัตรู 4, Shelter 09), เพิ่ม pipeline model_scene เชื่อมต่อ .tres, เพิ่มระบบ Pause Menu (Esc), เชื่อมต่อ ProfileRepository คำนวณ barricade level และบันทึก Salvage/สถิติจบรอบ, automated tests ผ่านสมบูรณ์
- **ทำแล้ว (2026-11-04):** Settings Menu (volume 3 ช่อง + reduce flashes/motion + large text) ใน title และ pause menu ผ่าน autoload `TDSettings` (`user://settings.cfg`, แพตเทิร์นเดียวกับ 2D); แก้ Esc-resume หลัง pause ที่จริง ๆ แล้วไม่เคยทำงาน (ย้ายไป HUD PROCESS_MODE_ALWAYS); เทสต์ phase3 เพิ่มเป็นชุดที่ 3 ของ 3D

### ระเบียบการตัดสินข้ามฉบับ

- เมื่อเอกสารขัดกันสำหรับโปรเจกต์ 3D: GDD_3DTD > GDD (2D) ตามหัวข้อ design; Architecture ของ 2D ใช้กับ 2D เท่านั้น ส่วน 3D จะเขียน Architecture ใหม่ที่ Phase TD-1 ผ่าน
- การ playtest ที่เก็บด้วย RunMetrics ช่วยให้เทียบ baseline ความยากของฉบับ 2D เป็นข้อมูลตั้งต้นของฉบับ 3D ได้

## Phase 3 — Progression และ production foundation ✅

- Salvage, meta unlocks ที่ไม่ทำให้ balance พัง, versioned atomic save
- data resources สำหรับ wave/enemy/weapon/upgrade
- test save migration, scene flow และ stress performance
- localization-ready strings ไทย/อังกฤษ

**ทำแล้ว:** `ProfileRepository` schema v3, temp + backup + migration/fallback, Salvage/codex/base barricade progression, data `.tres` สำหรับ enemies/waves/mission/weapon upgrades, ภาษาไทย/อังกฤษและ settings persistence

**ตรวจยืนยัน:** automated tests ครอบคลุม migration, backup recovery, newer-save protection, validation และ progression thresholds

## Phase 4 — Content + platform (implementation ready; target sign-off pending)

- เตรียม art/audio/UI polish และ production-ready data; เพิ่มภารกิจ/บอสหลังได้ผล playtest
- Windows export preset และ headless project-startup check; exported-build/clean-machine validation ยังรอ
- Android Arm64 preset มีไว้ใน repository แต่ Android-specific development/export/touch tuning ถูกพักไว้ตามลำดับความสำคัญปัจจุบัน
- accessibility, crash/error reporting และ release checklist

**ทำแล้ว:** responsive safe-area layout, large-text/reduce-flash, English/Thai font, focus navigation, ambient audio/audio buses, local rotating diagnostic log + interrupted-session marker, Windows/Android Arm64 export presets and PowerShell exporter, stress fixture (100 enemies + 200 projectiles), release checklist.

**ค้างที่ต้องใช้ environment/ผู้ทดสอบจริง:** Godot export templates (เครื่องนี้ยังไม่มี), Windows exported-build/clean-machine test, manual playtest และ FPS/accessibility verification บนอุปกรณ์เป้าหมาย. Android SDK/JDK/device validation รอจนกว่า core loop ผ่าน playtest. ห้ามนับ platform certification ว่าผ่านจนกว่าจะทดสอบจริง

## Fun-first iteration — active

- เปลี่ยน fantasy จากยานยิงเป็นผู้รอดชีวิตเดินเท้าป้องกัน Shelter จากฝูง Hollow
- ขยับซ้าย/ขวาและ auto-fire เหมือนเดิม; ทุก 100 Parts เลือกอัปเกรดปืนซ้ำได้สูงสุดเลเวล 6 หรือใช้ Emergency Blast
- ใช้ Salvage เสริม Barricade ได้สองระดับเพื่อเพิ่ม Integrity เริ่มต้นของรอบ
- ปรับ art, ฉาก, HUD และเรื่องให้เป็นแนวตั้งรับบนพื้น; ใช้ upgrade choices เป็นแกนการเติบโตระหว่างรอบ
- ทดสอบด้วยคีย์บอร์ด Windows และให้ผู้เล่นใหม่ลอง ก่อนปรับสมดุลหรือเพิ่มระบบฐานอื่น
- ยังไม่เพิ่ม hunger/crafting/ inventory, ภารกิจ หรือบอสใหม่จนกว่าจะได้ feedback จากผู้เล่นจริง
- Android work remains deferred; revisit after the Windows core-loop playtest.

## Playtest metrics ที่ควรเก็บ

- เวลาที่ผู้เล่นใช้จนเข้าใจว่าศัตรูจะ breach
- จำนวน breach/Integrity ที่เหลือในชัยชนะ
- ผู้เล่นเลือก Weapon Upgrade หรือ Emergency Blast เมื่อใด และเข้าใจผลลัพธ์หรือไม่
- จุดเวลาที่ผู้เล่นตาย/ออกจากเกม และระดับความยากที่รายงาน
- เฟรมเรต/จำนวน entity บน Windows เครื่องอ้างอิง

อย่าปรับ balance ด้วยค่าเฉลี่ยอย่างเดียว: สังเกตผู้เล่นที่ไม่รู้ genre และแยกปัญหา readability, control, difficulty ออกจากกัน

## Risks และวิธีลด

| ความเสี่ยง | ลดความเสี่ยง |
|---|---|
| ผู้เล่นใหม่ไม่เข้าใจการตั้งรับ | auto-fire, จำกัดแกน X, แสดงแนว breach ชัด และทดสอบกับผู้เล่นที่ไม่รู้ genre |
| อ่านกระสุนไม่ออก | จำกัดสี/เอฟเฟกต์, telegraph ด้วยรูปร่าง+motion, ลดรายละเอียดพื้นหลัง |
| ทางเลือก Parts ไม่สมดุล | playtest; ปรับ Parts reward และผลของ Weapon Upgrade/Emergency Blast |
| scope บานเป็น roguelite ใหญ่ | ล็อก MVP หนึ่ง arena/หนึ่งภารกิจ/หนึ่งบอสก่อนเพิ่ม meta/content |
| Android export ช้า | คง Android development/export ไว้หลัง Windows core loop ผ่าน playtest |
| asset tool ให้ผลไม่สม่ำเสมอ | อนุมัติ visual target ก่อนสร้างทั้งชุด; ตรวจทุก asset ใน Godot scene |
