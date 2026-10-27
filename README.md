# Kick Hero Arena ⚽

> เกมฟุตบอล 1v1 มุมมอง **top-down bird's-eye** พิกเซลอาร์ต สไตล์ arena แบบ Head-Soccer: กำแพงล้อมสนามทุกด้าน บอลไม่มีทางออก ผู้เล่นคุม Hero 1 คน ส่วนผู้รักษาประตูเป็น Auto — เตะ แย่ง เลี้ยง เพื่อยิงเข้าประตูฝั่งตรงข้ามก่อนคู่แข่ง

- **Engine:** Godot **4.7.2 stable** (GL Compatibility)
- **ภาษาสคริปต์:** GDScript
- **จอฐาน:** 480×270 logical (scale 3×, nearest → คมแบบพิกเซลอาร์ต)
- **สไปรต์:** สร้าง/แต่งด้วย pixelart-mcp + pixellab AI, palette Sweetie 16

## ✨ ฟีเจอร์ปัจจุบัน

| ระบบ | รายละเอียด |
|---|---|
| **Possession บอลติดตัว** | เดินชนบอลว่าง = ครอง, บอลติดตัวที่ปลายทิศเล็ง, โดนแย่ง = stun |
| **เตะ + สกิลพิเศษ** | ยิงตามทิศเล็ง (แรง 260) / สกิลแรงสุด 430 (cooldown 2.5s) |
| **Sprint + Stamina** | ×1.75 ความเร็ว, ใช้/ฟื้นสไตมิน่า, โดน stun ห้าม sprint |
| **AI 3 ระดับ** | Easy / Normal / Hard + โหมด Local (คน 2) + Training (ฟรีสไตล์ ไม่มีคู่) |
| **GK Auto** | อ่านจุดตัดลูกยิง + ไดฟ์ล็อกเป้า + ผลักบอลออกจากกรอบเมื่อบอลมากอด |
| **FSM แข่งครบรอบ** | KICKOFF → PLAY (90 วิ/ชนะ 3 ประตู) → GOAL → END + HUD สกอร์/เวลา/สไตมิน่า |

## 🎮 คีย์ควบคุม (ย่อ — เต็มอยู่ใน docs/MANUAL.md)

| | ผู้เล่น 1 (น้ำเงิน ซ้าย) | ผู้เล่น 2 (แดง ขวา) |
|---|---|---|
| วิ่ง 8 ทิศ | `W A S D` | ลูกศร |
| เตะ/ยิง/แย่ง | `C` | `K` |
| สกิลพิเศษ | `V` | `L` |
| Sprint | `Space` | `Shift` |

## 🚀 วิธีรัน

1. ติดตั้ง [Godot 4.7.2](https://godotengine.org/download) (winget: `GodotEngine.GodotEngine`)
2. เปิดโปรเจกต์: โฟลเดอร์ root คือ **`projects/my-game/`**
3. จาก command line:

```powershell
# เล่นเกมจริง (หน้าต่าง)
& Godot_v4.7.2-stable_win64_console.exe --path projects/my-game

# import รอบแรกหลัง clone (จำเป็น — สร้าง class cache)
& Godot_v4.7.2-stable_win64_console.exe --headless --path projects/my-game --import
```

## 🧪 เทสต์ headless

```powershell
# สโมคเทส 400 เฟรม
& $gd --headless --path projects/my-game res://scenes/arena.tscn --quit-after 400 -- training

# แมตช์เต็มด้วย AI (ห้ามลืม --quit-after; ตัดค่าได้ easy|normal|hard)
& $gd --headless --path projects/my-game res://scenes/arena.tscn --quit-after 6000 -- hard
```

อ่านผลจาก stdout: `[ARENA] GOAL`, `[GK] SAVE`, `[GK] CLEAR`, `[ARENA] MATCH END`, ไม่นับเป็นผ่านหากมี `SCRIPT ERROR`

> ⚠ **ห้ามวัดสมดุลด้วยโหมด fast (time_scale ×4)** — physics พลาด เกิดบอลทะลุ GK ได้ ใช้เวลาจริงเท่านั้น

## 📁 เอกสารและโครงสร้าง

```
m-home-game/
├── ReadFirst.md                  # Master log — สถานะล่าสุด / เครื่องมือ / MCP ทั้งหมด
├── docs/
│   ├── HANDOFF.md                # ขั้นตอนย้ายเครื่อง + สถานะงานปัจจุบัน
│   ├── ARCHITECTURE.md           # โครง scene tree / possession / FSM / แผน online
│   └── MANUAL.md                 # คู่มือเล่น + คีย์ครบ + วิธีเทสต์
└── projects/my-game/
    ├── scenes/                   # เมนู / arena / hero / gk / ball
    ├── scripts/                  # game.gd (Autoload โหมด) / arena / hero / ball / gk / ...
    ├── assets/                   # สไปรต์ที่เกมใช้จริง (6 ไฟล์)
    └── assets_legacy/            # ต้นฉบับ/เวอร์ชันเก่า (gdignore — ไม่ถูก import)
```

| เอกสาร | เรื่อง |
|---|---|
| `ReadFirst.md` | เริ่มอ่านไฟล์นี้ก่อน — สถานะ + การตั้งค่าทุกอย่าง |
| `docs/HANDOFF.md` | ย้ายเครื่อง / clone ใหม่ / checklist |
| `docs/ARCHITECTURE.md` | สถาปัตยกรรมระบบเกม |
| `docs/MANUAL.md` | วิธีเล่นครบทุกคีย์ + เทสต์ |
| `projects/my-game/DESIGN.md` | ดีไซน์เกม + Hero ชนิดพิเศษ + Changelog สมดุล |

## 🗺 แผนถัดไป

- [ ] BALANCE7 — จูนยอดประตู easy/normal (เป้า 1–2 ประตู/แมตช์)
- [ ] Online 1v1 sync (โครง host/join พร้อม — เหลือ rpc input/state)
- [ ] Export Windows + Web
- [ ] ไอเทมกลางสนาม + Ultimate ต่อ Hero
- [ ] เสียง + อนิเมชันเดิน/เตะ

---

*สร้างเล่นกับ OpenCode agent · เซฟลง GitHub เรียบร้อยทุกรอบงาน*
