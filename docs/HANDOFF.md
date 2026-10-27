# HANDOFF — ต่องาน Kick Hero Arena บนเครื่องอื่น

> อ่านไฟล์นี้ก่อน เมื่อย้ายไปทำต่อบนเครื่องใหม่ / ให้ agent ตัวใหม่รับงานต่อ

## 1. ข้อมูลโปรเจกต์

| รายการ | ค่า |
|---|---|
| ชื่อเกม | Kick Hero Arena (ฟุตบอล 1v1 มุมมอง top-down bird's-eye) |
| Engine | Godot **4.7.2 stable** (GL Compatibility, render gl_compatibility) |
| โฟลเดอร์โปรเจกต์ | `projects/my-game/` (root ของ Godot project คือโฟลเดอร์นี้) |
| Repo | https://github.com/nattawutvisayataksin/m-home-game.git (**ยังไม่ได้ git init / push จากเครื่องนี้ — ทำทันทีแรกพอย้ายเครื่อง**) |
| จอฐาน | viewport 480×270, window 1440×810, stretch `canvas_items` keep, nearest filter, snap_2d_transforms_to_pixel |

## 2. เช็กลิสต์ตั้งเครื่องใหม่

```
1. ติดตั้ง Godot 4.7.2 → winget install GodotEngine.GodotEngine
   (ต้องมีไฟล์ Godot_v4.7.2-stable_win64_console.exe สำหรับรัน headless)
2. ติดตั้ง uv → winget install astral-sh.uv          (ใช้รัน checker + pixelart-mcp)
3. ติดตั้ง Node.js ≥ 22                              (ใช้รัน godot-mcp ผ่าน npx)
4. ติดตั้ง Git                                       (Clone + commit + push)
5. git clone https://github.com/nattawutvisayataksin/m-home-game.git
6. ตั้ง opencode.json ให้ MCP 3 ตัว (godot / pixelart / blender) — ดู ReadFirst.md หัวข้อ MCP Servers
7. รัน import รอบแรก:   godot --headless --path projects/my-game --import
   ⚠ การ import รอบแรก "จำเป็น" — เพื่อ cache class_name (Ball, Hero) ไม่งั้นรันแล้ว script error
```

## 3. คำสั่งตรวจ/รันที่ใช้ประจำ (Windows PowerShell)

```powershell
$gd = "<path>\Godot_v4.7.2-stable_win64_console.exe"
$proj = "projects\my-game"

# ตรวจโครงสร้าง .tscn/.gd ทุกไฟล์ (ต้อง 0 errors)
uv run python .agents/skills/godot-nodes-scenes/scripts/check_godot_project.py $proj

# คัดกรอง parse error
& $gd --headless --path $proj --quit

# เทสต์แมตช์เต็มทีละโหมด (ประมาณ 100 วิ ต่อโหมด, หยุดหลัง 6000 เฟรม)
& $gd --headless --path $proj "res://scenes/arena.tscn" --quit-after 6000 -- easy
& $gd --headless --path $proj "res://scenes/arena.tscn" --quit-after 6000 -- normal
& $gd --headless --path $proj "res://scenes/arena.tscn" --quit-after 6000 -- hard
& $gd --headless --path $proj "res://scenes/arena.tscn" --quit-after 1200 -- training

# เตะเกมจริง (หน้าต่าง)
& $gd --path $proj
```

> ⚠ ดีบักจาก stdout: มี `[ARENA] ...` เฉพาะตอน headless — คาดหวังบรรทัด `ARENA READY`, `KICKOFF → PLAY`, `GOAL →`, `MATCH END` ก่อนจบ
> ⚠ **ห้ามรัน headless โดยไม่ใส่ `--quit-after`** — แมตช์ไม่หมดเอง จะค้างตลอดไป

## 4. สำคัญที่ต้องรู้ก่อนแก้โค้ด

1. **Autoload `Game`** (`scripts/game.gd`) อ่านโหมดจาก `OS.get_cmdline_user_args()` ที่ `%1` = mode (`local|easy|normal|hard|training`) ก่อนเปลี่ยนซีน ระบบเทสต์ทั้งหมดไหลผ่านไฟล์นี้
2. **possession คือหัวใจ** — ดู `docs/ARCHITECTURE.md` §2 ก่อนแตะ `ball.gd` / `hero.gd` เด็ดขาดห้ามกลับไป logic "เตะแล้วบอลไปเลย" แบบเก่า
3. **พาธ node ในเมนู**: ปุ่มอยู่ใต้ `Menu/` ดังนั้น `get_node("Menu/BtnLocal")` ฝั่ง online_menu มีปุ่ม `BtnBack` อยู่ "นอก" กล่อง Menu
4. **ตำแหน่งสนาม**: ประตูซ้าย x=0 / ขวา x=480, แนวกลาง y=135, ช่องประตูสูง 62px (104..165), เริ่มบอล (240,135)
5. ค่า ratio ใน tscn แก้ได้เฉพาะบาง property ที่ export ไว้ (hero: run_speed, kick_power, sprint_*, ai_level, attack_left / gk: patrol_min_y, patrol_max_y / arena: player_id, skin ของ Hero2)

## 5. สถานะปัจจุบัน (ณ ย้ายเครื่อง)

✅ เสร็จ: สนาม top-down + ฟิสิกส์บอล + possession บอลติดตัว + sprint/stamina + steal + AI 3 ระดับ + Training + เมนูเลือกโหมด + HUD คะแนน/เวลา/สไตมิน่า + สไปรต์/สนามผ่าน lint 90+ ทุกชิ้น

⏳ ค้าง ทำต่อตามลำดับ:
1. **Online 1v1 sync** — ดู ARCHITECTURE doc §5 (ส่วนของ `_setup_online` / `remote_control` เตรียมไว้แล้ว)
2. **Export** Windows + Web (install export templates ก่อน)
3. ไอเทมกลางสนาม + Ultimate ต่อ Hero ต่างชนิด (DESIGN.md §สร้างความรู้สึก)
4. เสียง (SFX เตะ/ประตู + มิวสิก) + animation frames วิ่ง/เตะ
5. ✅ git init → commit → push สำเร็จแล้ว (2026-10-27) — ทำงานต่อบนเครื่องใหม่ด้วย `git clone`

## 6. เอกสารลูก

| ไฟล์ | เก็บเรื่อง |
|---|---|
| `ReadFirst.md` (root) | Master log — สถานะล่าสุด/เครื่องมือ/MCP ทั้งหมด |
| `docs/ARCHITECTURE.md` | โครงสร้าง scene tree / ระบบ possession / FSM / แผน online |
| `docs/MANUAL.md` | วิธีเล่น/คีย์ทั้งหมด/โหมด/วิธีเทสต์ |
| `projects/my-game/DESIGN.md` | ดีไซน์เกม (Hero ชนิด, สนาม, โหมด) |
