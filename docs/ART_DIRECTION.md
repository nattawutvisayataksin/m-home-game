# Art Direction — LAST LIGHT

## เป้าหมายภาพ

ทำภาพ **pixel art sci-fi ที่อ่านง่ายก่อนสวยละเอียด**: ฉากมืดสงบเพื่อให้ผู้เล่นเห็นศัตรู กระสุน สัญญาณเตือน และแนว Beacon ได้ชัด อารมณ์คือแสงสุดท้ายในเมืองที่กำลังมืดลง

## รูปแบบภาพ

- 2D pixel art มุมมองด้านข้าง/กึ่งด้านบนแบบอ่านเป็นสนามยิงแนวตั้ง; ศัตรูเคลื่อนจากบนลงล่าง
- logical canvas เริ่มที่ **360×640 (9:16)**; ใช้ integer-friendly scaling และ nearest filtering
- ตัวละคร/ศัตรูเริ่มทดสอบที่ 24–48 px สูง; projectile และไอคอนมี silhouette ชัดในขนาดเล็ก
- background ใช้ parallax น้อยชั้นและคอนทราสต์ต่ำ ไม่เลื่อนเร็วกว่าเป้าหมาย
- หลีกเลี่ยง texture รายละเอียดสูงใต้ combat lane และเอฟเฟกต์ที่บังสีเตือน

## Palette เริ่มต้น

| ใช้กับ | สีแนะนำ |
|---|---|
| ฉากลึก | `#0B1020`, `#121C31` |
| เมือง/โครงสร้าง | `#25364A`, `#46536A` |
| ผู้เล่น/พลังที่เป็นมิตร | cyan `#54E6E0`, ขาวนวล `#E5F4F2` |
| ศัตรู/อันตราย | coral `#FF6D69`, amber `#FFC857` |
| พลัง Resonance | violet `#B18CFF` |
| UI รอง | `#AFC2D5` |

ความหมายสีห้ามพึ่งสีอย่างเดียว: เตือน Dasher ด้วยรูปทรง/ทิศ/animation และ icon ประกอบ เพื่อรองรับผู้มีภาวะตาบอดสี

## ภาษา silhouette

- **ผู้เล่น:** ลิ่ม/ป้อมแคบ หันขึ้น มี core สี cyan และจุดศูนย์ยิงชัด
- **Drifter:** รูปทรงกลม/ก้อนใหญ่ สมมาตร; จุดอ่อนกลางลำตัว
- **Skitter:** ปีกไม่สมมาตรและมี trail ด้านข้าง
- **Dasher:** แคบและชี้ลง มีวง telegraph ที่ขยายก่อนพุ่ง
- **Bulwark:** กว้าง หนัก มีแผ่นเกราะเป็นชั้น
- **บอส:** silhouette กินพื้นที่แต่ไม่บัง HUD; phase ใหม่มีสี/รูปร่างเปลี่ยนชัด

## VFX และ readability

- กระสุนผู้เล่นเป็นสี cyan สว่าง; projectile อันตรายใช้ amber/coral และรูปร่างต่างกัน
- การเตือนกระทบ Beacon แสดงเป็นแถบ/วงกระพริบล่วงหน้าอย่างน้อยช่วงที่ตอบสนองได้
- feedback ปกติเป็นประกายเล็กและ hit flash; Pulse/บอสใช้เอฟเฟกต์ใหญ่กว่า แต่ลดความสว่าง/สั่นได้
- จำกัดการกระพริบถี่และเต็มจอ; มี Reduce Flash และ Reduce Shake
- รักษาพื้นที่ HUD ด้านบนและ safe area ด้านล่างของมือถือ

## UI และ typography

- รูปทรงกรอบ UI เป็นแผงอุปกรณ์วิทยุ/มาตรวัด Beacon; ไม่ใส่กรอบตกแต่งซับซ้อน
- ตัวเลข Integrity, Resonance, เวลาคลื่น และการเตือนต้องอ่านได้ในหนึ่ง glance
- ใช้ containers/anchors; desktop จอ 16:9 แสดงแถบข้าง ไม่ขยาย playfield จนตำแหน่งศัตรูได้เปรียบ
- เลือก font ที่มี glyph ไทย/อังกฤษครบและตรวจการ export จริง; ห้ามสมมติว่า font default มีภาษาไทย

## Asset pipeline และการใช้เครื่องมือ

1. ทำ greybox จาก shape สีพื้นและตรวจความชัดที่ขนาด 360×640
2. ทำ visual target ชุดเล็ก: player, Drifter, projectile ฝ่ายละหนึ่ง, background strip, HUD icon
3. ใช้ **Pixel-art MCP** สร้าง/แก้ sprite และทดลอง palette; เก็บ PNG ต้นฉบับและ source/notes ที่จำเป็นใน `projects\last-light\assets\art\`
4. ใช้ **Blender MCP** เฉพาะเมื่อช่วยสร้าง reference/ฉาก parallax หรือภาพโปรโมต; ไม่เปลี่ยน gameplay ไป 3D
5. ใช้ **Godot MCP** ตรวจ scene, import, และจับภาพเทียบใน build; ตรวจ pixel filtering และ aspect ratio
6. ทำชุด asset ต่อเมื่อ visual target ได้รับการยืนยันจากการทดสอบในฉากจริง

ทุก asset ต้องเป็นงานต้นฉบับหรือมี license ที่ตรวจสอบได้; เก็บ `LICENSES.md`/เครดิตเมื่อเริ่มนำ asset ภายนอกเข้ามา

## Audio direction

- Music: ambient synth บาง ๆ; เพิ่ม percussion/ชั้นจังหวะตาม threat
- UI: click สั้นและชัด, charge-ready เป็นสัญญาณเสียงที่ไม่คล้าย warning ของศัตรู
- Combat: SFX แยกประเภท projectile/impact/enemy/breach; variation เล็กน้อยลดเสียงซ้ำเหมือนเครื่องจักร
- Bus ตั้งต้น: Master, Music, SFX, UI, Ambience, Voice
- ตรวจฟังทั้งหูฟังและลำโพงมือถือ ปรับระดับเสียงทุกหมวดได้
