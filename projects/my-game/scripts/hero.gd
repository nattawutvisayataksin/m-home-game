extends CharacterBody2D
class_name Hero
## Hero: มนุษย์/AI — top-down 8 ทิศ
## ระบบ possession: บอลติดตัว (ball.owner_hero = ตัวนี้) — แย่งด้วยเตะ C/K หรือสกิล V/L
## Sprint (Space/Shift): ใช้สไตมิน่า เร่งเข้าแย่งบอล / หลบตอนเลี้ยง
## ai_level > 0 สวมชุด AI (Easy/Normal/Hard — decide/steer แยกชั้นตาม skill game-ai)

@export var player_id := int(1)
@export var skin: Texture2D
@export var run_speed := float(120.0)
@export var kick_power := float(300.0)
@export var skill_power := float(430.0)
@export var skill_cooldown := float(2.5)
@export_range(0.02, 0.3) var kick_window := 0.14
@export var sprint_multiplier := float(1.75)
@export var acceleration := float(900.0)
@export var deceleration := float(1100.0)
@export var stamina_drain := float(0.85)   # ต่อวินาทีตอนวิ่ง + sprint
@export var stamina_regen := float(0.55)   # ต่อวินาทีตอนไม่ sprint
@export var ai_level := int(0)
@export var attack_left := bool(false)     # AI: ยิงประตูฝั่งซ้าย (สำหรับ P2)
@export var held_item := StringName(&"")   # ไอเทมที่ถืออยู่ — ใช้ด้วย X (P1) / J (P2)

# ตาราง 1..3 = Easy/Normal/Hard
const AI_SPEED_SCALE := [1.0, 0.78, 0.9, 1.0]
const AI_REACT := [0.0, 0.45, 0.28, 0.15]
const AI_ITEM_SEEK := [0.0, 110.0, 160.0, 200.0]  # ระยะที่ AI สนใจไอเทม (skill สูงเห็นไกลกว่า)
const AI_AIM_ERR := [0.0, 0.38, 0.18, 0.06]
const AI_KICK_SCALE := [1.0, 0.82, 0.92, 1.0]
const AI_LEAD := [0.0, 0.0, 0.12, 0.25]    # ทำนายบอลล้ำหน้า (วินาที)
const STUN_SLOW := 0.55
const CLAIM_RADIUS := 18.0                 # ระยะเดินชนบอลแล้วได้ครอง
const BALL_OFFSET := 14.0                  # kick zone อยู่หน้าตัว (ครอบบอลที่ติดหน้า 16px)
const ITEM_SPEED_MULT := 1.35              # บัฟความเร็วจากไอเทม ⚡

@onready var kick_zone: Area2D = $KickZone
@onready var sprite: Sprite2D = $Visual

var aim := Vector2.RIGHT
var remote_control := bool(false)
var stamina := float(1.0)
var speed_buff_t := float(0.0)             # เวลาที่เหลือของบัฟความเร็ว
var _stun_t := float(0.0)
var _kick_now := float(0.0)
var _kick_timer := float(0.0)
var _kick_active := float(0.0)
var _kick_used := bool(false)              # หนึ่งการเตะ = สัมผัสบอลครั้งเดียว
var _ai_timer := float(0.0)
var _ai_item_t := float(0.0)               # AI: ดีเลย์สั้น ๆ ก่อนใช้ไอเทมที่เก็บได้
var _ai_dir := Vector2.ZERO
var _ai_wants_kick := bool(false)
var _ai_sprint := bool(false)
var _ai_prev_pos := Vector2.ZERO       # ยังตรวจ ติด collision
var _unstuck_t := float(0.0)           # จังหวะหลบรอบหลังโดนตัน
var _unstuck_dir := Vector2.ZERO
var _walk_phase := float(0.0)
var _visual_base_position := Vector2.ZERO

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("hero")
	_visual_base_position = sprite.position
	if skin != null:
		sprite.texture = skin
	if player_id == 2 and ai_level == 0:
		aim = Vector2.LEFT
	_face_aim()

