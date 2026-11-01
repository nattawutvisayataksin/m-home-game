extends Node2D
class_name CombatEffect

var effect_kind: int = 0
var _age: float = 0.0
var _lifetime: float = 0.22


func _ready() -> void:
	match effect_kind:
		0: _lifetime = 0.24
		1: _lifetime = 0.62
		2: _lifetime = 1.05
		3: _lifetime = 0.45
		4: _lifetime = 0.12
		5: _lifetime = 0.75
		6: _lifetime = 0.55
		_: _lifetime = 0.3
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / _lifetime, 0.0, 1.0)
	var fade: float = 1.0 - progress
	if effect_kind == 0:
		var radius: float = lerpf(3.0, 13.0, progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 12, Color(0.33, 0.9, 0.88, fade), 2.0)
	elif effect_kind == 1:
		var radius: float = lerpf(12.0, 190.0, progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.33, 0.9, 0.88, 0.8 * fade), 4.0)
	elif effect_kind == 2:
		var alpha: float = 0.24 if bool(get_meta("reduce_flashes", false)) else 0.3 + 0.18 * sin(progress * TAU * 2.0)
		var lane := Rect2(-32.0, -424.0, 64.0, 454.0)
		draw_rect(lane, Color(1.0, 0.18, 0.22, alpha * 0.18))
		draw_line(lane.position, Vector2(lane.position.x, lane.end.y), Color(1.0, 0.35, 0.28, alpha), 2.0)
		draw_line(Vector2(lane.end.x, lane.position.y), lane.end, Color(1.0, 0.35, 0.28, alpha), 2.0)
		draw_line(Vector2(-32.0, 0.0), Vector2(32.0, 0.0), Color(1.0, 0.35, 0.28, alpha), 3.0)
	elif effect_kind == 3:
		# death burst
		var radius: float = lerpf(4.0, 34.0, progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(1.0, 0.55, 0.3, fade * 0.9), 2.0)
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0
			var dist: float = lerpf(0.0, 26.0, progress)
			var p: Vector2 = Vector2(cos(angle), sin(angle)) * dist
			draw_circle(p, 2.0 * fade, Color(1.0, 0.85, 0.5, fade))
	elif effect_kind == 4:
		# muzzle flash
		var radius: float = lerpf(2.0, 9.0, progress)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.95, 0.7, fade))
		draw_line(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), Color(1.0, 0.9, 0.5, fade), 1.0)
	elif effect_kind == 5:
		# upgrade burst
		var radius: float = lerpf(8.0, 60.0, progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.95, 0.85, 0.3, fade), 3.0)
		draw_circle(Vector2.ZERO, 6.0 * fade, Color(1.0, 0.95, 0.6, fade))
	elif effect_kind == 6:
		# breach flash
		var alpha: float = 0.4 * (1.0 - progress * progress)
		draw_rect(Rect2(-170.0, -6.0, 340.0, 12.0), Color(1.0, 0.2, 0.2, alpha))
