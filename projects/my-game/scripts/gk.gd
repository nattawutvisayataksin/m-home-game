extends CharacterBody2D
class_name Goalkeeper
## ผู้รักษาประตูอัตโนมัติ — ยืนเฝ้าเส้นประตู, ขยับตามบอลเพื่อบล็อก
## (สลดช้าพอให้ยิงผ่านได้ถ้าโชคดี/จังหวะดี)

@export var patrol_min_y := 150.0      # เพดานที่ GK ยกมือถึงได้
@export var patrol_max_y := 242.0      # พื้นสนาม
@export var track_speed := 75.0        # ความเร็วขยับ (ต่ำ = เกมให้โอกาสยิง)
@export var anticipations := 6.0       # ยิ่งสูงยิ่งตามแบบอ่านบอลเร็ว
@export var predict_lead := 0.20       # อ่านทางบอลล่วงหน้าแค่หน้าต่างสั้น ๆ (วิ) — ไกลกว่านี้ยังเห็นไม่ทัน
@export var misread := 11.0            # ความเพี้ยนในการอ่านจุดตัด (px) — GK คนจริงอ่านผิดบางครั้ง
@export var clear_power := 250.0       # แรงผลักบอลออกจากกรอบเมื่อบอลมากอดติดตัว

var _ball: Node2D
var _guard_x := 14.0   # แกน x ตายตัว (กัน drift เข้าหลุมประตูจาก recovery/ซ้อนทับ)
var _noise := 0.0      # ค่าเพี้ยนการอ่านในรอบปัจจุบัน
var _noise_t := 0.0
var _save_log_t := 0.0 # throttle log เซฟ (ลดสแปมตอนบอลในตัว GK)
var _clear_t := 0.0    # cooldown การผลักบอลออก (กันสแปมด้วย)
var _dive_y := -1.0    # เป้า y ที่ล็อกไว้ต่อลูกยิงหนึ่งลูก (-1 = ยังไม่ล็อก)

func _ready() -> void:
	_ball = get_tree().get_first_node_in_group("ball")
	_guard_x = global_position.x

func _physics_process(delta: float) -> void:
	# สุ่มค่าเพี้ยนการอ่านใหม่เป็นรอบ ๆ (เหมือนอ่านผิดทุกครั้งยิงใหม่)
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = 0.35
		_noise = randf_range(-misread, misread)
	var target_y := (patrol_min_y + patrol_max_y) * 0.5
	var diving := false
	if _ball != null and is_instance_valid(_ball):
		var v: Vector2 = (_ball as RigidBody2D).linear_velocity
		var owned: bool = (_ball as Ball).owner_is_hero()
		# บอลฉีดเข้าหาเส้นประตูนี้จริงไหม (|v.x| หนักพอ + จุดตัดอยู่ข้างหน้า)
		var t_hit := -1.0
		if absf(v.x) > 110.0:
			var tx := (_guard_x - _ball.global_position.x) / v.x
			if tx > 0.0:
				t_hit = tx
		if t_hit >= 0.0 and t_hit <= predict_lead:
			# หน้าต่างไดฟ์: ล็อกจุดตัดครั้งเดียวต่อลูก (อ่าน ๆ ผิดบ้างตาม misread)
			# และไม่แก้เป้าอีกแม้บอลเบี่ยง — คนเฝ้าประตูกระโดดแล้วกระโดดแล้วเปลี่ยนไม่ได้
			if _dive_y < 0.0:
				_dive_y = clampf(_ball.global_position.y + v.y * t_hit + _noise, patrol_min_y, patrol_max_y)
			target_y = _dive_y
			diving = true
		elif t_hit >= 0.0 and not owned:
			# ลูกยิงกำลังบินแต่ยังไกล — ไม่ตาม ball.y ล่วงหน้า (กัน pre-tracking ปิดประตูตาย)
			# ยืนกลางปากประตูรอแล้วค่อยไดฟ์ตอนลูกเข้าใกล้
			_dive_y = -1.0
			target_y = (patrol_min_y + patrol_max_y) * 0.5
		else:
			# บอลหลุดจากแนวยิง (เลี้ยง/ค่อย ๆ ลอย/ยิงข้ามหลัง) — ตัดสถานะไดฟ์
			_dive_y = -1.0
			if owned:
				# ขณะบอลถูกกาว (เลี้ยง) — ยืนเกาะกลางปากประตูเอียงตามบอลเบา ๆ
				target_y = clampf(_ball.global_position.y * 0.25 + (patrol_min_y + patrol_max_y) * 0.375, patrol_min_y, patrol_max_y)
			else:
				target_y = clampf(_ball.global_position.y, patrol_min_y, patrol_max_y)
	else:
		_dive_y = -1.0
	var cap := track_speed * 1.45 if diving else track_speed
	var dy := target_y - global_position.y
	velocity.y = clampf(dy * anticipations, -cap, cap)
	velocity.x = 0.0
	move_and_slide()
	position.x = _guard_x   # hard lock — GK ต้องอยู่บนเส้นประตูเสมอ
	if DisplayServer.get_name() == "headless":
		_punch_clear(delta)

## เคลียร์บอลที่มากอดอยู่บอลช้า (กันบอลแช่ข้างเท้าตัวเอง) — ผลักกลับเข้าสนาม
func _punch_clear(delta: float) -> void:
	_clear_t -= delta
	_save_log_t -= delta
	var b := get_tree().get_first_node_in_group("ball") as Ball
	if b == null or not is_instance_valid(b):
		return
	var touching := false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == b:
			touching = true
			break
	if not touching:
		return
	var v := b.linear_velocity
	if _clear_t <= 0.0 and v.length() <= 60.0 and not b.owner_is_hero():
		_clear_t = 0.6
		var away := Vector2(1.0 if _guard_x < 240.0 else -1.0, randf_range(-0.5, 0.5)).normalized()
		b.release(away * clear_power, 0.6)
		print("[GK] CLEAR — ผลักบอลออกจากกรอบ v=%v" % [away * clear_power])
	elif _save_log_t <= 0.0 and v.length() > 140.0:
		_save_log_t = 0.5
		print("[GK] SAVE — ball %v v=%v" % [b.global_position, v])

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
