extends Area2D
class_name PlayerProjectile

@export var speed: float = 520.0

var damage: int = 1
var _active: bool = true


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func launch(start_position: Vector2, shot_damage: int) -> void:
	global_position = start_position
	damage = maxi(shot_damage, 1)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position.y -= speed * delta
	if global_position.y < -20.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not _active or not area.is_in_group("last_light_enemies"):
		return
	if area.has_method("take_damage"):
		_active = false
		area.call("take_damage", damage)
		queue_free()
