# Architecture — LAST LIGHT

## 1. หลักการ

- ใช้ **Godot 4.7.2, GDScript, 2D**; scene เล็กและนำกลับมาใช้ได้
- แยกการตัดสินใจ wave, การเคลื่อนที่, การชน และ feedback ออกจากกัน
- ค่าศัตรู/อาวุธ/wave เป็น `.tres` data; gameplay อ่าน InputMap actions ไม่อ่าน raw key
- HUD รับ signals/events เมื่อค่าเปลี่ยน ไม่ polling ทุกเฟรม
- เขียน save ลง `user://` เป็น plain data, มี schema version; ห้าม serialize Node/live object
- ไม่มี service/network/pathfinding ใน MVP ที่ไม่ได้แก้ปัญหาจริง

## 2. Root และ Godot project

```text
repository/
├── README.md
├── START_HERE.md
├── docs/                         # GDD, story, art, architecture, roadmap, manual, handoff
├── scripts/dev.ps1               # run/import/check
├── scripts/test.ps1              # Godot automated test suite
├── scripts/export.ps1            # Windows/Android build helper
├── projects/last-light/
│   ├── project.godot
│   ├── scenes/
│   ├── scripts/
│   ├── data/
│   ├── assets/
│   └── tests/
├── agent/skills/, .agents/skills/ # skills เดิม
├── mcp-servers/                  # MCP servers เดิม
└── opencode.json                 # MCP configuration เดิม
```

เกมเล่นได้จาก `projects\last-light\`; build output และ editor cache ไม่ควร commit

## 3. Scene composition

```text
Title (Control)                       # title.tscn + title_screen.gd
├── Background
└── SafeRoot (MarginContainer)        # screen content built in code
    ├── Center / title stack
    ├── Settings panel
    └── Field Archive panel

Run (Node2D)                          # run.gd creates these on _ready
├── Enemies (Node2D)
├── Projectiles (Node2D)
├── Effects (Node2D)
├── AudioDirector (Node)
├── Player (CharacterBody2D)
└── HUD (CanvasLayer)

