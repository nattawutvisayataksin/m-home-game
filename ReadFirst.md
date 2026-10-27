# ReadFirst

> ⚠️ **เอกสารสำคัญ — กรุณาอ่านก่อน**

## Git / Repository ของ Project

| รายการ | ข้อมูล |
|---|---|
| **ชื่อ Project** | m-home-game |
| **Repo URL (HTTPS)** | https://github.com/nattawutvisayataksin/m-home-game.git |
| **Clone URL (HTTPS)** | https://github.com/nattawutvisayataksin/m-home-game.git |
| **Clone URL (SSH)** | git@github.com:nattawutvisayataksin/m-home-game.git |
| **หน้า Web** | https://github.com/nattawutvisayataksin/m-home-game |
| **Owner** | nattawutvisayataksin |
| **สถานะ** | Public |
| **Default Branch** | `main` |
| **สร้างเมื่อ** | 2026-10-27 |
| **เนื้อหา** | ยังว่าง (empty repo — ไม่มี commit แรกยัง) |

### คำสั่งเบื้องต้น

```bash
# Clone
git clone https://github.com/nattawutvisayataksin/m-home-game.git

# หรือเริ่มจากโฟลเดอร์เดิม (เชื่อม remote ให้โฟลเดอร์ปัจจุบัน)
git init
git branch -M main
git remote add origin https://github.com/nattawutvisayataksin/m-home-game.git
git add .
git commit -m "first commit"
git push -u origin main
```

## โครงสร้างเบื้องต้นของ Project (สำหรับทำ Game)

> ✅ **สถานะ:** สร้างโฟลเดอร์นี้บนเครื่องจริงแล้ว (โฟลเดอร์ว่างมี `.gitkeep` ไว้ให้ git ติดตาม) — ที่นี่ `m-home-game` คือโฟลเดอร์ `game-dev/` โดยตรง

```
game-dev/
├── mcp-servers/              # MCP servers ที่ใช้ช่วยพัฒนาเกม
│   ├── pixelart-mcp/         #   - สร้าง pixel art
│   ├── godot-mcp/            #   - เชื่อมกับ Godot engine
│   └── blender-asset-mcp/    #   - จัดการ asset ผ่าน Blender
├── assets-library/           # คลัง asset กลาง
│   ├── sprites/
│   ├── tilesets/
│   ├── audio/
│   ├── 3d-models/
│   └── textures/
└── projects/
    └── my-game/              # ตัวเกมหลัก
        ├── scenes/
        ├── scripts/
        ├── assets/
        └── audio/
```

### สรุปการใช้งานแต่ละส่วน

