# ARCHITECTURE — Kick Hero Arena (Godot 4.7)

## 1. โครงสร้างไฟล์ (projects/my-game/)

```
project.godot            # main scene = main_menu.tscn, autoload Game, inputs, stretch 480×270
scripts/
  game.gd     (autoload) # โหมดปัจจุบัน + อ่าน cmdline user args (การเทสต์ headless)
  main_menu.gd           # ปุ่ม 6 โหมด  connect ด้วยโค้ด (get_node("Menu/BtnX"))
  online_menu.gd         # Host/Join ผ่าน WebSocketMultiplayerPeer (Phase B)
  arena.gd               # จังหวะการแข่ง FSM ทั้งหมด + HUD
  hero.gd                # มนุษย์ & AI เดียวกัน (ai_level > 0 = AI) + sprint/stamina/steal
  ball.gd                # possession ของบอล (owner/claim/steal/release)
  gk.gd                  # GK auto เฝ้าช่องประตู (patrol y)
scenes/
  main_menu.tscn / online_menu.tscn / arena.tscn / hero.tscn / gk.tscn
assets/                  # hero_blue, hero_red, gk, ball, field, shadow (sweetie16, lint 90+)
```

## 2. ระบบ Possession (บอลติดตัว) — หัวใจของเกม

```
บอลว่าง ── เดินเข้า ≤15px ──▶ hero ครอง (ball.owner_hero = hero)
                                  │
             ┌────────────────────┴────────────────────┐
   เจ้าของกดเตะ C/K / V/L              ฝ่ายอื่นเตะโดน (receive_touch)
             │                                       │
      release(aim * power)                   เจ้าของเดิม stun(0.45)
      ignore lockout 0.35s (ครองใหม่ไม่ได้)      บอลหลุดแรง 35% (min 120)
```

- ขณะครอง: บอลถูก "ติด" ที่ `owner.pos + owner.aim * 11` ทุก physics tick (`ball.gd::_physics_process`)
- `try_claim()` คืน false ถ้ามีเจ้าของคนอื่น หรือยังติด lockout
- ครอง → hero._claim_ball_if_free() เรียกหลัง `move_and_slide()` ทุกเฟรม
- เตะ/แย่ง/สกิล ไหลผ่านฟังก์ชันเดียว: `Ball.receive_touch(hero, power)` — hero แค่ส่ง power มา
- Skill (V/L) เรียก `_start_kick(skill_power, skill_cooldown)` = เตะโดยแรง 430 (cooldown 2.5s)

## 3. Sprint + Stamina

| ค่า | หมายเหตุ |
|---|---|
| ปุ่ม | P1 = Space (physical 32), P2 = Shift (physical 4194325) |
| เร่งเมื่อ | กดปุ่มค้าง + เดินอยู่ + stamina > 0.02 + ไม่ stun |
| multiplier | ×1.75 ความเร็วฐาน (run_speed) |
| drain / regen | -0.85/s ตอน sprint, +0.55/s ตอนไม่ sprint |
| stun | speed ×0.55 และ "ห้าม sprint" — จากการโดนแย่งบอล (0.45s) |
| HUD | `UI/Stamina1`, `UI/Stamina2` ProgressBar (max=1) — arena.gd อัปเดตทุกเฟรม |

## 4. FSM การแข่ง (`arena.gd`)

```
KICKOFF (นับ 3→หย่อนบอล, 2.0s)
   ▼
PLAY (90s timer / เป้า 3 ประตู / Training = เวลา INF)
   │  ball เข้า Goal Area ซ้าย/ขวา (body_entered, state ต้อง = PLAY)
   ▼
GOAL (ประกาศ 1.4s) ──▶ place_pieces() ──▶ KICKOFF
   │ ถ้าคะแนน ≥ 3 หรือเวลาหมด
   ▼
END (R = เริ่มใหม่ / Esc หรือ M = เมนู)
```

Training mode: Hero2 ซ่อน + disabled + shape ปิด, ประตู "ทั้งสองฝั่ง" นับคะแนนได้, Timer = `--:--`, Stamina2 ซ่อน

## 5. AI Design (ใน `hero.gd`, skill game-ai: decide/steer แยกชั้น)

