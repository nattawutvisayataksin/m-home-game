extends Node2D
class_name CombatEffect

var effect_kind: int = 0
var _age: float = 0.0
var _lifetime: float = 0.22


func _ready() -> void:
	_lifetime = 0.24 if effect_kind == 0 else (0.62 if effect_kind == 1 else 1.05)
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / _lifetime, 0.0, 1.0)
	if effect_kind == 0:
		var radius: float = lerpf(3.0, 13.0, progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 12, Color(0.33, 0.9, 0.88, 1.0 - progress), 2.0)
	elif effect_kind == 1:
		var radius: float = lerpf(12.0, 190.0, progress)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.33, 0.9, 0.88, 0.8 * (1.0 - progress)), 4.0)
	else:
		var alpha: float = 0.24 if bool(get_meta("reduce_flashes", false)) else 0.3 + 0.18 * sin(progress * TAU * 2.0)
		var lane := Rect2(-32.0, -424.0, 64.0, 454.0)
		draw_rect(lane, Color(1.0, 0.18, 0.22, alpha * 0.18))
		draw_line(lane.position, Vector2(lane.position.x, lane.end.y), Color(1.0, 0.35, 0.28, alpha), 2.0)
		draw_line(Vector2(lane.end.x, lane.position.y), lane.end, Color(1.0, 0.35, 0.28, alpha), 2.0)
		draw_line(Vector2(-32.0, 0.0), Vector2(32.0, 0.0), Color(1.0, 0.35, 0.28, alpha), 3.0)