1. **mcp-servers/** — เครื่องมือแบบ MCP (Model Context Protocol) 3 ตัว: สร้าง pixel art, ควบคุม Godot, และจัดการ 3D asset ผ่าน Blender
2. **assets-library/** — เก็บ asset ที่ผลิตได้ซ้ำ (sprite, tileset, เสียง, โมเดล 3D, texture) แยกไว้ต่างหากจากตัวเกม เพื่อนำกลับมาใช้ซ้ำได้
3. **projects/my-game/** — ตัว project เกมจริง แยก scenes / scripts / assets / audio ตามมาตรฐาน Godot

## MCP Servers

### godot-mcp ✅ (ติดตั้งแล้ว)

| รายการ | ข้อมูล |
|---|---|
| **แพ็กเกจ** | `@coding-solo/godot-mcp` v0.1.1 (รันผ่าน `npx -y`) |
| **โหมด** | local (stdio) — เขียนไว้ใน `opencode.json` ของ project นี้ |
| **Godot Engine** | v4.7.2 stable (ติดตั้งผ่าน winget, id `GodotEngine.GodotEngine`) |
| **GODOT_PATH** | `C:\Users\admin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe` |
| **สถานะ** | เชื่อมต่อสำเร็จ — ใช้งานได้ 14 tools |

**Tools ที่ใช้ได้:** `create_scene`, `add_node`, `load_sprite`, `save_scene`, `run_project`, `stop_project`, `get_debug_output`, `get_godot_version`, `get_project_info`, `list_projects`, `export_mesh_library`, `get_uid`, `update_project_uids`

**หมายเหตุ:** โฟลเดอร์ `mcp-servers/godot-mcp/` เก็บโน้ต/คอนฟิกประกอบ (ตัว server จริงรันผ่าน npx ไม่ต้อง clone)

### pixelart-mcp ✅ (ติดตั้งแล้ว)

| รายการ | ข้อมูล |
|---|---|
| **แหล่งที่มา** | https://github.com/light-vp/pixelart-mcp (clone อยู่ที่ `mcp-servers/pixelart-mcp/`) |
| **รันผ่าน** | `uv --directory mcp-servers/pixelart-mcp run -m pixelart_mcp` |
| **สภาพแวดล้อม** | uv 0.13.6 + CPython 3.12.16 (pin ไว้ใน `.python-version` — เวอร์ชันสูงกว่านี้จะพาง build ล้มเหลว) |
| **สถานะ** | เชื่อมต่อสำเร็จ — ใช้งานได้ 39 tools ✓ (ทดสอบวาด canvas จริงแล้ว) |
| **ข้อควรจำ** | วาดด้วย `pixel_batch` เป็นหลัก, เรียก `pixel_guide` เป็น playbook, ส่งออก GIF/spritesheet สำหรับเกมได้ |

**Tools กลุ่มหลัก:** craft (ramp/shade/gradient/palette/lint), วาด (canvas/line/rect/ellipse/flood fill/sprite outline), ปรับ canvas (copy/shift/scale/transform), อนิเมชัน (rig + motion → GIF/spritesheet), ตรวจและส่งออก (view/info/export PNG)

### blender-asset-mcp ✅ (ติดตั้งและเชื่อมต่อสำเร็จ)

| รายการ | ข้อมูล |
|---|---|
| **แหล่งที่มา** | https://github.com/yi00it/blender-asset-mcp — รันผ่าน `uvx --python 3.12 --from git+... blender-asset-mcp` (ไม่ต้อง clone) |
| **Blender** | v5.2.3 LTS ติดตั้งผ่าน winget — `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| **Add-on AI Bridge** | ติดตั้งแล้วที่ `%APPDATA%\Blender Foundation\Blender\5.2\extensions\user_default\ai_bridge` (จาก release zip v1.0.0) — enable + Start Bridge อัตโนมัติผ่านสคริปต์ตอนเปิด Blender |
| **สถานะ** | เชื่อมต่อสำเร็จ — ใช้งานได้ **126 tools** ✓ (`ping_blender` ตอบ bridge_version 1.0.0) |

**ข้อควรจำ:** ถ้า `bridge_unreachable` — เปิด Blender แล้วกด **N** ใน 3D viewport → แท็บ **AI Bridge** → กด **Start Bridge** (หรือใช้สคริปต์ `start_aibridge.py` ที่ติดอยู่) ตัว bridge ทำงานบน localhost:9876 เท่านั้น และ export/previews อยู่ใน `~/blender-asset-mcp/workspace`

> 💡 ถ้าจะให้ bridge start เองทุกครั้ง: เปิด Blender → AI Bridge tab → เปิดติ๊ก **Start bridge when Blender loads** ใน Add-on preferences

## Gamedev Skills ✅ (ติดตั้งแล้ว 77 skills)

- **ที่มา:** [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (repo นี้เป็น skills ใช้กับ agent ได้หลายตัว: OpenCode, Claude, Copilot, Gemini CLI, Antigravity)
- **ติดตั้งที่:** `.agents/skills/` ใน project นี้ (OpenCode อ่านจากที่นี่โดยตรง, Source: local)
- **ตัวเริ่มต้น:** ใช้ skill **`router`** ก่อนเสมอ เมื่อไม่แน่ใจว่าหน้างานควรใช้ skill ไหน — มันจะ detect engine + task แล้วชี้ต่อ

### กลุ่ม skills สนใจสำหรับ project นี้ (Godot + pixel art + Blender)

| กลุ่ม | Skills |
|---|---|
| Godot 4.7 | `godot-gdscript`, `godot-nodes-scenes`, `godot-2d-movement`, `godot-3d-essentials`, `godot-animation`, `godot-physics`, `godot-tilemap`, `godot-ui-control`, `godot-audio`, `godot-shaders`, `godot-resources`, `godot-signals-groups`, `godot-multiplayer`, `godot-export`, `godot-csharp`, `godot-gdscript-headless-testing` |
| สายงาน | `create-game-assets`, `game-feel`, `game-ui-ux`, `game-ai`, `ai-behavior-trees-utility-ai`, `camera-systems`, `input-systems`, `audio-design`, `dialogue-systems`, `level-design`, `performance-optimization`, `physics-tuning`, `save-systems`, `shader-programming`, `procedural-gen`, `prototype-fast` |
| ประเภทเกม | `platformer`, `roguelike`, `rpg`, `tower-defense`, `puzzle`, `fps-shooter`, `card-game`, `visual-novel`, `survival-crafting` |
| จัดส่ง | `game-jam`, `itch-publish`, `steam-publish` |
| Engine อื่น | unity-* (6), unreal-* (6), roblox-* (5), phaser/pixi/three.js/bevy/ebitengine/defold/love2d/pygame |

> **หมายเหตุการอัปเดต:** skills เหล่านี้โหลดด้วยการ copy ตรงจาก repo (เพราะ `npx skills` CLI โดน reload ตัดขาดกลางคันบนเครื่องนี้) — เมื่อต้องการอัปเดตให้ clone repo ใหม่แล้ว copy ทับ `.agents/skills/` ได้เลย

> 📚 **เอกสารต่อ (ลดลงลึก):** `docs/HANDOFF.md` (ย้ายเครื่อง/ขั้นตอนตั้งค่า) · `docs/ARCHITECTURE.md` (ระบบ possession/FSM/แผน online) · `docs/MANUAL.md` (คีย์/โหมด/วิธีเทสต์)

## Kick Hero Arena — ความคืบหน้า (Vertical slice)

**เอกสารออกแบบ:** `projects/my-game/DESIGN.md` (อาชีพ Hero ต่าง ๆ, สนามกำแพงเด้ง, GK auto, โหมด online/AI/training)

| งาน | สถานะ |
|---|---|
| **Pivot มุมมอง: side-view → Bird's Eye (top-down)** — บอลไม่มีโน้มถ่วง (gravity_scale=0, linear_damp=0.45 ให้บอลค่อยช้าลง), Hero เดิน 8 ทิศ + aim = ทิศวิ่งล่าสุด + sprite หมุนตามที่เล็ง, GK เฝ้าช่องประตู y 112–158 | ✅ (hero.gd / ball.gd / arena.tscn) |
| สนาม top-down 480×270: กำแพงซ้าย/ขวาแยกชิ้นเว้นช่องประตู 62px + back net, Goal Area ที่ x=0/480, จุดรีเซ็ตบอลกลางสนาม (240,135) | ✅ |
| Sprite ทุกชิ้นปรับสวยงามด้วย pixelart-mcp (repo davidkim9/pixel-art-mcp — มีตั้งแต่แรก): shading แบบกำหนด ramp เองด้วย sweetie16, outline solid 1px, ball ทรงกลมมี crescent shading + pentagon, สนามลายหญ้าถี่ 24px + จุดหญ้า texture + กำแพง bevel + ตาข่ายทแยง, เพิ่ม shadow.png (เงาใต้ตัว/บอล) — lint score 90 ทุกชิ้น, ตรวจภาพจริง + ascii ทุกรอบ | ✅ |
| Arena: กำแพงเด้งบอลทุกด้าน + ประตู 2 ฝั่ง + สกอร์ HUD (ชนะ 3 ประตู) | ✅ |
| Hero controller: เดิน 8 ทิศ / เตะตามทิศเล็ง / สกิลพิเศษแรงสุด (cooldown 2.5s) / ดริบเบิลเดินชนบอล | ✅ (scripts/hero.gd) |
| **Possession (บอลติดตัว)** — เดินชนบอลว่าง = ครอง (≤15px), บอลติดตัวที่ aim×11px, เตะ C/K หรือสกิล V/L = ยิงหรือแย่ง, โดนแย่ง = เจ้าของเดิม stun 0.45s, ล็อกครองใหม่ 0.35s หลังเตะ | ✅ (ball.gd + hero.gd wired เต็มระบบ) |
| **Sprint + Stamina** — P1 Space / P2 Shift (ลง input map), ×1.75 speed, drain 0.85/s regen 0.55/s, โดน stun = วิ่งช้า 0.55× และห้าม sprint; HUD Stamina1/2 ProgressBar + AI ใช้ sprint/steal ด้วย | ✅ |
| เมนูหลัก 6 ปุ่ม (Local / AI 3 ระดับ / Training / Online) + Autoload Game (โหมด + cmdline `-- easy|normal|hard|training` สำหรับเทสต์) + Online menu (Host/Join ws://:8910) | ✅ (online sync ยังตัดต่อ — ดู docs/ARCHITECTURE.md §6) |
| จังหวะแข่ง FSM: KICKOFF(นับ 3s) → PLAY (90s/3 ประตู) → GOAL → END (R ย้อม/Esc เมนู) + Training โหมด (ไม่มีคู่, Infinity timer, ประตูสองฝั่งนับได้) + บันทึก `[ARENA]` headless logs | ✅ (arena.gd) |
| เอกสารย้ายเครื่อง: docs/HANDOFF.md + ARCHITECTURE.md + MANUAL.md (คุมลักษณะ/เทสต์/คำสั่งทั้งหมด) | ✅ |
| คุณภาพ: checker 0 errors (25 ไฟล์) + headless import/parse สะอาด | ✅ |
| Online 1v1 sync เต็ม / Export (Windows + Web) / ไอเทม + Ultimate ต่อ Hero / เสียง + อนิเมชันเดินเตะ | 🔜 todo-later (ลำดับใน docs/HANDOFF.md §5) |

> เทคนิค: build ตรวจด้วย `uv run python .agents/skills/godot-nodes-scenes/scripts/check_godot_project.py projects/my-game` + รอบ import แรกต้องใช้ `--import` ก่อน (class cache ของ `class_name Ball` ถึงจะติด) จากนั้นรัน `--headless --quit` เพื่อคัดกรอง parse error

## เครื่องมือที่ติดตั้งเพิ่มระหว่างเซ็ตอัป

| เครื่องมือ | เวอร์ชัน | เหตุผล |
|---|---|---|
| Git | 2.56.0 | เดิมเครื่องไม่มี git — ใช้ clone + push |
| uv | 0.13.6 | รัน MCP ฝั่ง Python (pixelart, blender-asset) |
| Godot Engine | 4.7.2 stable | ให้ godot-mcp ใช้งาน |
| Blender | 5.2.3 LTS + AI Bridge 1.0.0 | ให้ blender-asset-mcp ใช้งาน |
| Node.js | v24.22.1 (มีอยู่แล้ว) | รัน godot-mcp / skills CLI |
