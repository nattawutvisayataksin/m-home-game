extends CharacterBody2D
class_name Goalkeeper
## ผู้รักษาประตูแบบ "เมโทรนอม" — ขยับขึ้น-ลงตามแนวประตูตลอดเวลา จังหวะคงที่ ทำนายได้
## ไม่อ่านบอล ไม่ไดฟ์ — จังหวะเดียวกันทั้งสองฝั่ง ทุกโหมด easy/normal/hard
## ตั้งใจให้เกมมีประตูเยอะ: เซฟเกิดเฉพาะลูกยิงตรง ๆ ที่ชนตัว GK พอดี
## เลือกจังหวะ/มุมยิงตอน GK อยู่ไกล = ประตู (ฝีมือคนเล่น + โชคเล็กน้อย)

@export var patrol_min_y := 150.0      # ขอบบนช่วงขยับ (scene override 100)
@export var patrol_max_y := 242.0      # ขอบล่างช่วงขยับ (scene override 170)
@export var patrol_period := 4.0       # วินาทีต่อรอบเต็ม (ขึ้น+ลง) — จังหวะคงที่ตลอดแมตช์
@export var patrol_speed_max := 90.0   # cap ความเร็ว (กัน snap แรงเกินหลังโดนบอล/กำแพงดัน)
@export var clear_power := 250.0       # แรงผลักบอลออกจากกรอบเมื่อบอลมากอดติดตัว (headless เท่านั้น)

var _ball: Node2D
var _guard_x := 14.0   # แกน x ตายตัว (กัน drift เข้าหลุมประตูจาก recovery/ซ้อนทับ)
var _t := 0.0          # นาฬิกาเมโทรนอม — ทั้งสองฝั่งนับเท่ากัน → จังหวะตรงกันเป๊ะ
var _save_log_t := 0.0 # throttle log เซฟ (ลดสแปมตอนบอลในตัว GK)
var _clear_t := 0.0    # cooldown การผลักบอลออก (กันสแปมด้วย)

func _ready() -> void:
	_ball = get_tree().get_first_node_in_group("ball")
	_guard_x = global_position.x

func _physics_process(delta: float) -> void:
	_t += delta
	var mid := (patrol_min_y + patrol_max_y) * 0.5
	var amp := (patrol_max_y - patrol_min_y) * 0.5
	var ideal_y := mid + amp * sin(TAU * _t / patrol_period)
	# ตามตารางเวลาให้เป๊ะ: ความเร็ว = ระยะถึงตำแหน่งอุดมคติ / เดลต้า
	# (ถ้าโดนบอล/กำแพงดันเฉี่ยว รอบถัดไปจะวิ่งกลับเข้าจังหวะเอง)
	var v := clampf((ideal_y - global_position.y) / delta, -patrol_speed_max, patrol_speed_max)
	velocity = Vector2(0.0, v)
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
	_t = 0.0   # เริ่มจังหวะใหม่ (ตำแหน่งอุดมคติที่ t=0 คือกลางปากประตู)
