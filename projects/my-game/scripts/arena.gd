extends Node2D
## Kick Hero Arena — จังหวะแข่ง: KICKOFF → PLAY (จับเวลา) → GOAL (พักกระพริบ) → END
## โหมดจาก Game.mode: local / easy / normal / hard / training / online*

enum S { KICKOFF, PLAY, GOAL, END }

const MATCH_TIME := 90.0
const TARGET_SCORE := 3

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

var state := S.KICKOFF
var score_left := 0
var score_right := 0
var time_left := MATCH_TIME
var _announce := 2.0
var _debug_tick := 0.0    # debug สถานะเป็นช่วง ๆ (headless เท่านั้น)
var _elapsed := 0.0       # เวลาที่ผ่านไปในแมตช์ (เพื่อ debug/เทสต์)
var _training := false
var _online := false

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
	place_pieces()
	_update_labels()

func place_pieces() -> void:
	ball.reset()
	hero1.reset_to(Vector2(150, 135))
	hero2.reset_to(Vector2(330, 135))
	hero1.aim = Vector2.RIGHT
	hero1._face_aim()
	hero2.aim = Vector2.LEFT
	hero2._face_aim()

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
				_show_msg("")
		S.PLAY:
			if not _training:
				time_left = maxf(time_left - delta, 0.0)
				if time_left <= 0.0:
					_finish()
		S.GOAL:
			_announce -= delta
			if _announce <= 0.0:
				place_pieces()
				state = S.KICKOFF
				_announce = 2.0
		S.END:
			pass
	_update_labels()
	_elapsed += delta
	_debug_tick -= delta
	if _debug_tick <= 0.0 and DisplayServer.get_name() == "headless":
		_debug_tick = 5.0
		var owner_txt := "free"
		if ball.owner_is_hero():
			owner_txt = "P%d" % ball.owner_hero.player_id
		print("[ARENA] tick t=%ds state=%s score=%d:%d owner=%s ball=%v gkY=%v" % [
			int(_elapsed), state, score_left, score_right, owner_txt, ball.global_position, gk_left.global_position])

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
	if DisplayServer.get_name() == "headless":
		print("[ARENA] ball@=%v v=%v gkY=%v" % [ball.global_position, ball.linear_velocity, gk_left.global_position])
	state = S.GOAL
	_show_msg(text)
	_announce = 1.4

func _check_end() -> void:
	if score_left >= TARGET_SCORE or score_right >= TARGET_SCORE:
		_finish()

func _finish() -> void:
	state = S.END
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
	stamina1.value = hero1.stamina
	stamina2.value = hero2.stamina
	stamina2.visible = not _training
	if _training:
		timer_label.text = "--:--"
	else:
		var t := int(ceil(time_left))
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]

# ขอเก็บพื้นที่สำหรับ online (ต่อ phase ถัดไป) — ระดับนี้ยังให้เล่นได้แม้ไม่ต่อเน็ต
func _setup_online() -> void:
	pass

func _both_connected() -> bool:
	return true