func _physics_process(delta: float) -> void:
	_stun_t = maxf(_stun_t - delta, 0.0)
	speed_buff_t = maxf(speed_buff_t - delta, 0.0)
	if remote_control:
		_kick_timer = maxf(_kick_timer - delta, 0.0)
		if _kick_active > 0.0 and not _kick_used:
			_kick_active -= delta
			kick_zone.position = aim * BALL_OFFSET
			_apply_kick()
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		move_and_slide()
		_update_locomotion_visual(delta)
		return

	var dir := Vector2.ZERO
	var want_kick := false
	var want_skill := false
	var want_sprint := false
	if ai_level > 0:
		_ai_think(delta)
		dir = _ai_dir
		want_kick = _ai_wants_kick
		want_sprint = _ai_sprint
		# AI: ถือไอเทมแป๊บหนึ่งแล้วใช้เอง (จังหวะสุ่มเหมือนคนตัดสินใจ)
		if held_item != &"":
			_ai_item_t = maxf(_ai_item_t - delta, 0.0)
			if _ai_item_t <= 0.0:
				use_item()
	else:
		var p := _prefix()
		dir = Input.get_vector(p + "left", p + "right", p + "up", p + "down")
		want_kick = Input.is_action_just_pressed(p + "kick")
		want_skill = Input.is_action_just_pressed(p + "skill")
		want_sprint = Input.is_action_pressed(p + "sprint")
		if Input.is_action_just_pressed(p + "item"):
			use_item()

	if dir != Vector2.ZERO:
		aim = dir.normalized()
		_face_aim()

	# ---- sprint + stamina (แห้งหมด = วิ่งชั่วคราวช้าลงจนฟื้น) ----
	var speed := run_speed
	if ai_level > 0:
		speed *= AI_SPEED_SCALE[ai_level]
	if _stun_t > 0.0:
		speed *= STUN_SLOW
	if speed_buff_t > 0.0:
		speed *= ITEM_SPEED_MULT
	var sprinting := want_sprint and dir != Vector2.ZERO and stamina > 0.02 and _stun_t <= 0.0
	if sprinting:
		speed *= sprint_multiplier
		stamina = maxf(stamina - stamina_drain * delta, 0.0)
	else:
		stamina = minf(stamina + stamina_regen * delta, 1.0)
	var target_velocity := dir * speed
	var response := acceleration if dir != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, response * delta)

	# ---- kick window ----
	_kick_timer = maxf(_kick_timer - delta, 0.0)
	if want_kick and _kick_timer <= 0.0:
		var power := kick_power
		if ai_level > 0: power *= AI_KICK_SCALE[ai_level]
		_start_kick(power, 0.4)
	elif want_skill and _kick_timer <= 0.0:
		_start_kick(skill_power, skill_cooldown)

	kick_zone.position = aim * BALL_OFFSET
	if _kick_active > 0.0:
		_kick_active -= delta
		if not _kick_used:
			_apply_kick()
	move_and_slide()
	_claim_ball_if_free()
	_update_locomotion_visual(delta)

func _update_locomotion_visual(delta: float) -> void:
	var moving := velocity.length() > 8.0
	if moving:
		_walk_phase = fmod(_walk_phase + delta * (7.0 + velocity.length() * 0.018), TAU)
	else:
		_walk_phase = move_toward(_walk_phase, 0.0, delta * 8.0)
	var stride := sin(_walk_phase)
	var bob := absf(stride) * (1.0 if moving else 0.0)
	sprite.position = _visual_base_position + Vector2(0.0, -bob)
	sprite.scale = Vector2(0.5 + bob * 0.006, 0.5 - bob * 0.006)

	var shadow := get_node_or_null("Shadow") as Sprite2D
	if shadow != null:
		shadow.scale = Vector2(0.5 + bob * 0.025, 0.5 - bob * 0.015)

func _prefix() -> String:
	return "p1_" if player_id == 1 else "p2_"

## เลือกจุดยิง: มุมบน/ล่างของประตูที่ห่าง GK ฝั่งนั้น (skill สูงเลือกหนีแม่นกว่า)
func _pick_shot_target(goal_attack: Vector2, attack_x: float, own_x: float) -> Vector2:
	var gy := 135.0
	for n in get_tree().get_nodes_in_group("gk"):
		var gn := n as Node2D
		if gn == null:
			continue
		# GK ของฝั่งที่ยิงใส่ = ตัวที่อยู่ใกล้เส้นประตูฝ่ายโจมตี
		if absf(gn.global_position.x - attack_x) < absf(gn.global_position.x - own_x):
			gy = gn.global_position.y
	var y_top := 94.0    # กึ่งกลางโพรงบน (GK ครอบ 114–156 + ตัวสูง 20 → โพรงบอล 89–99)
	var y_bot := 176.0   # กึ่งกลางโพรงล่าง (171–181) — margin โพสต์/GK ฝั่งละ 5px
	var pick_top: bool
	if ai_level <= 0:
		pick_top = randf() < 0.5
	else:
		pick_top = absf(gy - y_top) > absf(gy - y_bot)
		# พลาดอ่าน GK บ้าง (normal พลาด 35%, hard พลาด 20%)
		if randf() < (0.35 if ai_level == 1 else 0.20):
			pick_top = not pick_top
	var jitter: float = randf_range(-10.0, 10.0) if ai_level <= 0 else randf_range(-4.0, 4.0)
	return Vector2(attack_x, (y_top if pick_top else y_bot) + jitter)

