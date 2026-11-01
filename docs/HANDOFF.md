# Handoff — พัฒนาต่อบนคอมพิวเตอร์เครื่องอื่น

## Repository และ path

- Repository: `https://github.com/nattawutvisayataksin/m-home-game.git`
- Clone หลังจากชุดงานนี้ถูก sync ขึ้น remote แล้ว; root repository คือ workspace หลัก
- Godot project อยู่ที่ `projects\last-light\project.godot`
- เปิด `README.md` และ `START_HERE.md` ก่อนเริ่มงาน
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
4. สำหรับ MCP: ติดตั้ง runtime ที่ MCP server ต้องการ (เช่น Node/uv ตาม config ของ server)
5. Android export ภายหลัง: Godot export templates รุ่นเดียวกัน, Android SDK/JDK; ไม่ต้องติดตั้งใน Phase 0

## ตรวจและรัน

จาก root repository บน Windows PowerShell:

```powershell
.\scripts\dev.ps1 -Action check
.\scripts\dev.ps1 -Action run
.\scripts\dev.ps1 -Action import
```

กำหนด `GODOT_PATH` เป็น path ของ executable Godot บนเครื่องนั้น หากไม่ได้อยู่ใน `PATH`:

```powershell
$env:GODOT_PATH = 'D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe'
.\scripts\dev.ps1 -Action check
```

แทน path ตัวอย่างด้วยตำแหน่งติดตั้งจริง ห้าม commit path นี้ลง source

## MCP และ skills ที่คงไว้

- `agent\skills\`, `.agents\skills\`, `.claude\`, `mcp-servers\` และ `opencode.json` เป็น tooling ไม่ใช่ game data
- `opencode.json` ปัจจุบันมี path executable/uv ที่เฉพาะเครื่อง; เครื่องใหม่ต้องปรับ local path ของ Godot และ Pixel-art MCP ให้ตรงเครื่องก่อนใช้
- อย่าลบหรือย้ายเครื่องมือเพื่อจัดโครงเกม; project asset และ source ใหม่ทั้งหมดอยู่ใต้ `projects\last-light\`
- Pixel-art MCP ใช้เมื่อ art brief ผ่านการตรวจ; Godot MCP ใช้เปิด/ตรวจ scene; Blender MCP เป็นทางเลือก ไม่ใช่ dependency ของการรันเกม

## ข้อกำหนดก่อนส่งงาน

- รัน `.\scripts\dev.ps1 -Action check` หลังเพิ่ม/ย้าย scene, resource หรือ script
- ทดสอบเปิดโปรเจกต์และดู error ใน Godot; checker ไม่แทน engine runtime test
- ไม่ commit `.godot/`, `build/`, keystore, password, export credential หรือข้อมูลส่วนตัว
- ทำ Windows build ก่อน แล้วจึงทดสอบ Android บนอุปกรณ์จริง; รายงานเวอร์ชันเครื่องมือ/ผลทดสอบจริง
- ตรวจ Git diff ก่อน commit ให้แน่ใจว่ามีเฉพาะการเปลี่ยนแปลงของโปรเจกต์ปัจจุบัน
