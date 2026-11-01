extends Area2D
class_name PlayerProjectile

@export var speed: float = 520.0

var damage: int = 1
var _active: bool = true
var _trail: Array[Vector2] = []
const TRAIL_LENGTH: int = 6


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func launch(start_position: Vector2, shot_damage: int) -> void:
	global_position = start_position
	damage = maxi(shot_damage, 1)
	_trail.clear()


func _process(delta: float) -> void:
	if not _active:
		return
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_trail.append(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	global_position.y -= speed * delta
	if global_position.y < -20.0:
		queue_free()


func _draw() -> void:
	for i: int in range(_trail.size()):
		var p: Vector2 = to_local(_trail[i])
		var alpha: float = float(i + 1) / float(_trail.size() + 1) * 0.55
		draw_circle(p, 2.0, Color(0.33, 0.9, 0.88, alpha))


func _on_area_entered(area: Area2D) -> void:
	if not _active or not area.is_in_group("last_light_enemies"):
		return
	if area.has_method("take_damage"):
		_active = false
		area.call("take_damage", damage)
		queue_free()