func _face_aim() -> void:
	# สไปรต์ยืนเต็มตัวมองด้านข้าง (วาดหันขวา) — พลิกซ้าย/ขวาตามทิศเล็ง ไม่หมุนราบ
	sprite.rotation = 0.0
	if aim.x != 0.0:
		sprite.flip_h = aim.x < 0.0

func _start_kick(power: float, cooldown: float) -> void:
	_kick_now = power
	_kick_timer = cooldown
	_kick_active = kick_window
	_kick_used = false
	Sfx.play(&"kick")

## เตะ = ยิง (บอลของเรา/บอลว่าง) หรือ แย่ง (บอลของคนอื่น) — บอลตัดสินใจใน receive_touch
## ใช้ระยะตรง (บอลติดตัวจะ teleport ทุกเฟรม — Area2D อาจตรวจไม่ทันที่เสถียรใน headless)
func _apply_kick() -> void:
	var b := get_tree().get_first_node_in_group("ball") as Ball
	if b == null:
		return
	var reach := 27.0
	if b.global_position.distance_to(global_position) <= reach:
		body_touched(b)

func body_touched(b: Ball) -> void:
	b.receive_touch(self, _kick_now)
	_kick_used = true

## เดินเข้าบอลว่าง → ได้ครอง
func _claim_ball_if_free() -> void:
	var b := get_tree().get_first_node_in_group("ball") as Ball
	if b == null or b.owner_is_hero():
		return
	if global_position.distance_to(b.global_position) <= CLAIM_RADIUS:
		b.try_claim(self)

## โดนแย่งบอล / สะดุด — เรียกจาก ball.receive_touch()
func stun(secs: float) -> void:
	_stun_t = maxf(_stun_t, secs)

## ไอเทมกลางสนามเดินชน → เรียกจาก FieldItem (เก็บเข้าตัว)
func receive_item(k: StringName) -> void:
	held_item = k
	_ai_item_t = randf_range(1.0, 2.5)   # AI: ถือแป๊บหนึ่งแล้วค่อยใช้ (เหมือนคิดจังหวะ)

## ใช้ไอเทมที่ถือ (X/J หรือ AI ใช้เอง) — เอฟเฟกต์จัดการโดย arena.apply_item_effect()
func use_item() -> void:
	if held_item == &"":
		return
	var k := held_item
	held_item = &""
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("apply_item_effect"):
		arena.apply_item_effect(self, k)

## ให้ arena/network เรียกเตะแทนด้วยสคริปต์นี้
func force_kick(dir: Vector2, power: float = 0.0) -> void:
	if _kick_timer > 0.0:
		return
	aim = dir.normalized()
	_face_aim()
	_start_kick(power if power > 0.0 else kick_power, 0.4)

