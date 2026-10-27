extends CharacterBody2D
class_name Goalkeeper
## ผู้รักษาประตูอัตโนมัติ — ยืนเฝ้าเส้นประตู, ขยับตามบอลเพื่อบล็อก
## (สลดช้าพอให้ยิงผ่านได้ถ้าโชคดี/จังหวะดี)

@export var patrol_min_y := 150.0      # เพดานที่ GK ยกมือถึงได้
@export var patrol_max_y := 242.0      # พื้นสนาม
@export var track_speed := 95.0        # ความเร็วขยับ (ต่ำ = เกมให้โอกาสยิง)
@export var anticipations := 4.0       # ยิ่งสูงยิ่งตามแบบอ่านบอลเร็ว

var _ball: Node2D

func _ready() -> void:
	_ball = get_tree().get_first_node_in_group("ball")

func _physics_process(delta: float) -> void:
	var target_y := (patrol_min_y + patrol_max_y) * 0.5
	if _ball != null and is_instance_valid(_ball):
		target_y = clampf(_ball.global_position.y, patrol_min_y, patrol_max_y)
	var dy := target_y - global_position.y
	velocity.y = clampf(dy * anticipations, -track_speed, track_speed)
	velocity.x = 0.0
	move_and_slide()

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
