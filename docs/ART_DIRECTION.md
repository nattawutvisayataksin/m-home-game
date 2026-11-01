# Art Direction — LAST LIGHT

## เป้าหมายภาพ

ทำภาพ **pixel art survival เมืองพังที่อ่านง่ายก่อนสวยละเอียด**: ผู้เล่นคือมนุษย์เดินเท้าป้องกัน Shelter จากฝูงกลายพันธุ์ อารมณ์คือการตั้งรับในย่านที่ถูกทิ้งร้าง ไม่ใช่การขับยานยิงในอวกาศ

## รูปแบบภาพ

- 2D pixel art มุมมองกึ่งด้านบนของถนน/แนวรั้ว; ผู้เล่นมนุษย์อยู่ด้านล่าง ศัตรูบุกจากด้านบน
- logical canvas เริ่มที่ **360×640 (9:16)**; ใช้ integer-friendly scaling และ nearest filtering
- ตัวละคร/ศัตรูเริ่มทดสอบที่ 24–48 px สูง; projectile และไอคอนมี silhouette ชัดในขนาดเล็ก
- background ใช้ parallax น้อยชั้นและคอนทราสต์ต่ำ ไม่เลื่อนเร็วกว่าเป้าหมาย
- หลีกเลี่ยง texture รายละเอียดสูงใต้ combat lane และเอฟเฟกต์ที่บังสีเตือน

## Palette เริ่มต้น

| ใช้กับ | สีแนะนำ |
|---|---|
| ถนน/เงา | `#202722`, `#343A32` |
| กำแพง/สิ่งปลูกสร้าง | `#5B513C`, `#465044` |
| ผู้เล่น/อุปกรณ์ | olive `#5B704E`, khaki `#D8CDA6` |
| ศัตรู/อันตราย | infected green `#91A380`, rust `#A4483C` |
| Parts/คำเตือน | amber `#DAA453` |
| UI รอง | `#D8CDA6` |

ความหมายสีห้ามพึ่งสีอย่างเดียว: เตือน Dasher ด้วยรูปทรง/ทิศ/animation และ icon ประกอบ เพื่อรองรับผู้มีภาวะตาบอดสี

## ภาษา silhouette

- **ผู้เล่น:** ร่างมนุษย์สวมเสื้อเกราะซ่อมเอง ถือปืนไรเฟิล; silhouette แยกจากศัตรูชัด
- **Drifter:** ผู้ติดเชื้อเดินช้า แขนยื่นและก้าวหนัก
- **Skitter:** ผู้ติดเชื้อร่างเล็ก เคลื่อนส่ายและต่ำ
- **Dasher:** กลายพันธุ์ทรงพุ่ง มีท่าหมอบเตือนก่อนโจมตี
- **Bulwark:** กว้าง หนัก มีแผ่นเกราะเป็นชั้น
- **บอส:** silhouette กินพื้นที่แต่ไม่บัง HUD; phase ใหม่มีสี/รูปร่างเปลี่ยนชัด

## VFX และ readability

- กระสุนผู้เล่นอ่านเป็นกระสุนไรเฟิล/แสงปากกระบอก; Parts ใช้ amber
- การเตือนกระทบ Shelter แสดงเป็นแนวโจมตีบนพื้นอย่างชัดเจน
- feedback ปกติเป็นสะเก็ด/ฝุ่น; Emergency Blast/บอสใช้เอฟเฟกต์ใหญ่กว่า โดยมี Reduce Flashes
- จำกัดการกระพริบถี่และเต็มจอ; มี Reduce Flash และ Reduce Shake
- รักษาพื้นที่ HUD ด้านบนและ safe area ด้านล่างของมือถือ

## UI และ typography

- รูปทรงกรอบ UI เป็นแผงสนาม/ป้ายเตือนแนวป้องกัน; ไม่ใส่กรอบยานหรืออุปกรณ์อวกาศ
- ตัวเลข Shelter Integrity, Parts, เวลาคลื่น และการเตือนต้องอ่านได้ในหนึ่ง glance
- ใช้ containers/anchors; desktop จอ 16:9 แสดงแถบข้าง ไม่ขยาย playfield จนตำแหน่งศัตรูได้เปรียบ
- เลือก font ที่มี glyph ไทย/อังกฤษครบและตรวจการ export จริง; ห้ามสมมติว่า font default มีภาษาไทย

## Asset pipeline และการใช้เครื่องมือ

1. ทำ greybox จาก shape สีพื้นและตรวจความชัดที่ขนาด 360×640
2. ใช้ต้นฉบับ pixel art ใน `assets/art/` เป็น visual target; สร้างซ้ำได้จาก `scripts\generate_pixel_art.py`
3. ใช้ **Pixel-art MCP** ปรับ sprite เมื่อ visual target ผ่าน playtest; เก็บ PNG ต้นฉบับและ source/notes ที่จำเป็นใน `projects\last-light\assets\art\`
4. ใช้ **Blender MCP** เฉพาะเมื่อช่วยสร้าง reference/ฉาก parallax หรือภาพโปรโมต; ไม่เปลี่ยน gameplay ไป 3D
5. ใช้ **Godot MCP** ตรวจ scene, import, และจับภาพเทียบใน build; ตรวจ pixel filtering และ aspect ratio
6. เพิ่ม family/animation หลัง visual target ได้รับการยืนยันจากการทดสอบในฉากจริง

ทุก asset ต้องเป็นงานต้นฉบับหรือมี license ที่ตรวจสอบได้; Noto Sans Thai ที่ bundle มาใช้ SIL OFL (license copy อยู่ใน `assets\fonts\OFL.txt`)

## Audio direction

- Music: drone เมืองร้างและจังหวะ percussion เบา ๆ; เพิ่มแรงตึงตาม threat
- UI: click สั้นและชัด, charge-ready เป็นสัญญาณเสียงที่ไม่คล้าย warning ของศัตรู
- Combat: SFX แยกประเภท projectile/impact/enemy/breach; variation เล็กน้อยลดเสียงซ้ำเหมือนเครื่องจักร
- Bus ตั้งต้น: Master, Music, SFX, UI, Ambience, Voice; prototype มี ambient loop และ SFX สังเคราะห์
- ตรวจฟังทั้งหูฟังและลำโพงมือถือ ปรับระดับเสียงทุกหมวดได้
