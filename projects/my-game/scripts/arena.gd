extends Node2D
## Kick Hero Arena — จังหวะแข่ง: KICKOFF → PLAY (จับเวลา) → GOAL (พักกระพริบ) → END
## โหมดจาก Game.mode: local / easy / normal / hard / training / online*

enum S { KICKOFF, PLAY, GOAL, END }

const MATCH_TIME := 90.0
const TARGET_SCORE := 3

# --- ไอเทมกลางสนาม (DESIGN.md §ระบบพิเศษ) — ปล่อยตามเวลา ใครเดินชนก่อนได้ก่อน ---
const ITEM_KINDS: Array[StringName] = [&"speed", &"heavy", &"decoy", &"gate"]
const ITEM_SPAWN_FIRST := 12.0    # วินาทีก่อนไอเทมลูกแรก (ช่วงเกมมุมกลาง)
const ITEM_SPAWN_EVERY := 15.0    # หลังจากนั้นปล่อยทุก ๆ 15 วิ
const ITEM_MAX_ON_FIELD := 2
const ITEM_EFFECT_SECS := 6.0     # ความยาวเอฟเฟกต์ทุกชนิด
const ITEM_TEX_PATHS := {
	&"speed": "res://assets/items/item_speed.png",
	&"heavy": "res://assets/items/item_heavy.png",
	&"decoy": "res://assets/items/item_decoy.png",
	&"gate": "res://assets/items/item_gate.png",
}

@onready var ball: Ball = $Ball
@onready var hero1: Hero = $Hero1
@onready var hero2: Hero = $Hero2
@onready var gk_left: CharacterBody2D = $GKLeft
@onready var gk_right: CharacterBody2D = $GKRight
@onready var score_label: Label = $UI/Score
@onready var timer_label: Label = $UI/Timer
@onready var msg_label: Label = $UI/Msg
@onready var stamina1: ProgressBar = $UI/Stamina1
@onready var stamina2: ProgressBar = $UI/Stamina2
@onready var cam: Camera2D = $Cam
@onready var score_panel: Panel = $UI/ScorePanel
@onready var score_left_label: Label = $UI/ScorePanel/LeftScore
@onready var score_right_label: Label = $UI/ScorePanel/RightScore
@onready var timer_panel: Panel = $UI/TimerPanel

var state := S.KICKOFF
var score_left := 0
var score_right := 0
var time_left := MATCH_TIME
var _announce := 2.0
var _elapsed := 0.0       # เวลาที่ผ่านไปในแมตช์
var _training := false
var _online := false
var _item_tex := {}             # kind -> Texture2D
var _item_t := ITEM_SPAWN_FIRST # นับถอยหลังถึงไอเทมลูกถัดไป
var _icon1: TextureRect         # ไอคอนไอเทมที่ P1 ถือ (UI)
var _icon2: TextureRect         # ไอคอนไอเทมที่ P2 ถือ (UI)
var _shake_t := 0.0             # เขย่าจอตอนได้ประตู (game feel)

func _ready() -> void:
	_headless_debug("ARENA READY — mode=%s" % Game.mode)
	$Goals/LeftGoal.body_entered.connect(_on_goal_left)
	$Goals/RightGoal.body_entered.connect(_on_goal_right)
	var m := Game.mode
	_training = (m == "training")
	_online = (m.begins_with("online"))
	match m:
		"easy": hero2.ai_level = 1
		"normal": hero2.ai_level = 2
		"hard": hero2.ai_level = 3
	hero2.attack_left = true
	if _training:
		hero2.visible = false
		hero2.process_mode = Node.PROCESS_MODE_DISABLED
		hero2.get_node("Shape").set_deferred("disabled", true)
		time_left = INF
		msg_label.text = "TRAINING"
		msg_label.visible = true
		_show_temporary_msg("TRAINING — เตะเล่นได้ทุกประตู", 2.0)
		state = S.KICKOFF
		_announce = 2.0
	_setup_online()
	for k in ITEM_TEX_PATHS:
		_item_tex[k] = load(ITEM_TEX_PATHS[k])
	_icon1 = _make_icon(Vector2(14, 14))
	_icon2 = _make_icon(Vector2(450, 14))
	place_pieces()
	_update_labels()
	Sfx.start_crowd()
	_refresh_hud_style()

func _exit_tree() -> void:
	Sfx.stop_crowd()

func place_pieces() -> void:
	ball.reset()
	hero1.reset_to(Vector2(150, 135))
	hero2.reset_to(Vector2(330, 135))
	hero1.aim = Vector2.RIGHT
	hero1._face_aim()
	hero2.aim = Vector2.LEFT
	hero2._face_aim()
	if _icon1 != null:
		_icon1.texture = null
	if _icon2 != null:
		_icon2.texture = null

