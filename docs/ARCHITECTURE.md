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
├── scripts/dev.ps1               # run/import/check แบบไม่ผูกเครื่อง
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

รายละเอียดของ project skeleton อยู่ใน `projects\last-light\`; build output และ editor cache ไม่ควร commit

## 3. Scene composition

```text
Boot (Control)                        # project entry ปัจจุบัน เป็น scaffold
├── Background
└── Center / Stack

Run (Node2D)                          # สร้างใน gameplay milestone
├── World (Node2D)
│   ├── ParallaxBackground
│   ├── EnemyContainer
│   ├── ProjectileContainer
│   ├── PickupContainer
│   ├── Player
│   └── BeaconLine
├── RunCamera (Camera2D)
├── Effects (Node2D)
└── HUD (CanvasLayer)

Enemy scenes: EnemyBase (CharacterBody2D หรือ Area2D ตามการทดลองชน)
Player scene: Player (CharacterBody2D) + Sprite/Animation + CollisionShape2D
Projectile scene: Projectile (Area2D) + visual + hit shape
```

ตัวอย่างเป็นเป้าหมาย ไม่ได้หมายความว่าทุก scene มีอยู่แล้ว เลือก root node ตามการทดสอบ physics; อย่าเลือก body type ซับซ้อนเกินการเคลื่อนที่แบบ lane

## 4. โฟลเดอร์ใน project

```text
projects/last-light/
├── scenes/
│   ├── ui/                         # main menu, pause, result, HUD
│   └── gameplay/
│       ├── actors/enemies/         # player, enemy base, enemy variants, boss
│       ├── projectiles/
│       └── pickups/
├── scripts/
│   ├── core/                       # app/session state, scene flow
│   ├── gameplay/                   # run director, wave director, weapon/upgrade
│   ├── actors/                     # player/enemy/projectile behavior
│   ├── ai/                         # enemy state logic
│   ├── systems/                    # save/audio/input helpers
│   └── ui/
├── data/
│   ├── enemies/ weapons/ upgrades/
│   └── waves/ missions/
├── assets/
│   ├── art/{player,enemies,projectiles,effects,backgrounds,ui}
│   ├── audio/{music,sfx,ambience,voice}
│   └── localization/
└── tests/{unit,integration}/
```

เก็บ resource definitions ที่ Godot ต้องโหลดเป็น `.tres` ใน `data/`; หากเพิ่มไฟล์ JSON/TXT ต้องกำหนด export filter ไม่เช่นนั้นอาจหายจาก build

## 5. Runtime responsibilities

- **AppState (autoload):** สถานะเมนู/ตั้งค่า/เปลี่ยนฉากเท่านั้น; ไม่ถือ reference ไปยังศัตรูใน run
- **SaveService (autoload):** โหลด/validate/migrate meta progress และ settings; รายงาน save error ให้ผู้เล่นเห็น
- **AudioDirector (autoload):** เปลี่ยนเพลง/เล่น SFX ผ่าน bus; ไม่เก็บ gameplay rules
- **RunDirector (ใน Run):** เริ่ม/จบ session, integrity, score, elapsed time และผลลัพธ์
- **WaveDirector (ใน Run):** อ่าน wave data และสั่ง spawn; จำกัดจำนวน/ตำแหน่ง spawn ตามขอบ playfield
- **Player/WeaponController:** อ่าน action state และยิงเมื่อ cooldown ผ่าน; ส่ง event เมื่อ hit/kill/charge เต็ม
- **Enemy:** MVP ใช้ FSM สั้น ๆ เช่น descend → telegraph → dash → breach/dead; ห้ามแชร์ flags ที่ทำให้สถานะขัดกัน
- **HUD:** subscribe ต่อ `integrity_changed`, `resonance_changed`, `wave_changed`, `upgrade_ready`; ไม่เข้าถึง internals ของศัตรู

ใช้ signals สำหรับเหตุการณ์ข้าม scene; ใช้ direct reference/child access เมื่อเป็นความสัมพันธ์เจ้าของ-ลูกที่ชัดเจน

## 6. Input contract

| Action | PC default | Android |
|---|---|---|
| `move_left`, `move_right` | A/D หรือ ←/→ | ลาก/virtual stick |
| `activate_pulse` | Space | ปุ่ม Pulse |
| `upgrade_weapon` | E | ปุ่ม Overclock |
| `pause` | Esc | ปุ่ม pause |
| `ui_accept`, `ui_cancel` | Enter/Esc | แตะ |

ปืนหลักยิงอัตโนมัติจึงไม่ต้องกดค้างเพื่อยิง; gameplay อ่าน actions ผ่าน InputMap และการตั้งค่า binding ต้องบันทึกแยกจาก run data

## 7. Data model

- `EnemyDefinition`: id, HP, speed, breach damage, points, drop/charge reward, scene, telegraph settings
- `WeaponDefinition`: id, base cooldown, damage, projectile scene, targeting mode, upgrades
- `WaveDefinition`: timeline/lanes/count/enemy ids, warning duration, seed policy, boss marker
- `UpgradeDefinition`: id, eligibility, stat modifier, stack limit, display/localization keys
- `MissionDefinition`: arena, wave sequence, objective, reward table, story events

ใช้ stable string IDs ใน save/data; balance ปรับจาก resource ไม่แก้ logic ทุกชนิดศัตรู

## 8. Physics และ performance

- จำกัด movement ในแกน X; clamp จาก playfield bounds ไม่ใช้ navigation mesh
- แยก collision layers สำหรับ player, enemy, player projectile, enemy projectile, pickup และ Beacon; ทำ hit test ให้ deterministic
- projectiles/enemies จำนวนมากให้เริ่มด้วย instantiate/free ที่อ่านง่าย; ทำ pooling เมื่อ profiler ยืนยันว่ามี spike
- เป้าทดสอบหลังมี combat: 60 FPS, 100 enemies + 200 projectiles ในฉาก stress โดยไม่ทำให้ frame time เกินงบบนเครื่องอ้างอิง; ปรับจำนวนตามผลอุปกรณ์จริง
- ไม่ใช้ hit-stop ด้วยการค้าง simulation ที่ทำให้ timer/logic หลุด; feedback ต้องกลับสู่สถานะปกติและมีตัวเลือกลดผล

## 9. Save contract

- ใช้ JSON plain data ใน `user://profile.json`; มี `version` ตั้งแต่ schema แรก
- บันทึก settings, unlocked content, best results และ meta Salvage; MVP ไม่ serialize active scene/run
- เขียน temp → ตรวจ error → เก็บ `.bak` → rename; โหลดสำรองเมื่อไฟล์หลักเสีย
- migrate ทีละ version และ validate range/required key ก่อนใช้; save จากเครื่องผู้เล่นไม่ใช่ข้อมูลที่เชื่อถือได้

## 10. Audio, UI และ export

- Audio buses: Master → Music/SFX/UI/Ambience/Voice; duck music เมื่อวิทยุหรือ SFX สำคัญดัง
- portrait gameplay field ใช้ reference 360×640; ยึด UI ด้วย anchors/containers, safe area และ event-driven HUD
- Windows และ Android export presets เป็น machine/build settings; ยังไม่ commit keystore หรือรหัสผ่าน
- เขียนข้อมูล runtime ใน `user://`; resource ใน `res://` เป็น read-only ใน exported game
- Android ต้องตั้ง SDK/JDK และ export templates ที่ตรง Godot 4.7.2 ก่อนระบุว่าผ่าน

## 11. Test seams

- Unit: integrity, charge thresholds, upgrade cost/limit, damage/breach, wave schedule, save migration
- Integration: main scene loads, wave spawns, bullet hit → kill → Resonance, full charge → exactly one action, defeat/victory → result
- Manual: keyboard, touch, aspect ratio/safe area, reduce shake/flash, quit/relaunch save, Windows export และ Android device
