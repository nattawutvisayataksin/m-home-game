extends RigidBody2D
class_name Ball
## บอล: มีความเป็นเจ้าของ (possession) — ติดกับ Hero จนกว่าจะโดนเตะ/แย่ง
## ครองได้: เดินชนบอล (ขณะบอลว่าง), ยิง/แย่ง: กดเตะ C/K หรือสกิล V/L

const START := Vector2(240, 135)   # จุดวางบอลกลางสนาม

var owner_hero: Hero = null
var _ignore_until := 0.0   # วินาทีจากตอนเตะออก — ไม่ให้ใคร "ครอง" ใหม่ก่อนเวลานี้

func _physics_process(_delta: float) -> void:
	if owner_hero != null and is_instance_valid(owner_hero):
		global_position = owner_hero.global_position + owner_hero.aim * 11.0
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0

func owner_is_hero() -> bool:
	return owner_hero != null and is_instance_valid(owner_hero)

## เดินชนบอล → ได้ครอง (คืน false ถ้ามีเจ้าของอื่น / เพิ่งเตะไปเมื่อครู่)
func try_claim(hero: Hero) -> bool:
	if owner_is_hero() and owner_hero != hero:
		return false
	if _now() < _ignore_until:
		return false
	owner_hero = hero
	return true

func release(new_velocity: Vector2, ignore_secs := 0.35) -> void:
	owner_hero = null
	_ignore_until = _now() + ignore_secs
	linear_velocity = new_velocity

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
		release(hero.aim * maxf(power * 0.35, 120.0), 0.0)
	else:
		release(hero.aim * power, 0.0)

func reset() -> void:
	owner_hero = null
	_ignore_until = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = START

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func kick(direction: Vector2, power: float) -> void:
	linear_velocity += direction.normalized() * power