func _process(delta: float) -> void:
	match state:
		S.KICKOFF:
			_announce -= delta
			if _online and not _both_connected():
				_show_msg("รอเพื่อนเชื่อมต่อ...")
				return
			if _announce > 0.0:
				_show_msg("3" if _announce > 2.0 else ("2" if _announce > 1.0 else "หย่อนบอล!"))
			else:
				state = S.PLAY
				_headless_debug("KICKOFF → PLAY (บอลกลางสนาม)")
				Sfx.play(&"whistle", 0.0)   # นกหวีดหย่อนบอล (pitch คงระดับ)
				_show_msg("")
		S.PLAY:
			if not _training:
				time_left = maxf(time_left - delta, 0.0)
				if time_left <= 0.0:
					_finish()
			# ไอเทมกลางสนาม — ปล่อยตามเวลา (online ยังไม่ sync จึงงดตอน online)
			if not _online:
				_item_t = maxf(_item_t - delta, 0.0)
				if _item_t <= 0.0:
					_item_t = ITEM_SPAWN_EVERY
					_spawn_field_item()
		S.GOAL:
			_announce -= delta
			if _announce <= 0.0:
				place_pieces()
				state = S.KICKOFF
				_announce = 2.0
		S.END:
			pass
	_update_labels()
	# เขย่าจอ (กล้อง) ตอนได้ประตู — ห้ามขยับ root เด็ดขาด (transform root ไปตรึง RigidBody บอลค้าง!)
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta, 0.0)
		var a := _shake_t / 0.45
		cam.offset = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)) * a
	else:
		cam.offset = Vector2.ZERO
	_elapsed += delta

	# ปุ่มลัด: R เริ่มใหม่ / M เมนู / Esc เมนู
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_M):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if state == S.END and Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()

func _on_goal_left(body: Node2D) -> void:
	if not (body is Ball) or state != S.PLAY:
		return
	if body.owner_is_hero():
		return   # บอลติดเท้า — ไม่นับ (กันการเดินบดทะลุ GK; ต้องเตะเข้าเส้น)
	if _training:
		score_left += 1
		_flash_goal("ได้ๆ! ต่อไป")
	else:
		score_right += 1
		_flash_goal("GOAL!! RIGHT")
	_check_end()

func _on_goal_right(body: Node2D) -> void:
	if not (body is Ball) or state != S.PLAY:
		return
	if body.owner_is_hero():
		return
	if _training:
		score_left += 1
		_flash_goal("ได้ๆ! ต่อไป")
	else:
		score_left += 1
		_flash_goal("GOAL!! LEFT")
	_check_end()

func _flash_goal(text: String) -> void:
	_headless_debug("GOAL → %s | %d : %d" % [text, score_left, score_right])
	state = S.GOAL
	Sfx.play(&"goal", 0.02)
	_shake_t = 0.45
	_show_msg(text)
	_announce = 1.4

func _check_end() -> void:
	if score_left >= TARGET_SCORE or score_right >= TARGET_SCORE:
		_finish()

func _finish() -> void:
	state = S.END
	Sfx.play(&"whistle_end", 0.0)
	var winner := "DRAW"
	if score_left > score_right: winner = "LEFT WINS!"
	elif score_right > score_left: winner = "RIGHT WINS!"
	_headless_debug("MATCH END :: %s  %d:%d" % [winner, score_left, score_right])
	_show_msg("%s  %d : %d\nR = เริ่มใหม่   Esc = เมนู" % [winner, score_left, score_right])
	if DisplayServer.get_name() == "headless":
		# เทสต์ headless: จบแมตช์แล้วออกจากโปรแกรมเอง (ไม่ต้องพึ่ง --quit-after)
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()

func _headless_debug(text: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("[ARENA] ", text)

func _show_msg(text: String) -> void:
	msg_label.text = text
	msg_label.visible = text != ""

func _show_temporary_msg(text: String, secs: float) -> void:
	_show_msg(text)
	await get_tree().create_timer(secs).timeout
	if state == S.KICKOFF and msg_label.text == text:
		_show_msg("")

func _update_labels() -> void:
	score_label.text = "%d  :  %d" % [score_left, score_right]
	score_left_label.text = str(score_left)
	score_right_label.text = str(score_right)
	stamina1.value = hero1.stamina
	stamina2.value = hero2.stamina
	stamina2.visible = not _training
	if _training:
		timer_label.text = "--:--"
	else:
		var t := int(ceil(time_left))
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]
		if time_left <= 10.0:
			timer_label.add_theme_color_override("font_color", Color("#fecaca"))
			timer_panel.modulate = Color("#f87171") if fmod(time_left, 1.0) < 0.5 else Color.WHITE
		else:
			timer_label.add_theme_color_override("font_color", Color("#fef3c7"))
			timer_panel.modulate = Color.WHITE

func _refresh_hud_style() -> void:
	score_label.visible = false
	timer_label.add_theme_color_override("font_color", Color("#fef3c7"))
	timer_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	timer_label.add_theme_constant_override("shadow_offset_x", 1)
	timer_label.add_theme_constant_override("shadow_offset_y", 1)

# ขอเก็บพื้นที่สำหรับ online (ต่อ phase ถัดไป) — ระดับนี้ยังให้เล่นได้แม้ไม่ต่อเน็ต
func _setup_online() -> void:
	pass