Enemy scenes: Drifter / Skitter / Dasher / Warden (Area2D + shared behavior), added under Enemies
Player scene: Player (CharacterBody2D) + sprite + collision shape
Projectile scene: PlayerBullet (Area2D + visual + hit shape), added under Projectiles
```

ตัว Run วาดสนามด้วย canvas; actor sprites อยู่ใน `assets/art/`. UI controls สร้างจาก code

## 4. โฟลเดอร์ใน project

```text
projects/last-light/
├── scenes/
│   ├── boot.tscn
│   ├── ui/title.tscn
│   └── gameplay/
│           ├── run.tscn
│           ├── actors/player.tscn
│           ├── actors/enemies/     # Drifter, Skitter, Dasher, Warden
│           └── projectiles/player_bullet.tscn
├── scripts/
│   ├── actors/                     # player/enemy/projectile behavior
│   ├── data/                       # typed Resource definitions
│   ├── gameplay/                   # run loop, combat effects
│   ├── systems/                    # save/progression/audio/diagnostics
│   └── ui/
│       ├── title_screen.gd
│       ├── hud.gd
│       └── safe_area_layout.gd
├── data/
│   ├── enemies/ missions/ upgrades/
│   ├── waves/
│   └── weapons/
├── assets/
│   ├── art/{player,enemies,projectiles,effects,backgrounds,ui}
│   ├── audio/{music,sfx,ambience,voice} + audio_bus_layout.tres
│   ├── fonts/                       # Noto Sans Thai (OFL)
│   └── localization/
└── tests/                           # Phase 1, save, and stress scripts
```

`scripts/core`, `scripts/ai`, `scenes/ui` และ test subfolders เป็น placeholders สำหรับขยายงาน; game flow/UI ปัจจุบันอยู่ในสคริปต์ที่ระบุด้านบน. เก็บ resource definitions ที่ Godot ต้องโหลดเป็น `.tres` ใน `data/`; หากเพิ่มไฟล์ JSON/TXT ต้องกำหนด export filter ไม่เช่นนั้นอาจหายจาก build

## 5. Runtime responsibilities

- **DiagnosticService (autoload):** bounded local log + session marker; ไม่ส่ง telemetry ออกนอกเครื่อง
- **ProgressionService (autoload):** ประสาน profile persistence, records, Salvage และ codex unlocks
- **ProfileRepository:** JSON schema v3, validation, v1/v2 migration, temp/backup recovery และป้องกันการเขียนทับ save ใหม่กว่า
- **RunDirector (ใน Run):** อ่าน mission/wave data, integrity, elapsed time, ผลลัพธ์และ Salvage
- **RunAudioDirector (ใน Run):** SFX one-shots + ambient loop ผ่าน SFX/Music buses
- **SafeAreaLayout:** แปลง safe rectangle ของ OS เป็น inset ใน UI units
- **FieldSurvivor/WeaponDefinition:** อ่าน InputMap + touch axis, ยิงตาม cooldown และใช้ weapon resource
- **Enemy:** MVP ใช้ FSM สั้น ๆ เช่น descend → telegraph → dash → breach/dead; ห้ามแชร์ flags ที่ทำให้สถานะขัดกัน
- **HUD:** รับ update เมื่อ integrity/resonance/wave/time เปลี่ยน และ subscribe ต่อ boss health; ไม่ poll ศัตรูทุกเฟรม
- **CombatEffect:** วาด hit/pulse/telegraph effect แบบชั่วคราวและไม่เปลี่ยน collider

ใช้ signals สำหรับเหตุการณ์ข้าม scene; ใช้ direct reference/child access เมื่อเป็นความสัมพันธ์เจ้าของ-ลูกที่ชัดเจน

## 6. Input contract

| Action | PC default | Mobile (deferred) |
|---|---|---|
| `move_left`, `move_right` | A/D หรือ ←/→ | ยังไม่อยู่ใน scope |
| `activate_pulse` | Space (Emergency Blast) | ยังไม่อยู่ใน scope |
| `upgrade_weapon` | E (Weapon Upgrade) | ยังไม่อยู่ใน scope |
| `pause` | Esc | ยังไม่อยู่ใน scope |
| `ui_accept`, `ui_cancel` | Enter/Esc | ยังไม่อยู่ใน scope |

ปืนหลักยิงอัตโนมัติจึงไม่ต้องกดค้างเพื่อยิง; Parts คือชื่อที่ผู้เล่นเห็น ส่วน `resonance` คงเป็นชื่อ implementation ภายใน; gameplay อ่าน actions ผ่าน InputMap

## 7. Data model

- `EnemyDefinition`: stable id, scene, archetype, minimum wave, HP, speed, Parts (`resonance_reward`) reward
- `WeaponDefinition`: id, base damage/fire interval, linked upgrade
- `WaveDefinition`: wave index, spawn interval, HP/speed bonus, eligible enemy IDs
- `UpgradeDefinition`: weapon-upgrade stacks and damage/fire-interval values
- `MissionDefinition`: duration, boss start, starting Integrity, enemy roster, wave definitions and boss

ใช้ stable string IDs ใน save/data; balance ปรับจาก resource ไม่แก้ logic ทุกชนิดศัตรู

## 8. Physics และ performance

- จำกัด movement ในแกน X; clamp จาก playfield bounds ไม่ใช้ navigation mesh
- Player อยู่ physics layer 1, enemy layer 2, projectile layer 3; player bullet ตรวจ enemy layer ผ่าน mask. Enemy projectile/pickup layers ยังไม่มีใน build
- projectiles/enemies จำนวนมากให้เริ่มด้วย instantiate/free ที่อ่านง่าย; ทำ pooling เมื่อ profiler ยืนยันว่ามี spike
- เป้าทดสอบหลังมี combat: 60 FPS, 100 enemies + 200 projectiles ในฉาก stress โดยไม่ทำให้ frame time เกินงบบนเครื่องอ้างอิง; ปรับจำนวนตามผลอุปกรณ์จริง
- ไม่ใช้ hit-stop ด้วยการค้าง simulation ที่ทำให้ timer/logic หลุด; feedback ต้องกลับสู่สถานะปกติและมีตัวเลือกลดผล

## 9. Save contract

- ใช้ JSON plain data ใน `user://profile.json`; schema version ปัจจุบัน 3
- เก็บ Salvage, lifetime Salvage, runs/victories, best wave/integrity/time, lore IDs และ barricade upgrade level; ไม่ serialize Node/live run
- `user://settings.cfg` เก็บ master dB, reduce flashes, large text และ locale
- เขียน temp → ตรวจ error → เก็บ `.bak` → rename; โหลดสำรองเมื่อไฟล์หลักเสีย
- migrate ทีละ version และ validate range/required key ก่อนใช้; save จากเครื่องผู้เล่นไม่ใช่ข้อมูลที่เชื่อถือได้

## 10. Audio, UI และ export

- Audio buses: Master → Music/SFX/UI/Ambience/Voice; build ใช้ SFX และ Music, ส่วน bus อื่นเตรียมไว้ขยายต่อ; ยังไม่มี music ducking
- portrait gameplay field ใช้ reference 360×640; ยึด UI ด้วย anchors/containers, safe area และ event-driven HUD
- `export_presets.cfg` มี Windows Desktop และ Android Arm64 presets; ไม่ commit keystore หรือรหัสผ่าน
- Noto Sans Thai เป็น OFL; license อยู่ใน `assets/fonts/OFL.txt`
- Generated pixel sprites/music/SFX มาจาก scripts ใน repository; เนื้อหาเป็นต้นฉบับ
- เขียนข้อมูล runtime ใน `user://`; resource ใน `res://` เป็น read-only ใน exported game
- Android export ถูกพักไว้จนกว่า Windows core loop จะผ่าน playtest; preset ไม่เท่ากับ platform validation

## 11. Test seams

- Tests ปัจจุบัน: gameplay/scene flow, save migration/recovery/validation และ stress fixture; unit-test subfolder ยังเป็น placeholder
- Integration: main scene loads, wave spawns, bullet hit → kill → Parts, full meter → weapon upgrade or Emergency Blast, defeat/victory → result
- Manual (current): Windows keyboard, aspect ratio, reduce shake/flash, quit/relaunch save; mobile and exported-build checks deferred
