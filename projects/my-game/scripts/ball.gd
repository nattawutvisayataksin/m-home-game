extends RigidBody2D
class_name Ball
## บอล: มีความเป็นเจ้าของ (possession) — ติดกับ Hero จนกว่าจะโดนเตะ/แย่ง
## ครองได้: เดินชนบอล (ขณะบอลว่าง), ยิง/แย่ง: กดเตะ C/K หรือสกิล V/L

const START := Vector2(240, 135)   # จุดวางบอลกลางสนาม

var owner_hero: Hero = null
var _ignore_until := 0.0   # วินาทีจากตอนเตะออก — ไม่ให้ใคร "ครอง" ใหม่ก่อนเวลานี้
var heavy_t := 0.0         # ไอเทม "บอลหนัก" — เวลาที่เหลือ (>0 = บอลไหลลื่น ไกลกว่าเดิม)
var _bounce_t := 0.0       # throttle เสียงเด้ง (กันสแปมตอนไถกับผนัง)

const NORMAL_DAMP := 0.45  # ตรงกับ linear_damp ใน arena.tscn — แก้คู่กัน
const HEAVY_DAMP := 0.15

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## ชนแรงพองาม (โพสต์/กำแพง/GK/ตัว hero) → เสียงเด้ง
func _on_body_entered(_body: Node) -> void:
	if _bounce_t <= 0.0 and linear_velocity.length() > 90.0:
		_bounce_t = 0.15
		Sfx.play(&"bounce")

func _physics_process(delta: float) -> void:
	# บอลหนัก: ลดแรงเสียดทานชั่วคราว → เตะแล้วลื่นไกลกว่าเดิม
	_bounce_t = maxf(_bounce_t - delta, 0.0)
	if heavy_t > 0.0:
		heavy_t = maxf(heavy_t - delta, 0.0)
		linear_damp = HEAVY_DAMP
	else:
		linear_damp = NORMAL_DAMP
	if owner_hero != null and is_instance_valid(owner_hero):
		# กาวบอล — clamp ไม่ให้ teleport เข้ากรอบโน้ต/หลังเส้น (กัน poke-through)
		# และหาจุดวางที่ไม่ทับตัว hero อื่น (กันบอลติดคาใน collider คู่แข่งจนยิงไม่ออก)
		var offset := owner_hero.aim * 16.0
		for cand in [offset, owner_hero.aim * 10.0, offset.orthogonal() * 0.8 + owner_hero.aim * 8.0, -offset.orthogonal() * 0.8 + owner_hero.aim * 8.0, owner_hero.aim * -10.0]:
			var spot := Vector2(
				clampf(owner_hero.global_position.x + cand.x, 28.0, 452.0),
				clampf(owner_hero.global_position.y + cand.y, 16.0, 254.0))
			var blocked := false
			for h in get_tree().get_nodes_in_group("hero"):
				var hn := h as Node2D
				if hn != null and hn != owner_hero and hn.global_position.distance_to(spot) < 14.0:
					blocked = true
					break
			if not blocked:
				global_position = spot
				linear_velocity = Vector2.ZERO
				angular_velocity = 0.0
				sleeping = false   # ห้ามหลับ — ไม่งั้น Area2D (kick zone) ตรวจไม่เจอ
				return
		global_position = Vector2(clampf(owner_hero.global_position.x - owner_hero.aim.x * 10.0, 28.0, 452.0), clampf(owner_hero.global_position.y, 16.0, 254.0))
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		sleeping = false

func owner_is_hero() -> bool:
	return owner_hero != null and is_instance_valid(owner_hero)

## เดินชนบอล → ได้ครอง (คืน false ถ้ามีเจ้าของอื่น / เพิ่งเตะไปเมื่อครู่)
func try_claim(hero: Hero) -> bool:
	if owner_is_hero() and owner_hero != hero:
		return false
	if _now() < _ignore_until:
		return false
	owner_hero = hero
	sleeping = false
	return true

func release(new_velocity: Vector2, ignore_secs := 0.35) -> void:
	owner_hero = null
	_ignore_until = _now() + ignore_secs
	linear_velocity = new_velocity
	sleeping = false
## Hero สัมผัสบอลด้วยปุ่มเตะ/สกิล:
##   คือเจ้าของ → ปล่อยยิงตาม power
##   มีเจ้าของคนอื่น → แย่ง! (บอลหลุด + เจ้าของเดิมมือหนักชั่วขณะ)
##   บอลว่าง → ปล่อยยิง
func receive_touch(hero: Hero, power: float) -> void:
	if owner_hero == hero and is_instance_valid(owner_hero):
		release(hero.aim * power)
	elif owner_is_hero():
		var loser := owner_hero
		if loser.has_method("stun"):
			loser.stun(0.45)
		# บอลฉีกหลุดเหมือนฟุตบอลจริง: ทิศหนีจากตัวเจ้าของเดิม ผสมทิศเล็งของคนแย่ง
		# (กันบอลดีดสวนกลับเข้าตัวเจ้าของ → ติดคา ping-pong ระหว่างสองคน)
		var away := (global_position - loser.global_position).normalized()
		var steal_dir := away.lerp(hero.aim, 0.45).normalized()
		release(steal_dir * maxf(power * 0.35, 120.0), 0.0)
	else:
		release(hero.aim * power, 0.0)

func reset() -> void:
	owner_hero = null
	_ignore_until = 0.0
	heavy_t = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = START

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func kick(direction: Vector2, power: float) -> void:
	linear_velocity += direction.normalized() * power