func _both_connected() -> bool:
	return true

# ---------------- ไอเทมกลางสนาม (X = P1 / J = P2) ----------------

func _item_log(text: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("[ITEM] ", text)

## HUD: ช่องไอคอนไอเทมที่ถือ (16×16 ใต้แถบสไตมิน่า)
func _make_icon(pos: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.position = pos
	tr.size = Vector2(16, 16)
	tr.stretch_mode = TextureRect.STRETCH_KEEP
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = null
	$UI.add_child(tr)
	return tr

## ปล่อยไอเทมสุ่ม 1 ชิ้นในแถบกลางสนาม (คู่แข่งทั้งสองฝั่งเข้าถึงได้พอ ๆ กัน)
func _spawn_field_item() -> void:
	if get_tree().get_nodes_in_group("field_item").size() >= ITEM_MAX_ON_FIELD:
		return
	var kind: StringName = ITEM_KINDS[randi() % ITEM_KINDS.size()]
	var pos := _find_item_spot()
	var it := FieldItem.new()
	var sh := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	sh.shape = c
	sh.name = "Shape"
	it.add_child(sh)
	var icon := Sprite2D.new()
	icon.name = "Icon"
	it.add_child(icon)
	it.add_to_group("field_item")
	add_child(it)
	it.setup(kind, _item_tex[kind], pos)
	it.picked.connect(_on_item_picked)
	_item_log("spawn — %s @ %v" % [kind, pos])

func _find_item_spot() -> Vector2:
	for i in 12:
		var p := Vector2(randf_range(180.0, 300.0), randf_range(60.0, 210.0))
		if p.distance_to(ball.global_position) < 60.0:
			continue
		if p.distance_to(hero1.global_position) < 60.0:
			continue
		if p.distance_to(hero2.global_position) < 60.0:
			continue
		return p
	return Vector2(240, 135)   # หาที่ว่างไม่ได้ใน 12 ครั้ง → กลางสนาม

func _on_item_picked(hero: Hero, kind: StringName) -> void:
	_item_log("pickup — P%d เก็บ %s" % [hero.player_id, kind])
	Sfx.play(&"pickup", 0.08)
	var icon := _icon1 if hero == hero1 else _icon2
	icon.texture = _item_tex[kind]

## เรียกจาก hero.use_item() — เอฟเฟกต์ทุกชนิดจัดการที่นี่ที่เดียว
func apply_item_effect(hero: Hero, kind: StringName) -> void:
	_item_log("use — P%d ใช้ %s" % [hero.player_id, kind])
	match kind:
		&"speed":
			hero.speed_buff_t = ITEM_EFFECT_SECS
		&"heavy":
			ball.heavy_t = ITEM_EFFECT_SECS
		&"decoy":
			_spawn_decoy(hero.global_position)
		&"gate":
			_spawn_gate(hero.player_id)
	Sfx.play(&"power", 0.1)
	var icon := _icon1 if hero == hero1 else _icon2
	icon.texture = null

## 👻 อำพราง — ตัวหลอกยืนตรงจุดที่ใช้ 6 วิ บอล/คู่แข่งชนได้ (กันยิงทะลุ)
func _spawn_decoy(pos: Vector2) -> void:
	var sb := StaticBody2D.new()
	sb.position = pos
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 14)
	sh.shape = r
	sb.add_child(sh)
	var s := Sprite2D.new()
	s.texture = _item_tex[&"decoy"]
	s.modulate = Color(1.0, 1.0, 1.0, 0.92)
	sb.add_child(s)
	add_child(sb)
	_despawn_later(sb, "decoy หายไป")

## 🚪 โรเลิ่ลลิงเกต — กำแพงหน้าประตูตัวเอง 6 วิ บล็อกลูกยิงทุกลูกช่วงนั้น
func _spawn_gate(player_id: int) -> void:
	var sb := StaticBody2D.new()
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(4, 102)  # คลุมปากประตู y 84..186
	sh.shape = r
	sb.add_child(sh)
	for i in 7:
		var s := Sprite2D.new()
		s.texture = _item_tex[&"gate"]
		s.position = Vector2(0, -48 + i * 16)
		s.modulate = Color(1.0, 1.0, 1.0, 0.92)
		sb.add_child(s)
	var x := 26.0 if player_id == 1 else 454.0   # P1 เฝ้าซ้าย / P2 เฝ้าขวา
	sb.position = Vector2(x, 135.0)
	add_child(sb)
	Sfx.play(&"gate", 0.04)
	_despawn_later(sb, "gate หายไป")

## หน่วงหายไป — Timer เป็นลูกของตัวเอง เพื่อไม่มี coroutine ค้างหลัง scene โหลดใหม่
func _despawn_later(n: Node, label: String) -> void:
	var t := Timer.new()
	t.wait_time = ITEM_EFFECT_SECS
	t.one_shot = true
	t.timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free()
			_item_log(label)
	)
	n.add_child(t)
	t.start()