- ตัดสินใจเป็นจังหวะ: `AI_REACT` = [–, 0.45, 0.28, 0.15]s (Easy/Normal/Hard)
- 3 บทบาท: **ครองบอล** → เลี้ยงพุ่งประตู, ยิงระยะใกล้ <170px (มี aim error ตามระดับ); **ศัตรูครอง** → sprint เข้าสั้น <22px แล้ว "เตะเพื่อแย่ง"; **บอลว่าง** → sprint ถ้าไกล >60px, วางตัวตัดหน้าประตูตัวเองถ้าใกล้ <150px
- ตารางต่อ level: `AI_SPEED_SCALE [1.0,0.78,0.9,1.0]`, `AI_AIM_ERR [0,0.38,0.18,0.06]`, `AI_KICK_SCALE [1,0.82,0.92,1.0]`, `AI_LEAD [0,0,0.12,0.25]`
- Headless log: `[ARENA] ...` จาก `_headless_debug()` (พิมพ์เฉพาะ DisplayServer=headless)

## 6. Online 1v1 — แผนผูก (โค้ดบางส่วนพร้อมแล้ว)

```
online_menu.gd: Host = WebSocketMultiplayerPeer.create_server(8910)
                Join = create_client(url ws://...:8910) + await connected_to_server
  → set multiplayer.multiplayer_peer, Game.mode = "online_host" | "online" → arena

arena.gd: _setup_online()  ← เตรียมพื้นที่ (ปัจจุบัน pass)
          _both_connected() ← เตรียมพื้นที่ (ปัจจุบัน return true; KICKOFF หน่วงถ้า false)
hero.gd:  remote_control = true → ไม่อ่าน Input, ตำแหน่ง/aim มาจาก network
          force_kick(dir, power) = ทางเข้าคำสั่งเตะจากเน็ต
Game.mode: "online" (client) / "online_host"
```

**สิ่งที่ยังต้องเขียน (Phase B ต่อ):**
1. `arena._setup_online()`: host จับ peer ตัวเอง = `multiplayer.get_unique_id()`; กำหนด Hero1 คือ host, Hero2 คือ client (`multiplayer.peer_connected` / `peer_disconnected`)
2. RPC: client → `@rpc("any_peer")` ส่ง input (dir, kick, skill, sprint, id) → server ใช้ `hero.remote_control` + `force_kick`; host ส่ง snapshot ย้อน (ตำแหน่ง hero/บอล/score/time) ให้ client แต่งพอ
3. disconnect guard: `multiplayer.peer_disconnected` / `server_disconnected` → กลับเมนูพร้อม snapshot tooltip
4. Web export ต้องตั้ง wss/ภูมิภาค host — ดู skill `godot-export` หั้น web COOP/COEP

## 7. จุดต่อยอดที่เตรียมไว้ (Extension Points)

| จุด | วิธีต่อ |
|---|---|
| ไอเทมกลางสนาม | เพิ่ม Area2D กลุ่ม "item" ใน arena.tscn + spawn เวลาแมตช์ที่ x เหล่านี้ + hero เก็บ (apply buff ผ่าน `hero` field) |
| Ultimate ต่อ Hero | hero.gd มี `skill_cooldown` พร้อมใช้ — เพิ่ม `ultimeter` นับจาก event receive_touch แล้วเรียก per-skin เอฟเฟกต์ตาม design 6 อาชีพ |
| เอฟเฟกต์/juice | Hero กระพริบตอน stun (`_stun_t > 0`), บอล stretch ตอนยิง, ประตู flash ตอน GOAL — ต่อจาก skill game-feel |
| เสียง | bus Master/SFX/Music ตาม skill audio-design; เตะ = คลิปสั้น random pitch |
| Anotation | สกิล 4 ปุ่ม มี (P1 X = ไอเทม, P2 J) ว่างพร้อมใช้ |

## 8. กฎห้ามแก้

1. `ball.gd::_physics_process` ต้อง set ตำแหน่งถ่าย role ครองบอลทุกเฟรม — ไม่ใช้ physics push
2. ห้ามให้บอลมีโน้มถ่วง (`gravity_scale = 0`)  — นี่คือ top-down; บอลต้องเด้งกำแพงไม่มี throw-in/หลุดสนาม
3. ครองใหม่ต้องผ่าน `try_claim()` เท่านั้น — อย่าเซ็ต `owner_hero` ตรง ๆ จากภายนอก (`reset()` ยกเว้น เพราะเป็น flow กลางสนาม)
4. เทสต์ headless ต้องมี `--quit-after` และระบุ `--` + โหมดก่อน (`-- training`)
5. แก้ hero.gd ทั้งชิ้นไหม? เช็กว่า `_apply_kick()` ยังคุ้มใช้ `receive_touch` และ `_claim_ball_if_free()` ยังถูกเรียกหลัง move