# ------------- AI (decide: คิดเป็นจังหวะ / steer: วิ่งตามเป้า) -------------
func _ai_think(delta: float) -> void:
	_ai_wants_kick = false
	_ai_sprint = false
	_ai_timer -= delta
	if _unstuck_t > 0.0:
		_unstuck_t -= delta
		_ai_dir = _unstuck_dir
		return
	var ball := get_tree().get_first_node_in_group("ball") as Ball
	if ball == null:
		_ai_dir = Vector2.ZERO
		return
	if _ai_timer <= 0.0:
		# ตรวจติดตัว: อยากวิ่งแต่ไม่ขยัก → สั่งหลบรอบ (หมุนทิศ 60°)
		var moved := global_position.distance_to(_ai_prev_pos)
		_ai_prev_pos = global_position
		if moved < 1.5 and _kick_timer <= 0.0:
			var sign_g := -1.0 if randf() < 0.5 else 1.0
			_unstuck_dir = _ai_dir.rotated(sign_g * PI / 3.0)
			_unstuck_t = 0.5
			return
		_ai_timer = AI_REACT[ai_level]

	var attack_x := 480.0 if not attack_left else 0.0
	var own_x := 0.0 if not attack_left else 480.0
	var goal_own := Vector2(own_x, 135.0)
	var goal_attack := Vector2(attack_x, 135.0)

	# --- ไอเทมกลางสนาม: ไม่ถือของ + ไม่ครองบอล + ไอเทมลอยใกล้ → วิ่งไปเก็บ ---
	if held_item == &"" and ball.owner_hero != self and _kick_timer <= 0.0:
		var it := get_tree().get_first_node_in_group("field_item") as Node2D
		if it != null and is_instance_valid(it):
			var d_it := global_position.distance_to(it.global_position)
			if d_it <= float(AI_ITEM_SEEK[ai_level]):
				_ai_sprint = d_it > 60.0
				_ai_dir = (it.global_position - global_position).limit_length(1.0)
				return

	if ball.owner_hero == self:
		# --- ครองบอล: เลี้ยงไปประตูฝ่ายตรงข้าม + ยิงเมื่อใกล้ (sprint เลี้ยงหลบ) ---
		_ai_sprint = true
		var dist_goal := global_position.distance_to(goal_attack)
		if dist_goal < 170.0 and _kick_timer <= 0.0:
			# เลือกมุมบน/ล่างที่ห่างจาก GK ฝั่งนั้น (skill สูงเลือกแม่นกว่า)
			var shot_target := _pick_shot_target(goal_attack, attack_x, own_x)
			var shot: Vector2 = (shot_target - global_position).normalized()
			shot = shot.rotated(randf_range(-float(AI_AIM_ERR[ai_level]), float(AI_AIM_ERR[ai_level])))
			aim = shot
			_face_aim()
			_ai_wants_kick = true
			_ai_dir = Vector2.ZERO
		else:
			var target := goal_attack + (global_position - goal_attack).limit_length(120.0)
			# เลี้ยงอ้อมคู่แข่งที่ยืนขวางแนวหน้า (ไม่ตรงดิ่งเข้าตัวเขาแล้วบอลติดคา)
			for h in get_tree().get_nodes_in_group("hero"):
				var hn := h as Hero
				if hn == null or hn == self or not is_instance_valid(hn):
					continue
				var to_opp := hn.global_position - global_position
				var fwd := (target - global_position).normalized()
				var along := to_opp.dot(fwd)
				if along > 0.0 and along < 70.0 and to_opp.length() < 50.0:
					var side := fwd.orthogonal()
					if to_opp.dot(side) < 0.0:
						side = -side
					target = global_position + (fwd * 0.45 + side * 0.9).normalized() * 70.0
			_ai_dir = (target - global_position).limit_length(1.0)
	elif ball.owner_is_hero():
		# --- เขาครองบอล: ตามเพื่อแย่ง (sprint เข้าเตะ) ---
		_ai_sprint = true
		var owner_pos: Vector2 = ball.owner_hero.global_position
		_ai_dir = (owner_pos - global_position).limit_length(1.0)
		if _kick_timer <= 0.0 and global_position.distance_to(owner_pos) <= 22.0:
			aim = (owner_pos - global_position).normalized()
			_face_aim()
			_ai_wants_kick = true
	else:
		# --- บอลว่าง: พุ่งไปครอง (sprint ตอนไกล) ---
		var bp: Vector2 = ball.global_position + ball.linear_velocity * float(AI_LEAD[ai_level])
		_ai_sprint = global_position.distance_to(bp) > 60.0
		_ai_dir = (bp - global_position).limit_length(1.0)
		if global_position.distance_to(bp) < 150.0:
			# ตัดหน้า: ยืนระหว่างบอลกับประตูตัวเองเพื่อกันโดนยิง
			var to_goal: Vector2 = (goal_own - bp).normalized()
			var target: Vector2 = bp + to_goal * 10.0
			_ai_dir = (target - global_position).limit_length(1.0)

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_walk_phase = 0.0
	sprite.position = _visual_base_position
	sprite.scale = Vector2(0.5, 0.5)
	stamina = 1.0
	_stun_t = 0.0
	_kick_timer = 0.0
	_kick_active = 0.0
	_ai_dir = Vector2.ZERO
	held_item = &""           # เริ่มแมตช์/คิกออฟ — เคลียร์ไอเทมที่ถือ
	speed_buff_t = 0.0
