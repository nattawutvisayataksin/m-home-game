# Handoff — พัฒนาต่อบนคอมพิวเตอร์เครื่องอื่น

## Repository และ path

- Repository: `https://github.com/nattawutvisayataksin/m-home-game.git`
- ใช้ root repository เป็น workspace หลัก; changes ของ session นี้ต้อง commit/push ก่อนเครื่องอื่นจะดึงได้
- เกมหลักที่กำลังพัฒนาต่อ (3D Tower Defense): `projects\last-light-3d\project.godot` — ใช้ `scripts\dev-3d.ps1` / `scripts\test-3d.ps1` (พารามิเตอร์เดียวกับด้านล่าง)
- เกม 2D playable reference (ห้ามแตะนอกจากระบบ metrics): `projects\last-light\project.godot` — ใช้ `scripts\dev.ps1` / `scripts\test.ps1`
- เอกสาร design และสถานะล่าสุด: `START_HERE.md`, `docs/AI_HANDOFF.md`, `docs/GDD_3DTD.md`; คู่มือผู้เล่นฉบับ 3D อยู่ที่ `docs/PLAYER_MANUAL_3D.md`
- เปิด `README.md` และ `START_HERE.md` ก่อนเริ่มงาน
- สำหรับงานภาพ ให้เริ่มจาก [ART_HANDOFF.md](./ART_HANDOFF.md) (ฉบับ 2D) และ [TD2_ASSET_PLAN.md](./TD2_ASSET_PLAN.md) (ธรรมชาติ 3D low-poly — asset suite สร้างครบแล้ว); ปรับ asset 3D เพิ่มได้ผ่าน Blender MCP ตาม workflow ในไฟล์นั้น
- path ใน source ใช้ `res://`; save ใช้ `user://`; ห้ามอ้าง `C:\Users\...` หรือ path เครื่องปัจจุบันในเกม

```powershell
git clone https://github.com/nattawutvisayataksin/m-home-game.git
Set-Location m-home-game
.\scripts\dev.ps1 -Action check
.\scripts\dev.ps1 -Action run
```

## สิ่งที่ต้องติดตั้ง

1. Godot **4.7.2 stable** (ให้ตรงกับ project skeleton)
2. Git
3. Python 3.10+ สำหรับ project checker (helper จะใช้ venv ของ Pixel-art MCP ถ้ามี; ถ้าไม่มีให้ติดตั้ง Python ไว้ใน PATH)
4. Python 3.10+ ใช้กับ project checker และ asset generators (standard library)
5. สำหรับ MCP: ติดตั้ง runtime ที่ MCP server ต้องการ (เช่น Node/uv ตาม config ของ server)
6. Android SDK/JDK ยังไม่ต้องติดตั้ง; งาน Android ถูกพักจนกว่า core loop บน Windows จะผ่าน playtest

## ตรวจและรัน

จาก root repository บน Windows PowerShell:

```powershell
.\scripts\dev.ps1 -Action check
.\scripts\dev.ps1 -Action run
.\scripts\dev.ps1 -Action import
.\scripts\test.ps1

# เกมหลัก (3D Tower Defense)
.\scripts\dev-3d.ps1 -Action check
.\scripts\dev-3d.ps1 -Action run
.\scripts\dev-3d.ps1 -Action import   # ต้องรันทุกครั้งหลังเพิ่ม class_name ใหม่ (global class cache)
.\scripts\test-3d.ps1                  # SceneTree suites 6 suites — พิมพ์ PHASE ... PASSED
```

กำหนด `GODOT_PATH` เป็น path ของ executable Godot บนเครื่องนั้น หากไม่ได้อยู่ใน `PATH`:

```powershell
$env:GODOT_PATH = 'D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe'
.\scripts\dev.ps1 -Action check
```

แทน path ตัวอย่างด้วยตำแหน่งติดตั้งจริง ห้าม commit path นี้ลง source

สร้าง build:

```powershell
.\scripts\export.ps1 -Platform Windows -Mode release
```

ไฟล์ output อยู่ใน `projects\last-light\build\`; directory นี้ถูก ignore. Android export และ keystore เป็นงานภายหลัง ไม่ใช่ขั้นตอนปัจจุบัน

## MCP และ skills ที่คงไว้

- `agent\skills\`, `.agents\skills\`, `.claude\`, `mcp-servers\pixelart-mcp\` และ `opencode.json` เป็น tooling; source ของ Pixel-art MCP อยู่ใน repository
- `.venv\`, Python cache และ nested `.git` metadata ไม่ถูก commit; ติดตั้ง `uv` และเปิด workspace จาก root เพื่อให้ `opencode.json` รัน MCP
- `opencode.json` ใช้ `npx`, `uv`, `uvx` และ `godot` จาก `PATH`; ติดตั้ง runtime เหล่านี้บนเครื่องใหม่ และเพิ่ม Godot 4.7.2 ลง `PATH` หากชื่อ executable ไม่ใช่ `godot`
- อย่าลบหรือย้ายเครื่องมือเพื่อจัดโครงเกม; project asset และ source ใหม่ทั้งหมดอยู่ใต้ `projects\last-light\`
- Pixel-art MCP ใช้เมื่อ art brief ผ่านการตรวจ; Godot MCP ใช้เปิด/ตรวจ scene; Blender MCP เป็นทางเลือก ไม่ใช่ dependency ของการรันเกม
- generated art/music/SFX อยู่ใน project; ใช้ `scripts\generate_pixel_art.py` และ `scripts\generate_sfx.py` เมื่อต้องสร้างซ้ำ
- ฟอนต์ Noto Sans Thai ใช้ SIL OFL; license copy อยู่ใน `projects\last-light\assets\fonts\OFL.txt`
- profile อยู่ใน `user://profile.json`; settings อยู่ใน `user://settings.cfg`; logs อยู่ใน `user://logs\`

## ข้อกำหนดก่อนส่งงาน

- รัน `.\scripts\dev-3d.ps1 -Action check` (หรือ `dev.ps1` สำหรับฉบับ 2D) หลังเพิ่ม/ย้าย scene, resource หรือ script; เพิ่ม `class_name` ใหม่ต้องรัน `-Action import` ก่อนเทสต์
- ทดสอบเปิดโปรเจกต์และดู error ใน Godot; checker ไม่แทน engine runtime test
- รัน `.\scripts\test-3d.ps1` ให้ผ่านครบทุก suite ก่อน commit งานที่เปลี่ยน gameplay
- **ห้าม capture หน้าจอเดสก์ท็อปโดยรอบ** — ตรวจ visual เฉพาะ in-engine capture ตามแบบอย่าง `projects/last-light-3d/tests/dev_title_selfshot.gd`
- งานที่เปลี่ยน behavior ของเกมเขียน dev log entry ที่ `docs/NIGHTLY_DEV_LOG.md`
- ไม่ commit `.godot/`, `build/`, keystore, password, export credential, ภาพ selfshot หรือข้อมูลส่วนตัว
- ทดสอบ TD loop บน Windows ตาม [PLAYTEST_PLAN.md](./PLAYTEST_PLAN.md) หัวข้อ 3D; ค่อยกลับมาทำ Android หลัง core loop ผ่าน playtest
- ตรวจ Git diff ก่อน commit ให้แน่ใจว่ามีเฉพาะการเปลี่ยนแปลงของโปรเจกต์ปัจจุบัน
