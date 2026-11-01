extends CharacterBody2D
class_name FieldSurvivor

signal shot_requested(origin: Vector2, damage: int)

@export var move_speed: float = 260.0
@export var fire_interval: float = 0.42

var weapon_level: int = 1
var weapon_damage: int = 1
var shots_fired: int = 0
var _touch_axis: float = 0.0
var _fire_timer: float = 0.0
var _accepts_input: bool = true
var _horizontal_bounds: Vector2 = Vector2(26.0, 334.0)
var _weapon_definition: WeaponDefinition


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("last_light_player")


func configure(horizontal_bounds: Vector2, start_position: Vector2) -> void:
	_horizontal_bounds = horizontal_bounds
	global_position = start_position


func configure_weapon(definition: WeaponDefinition) -> void:
	_weapon_definition = definition
	reset_combat_state()


func set_active(active: bool) -> void:
	_accepts_input = active
	if not active:
		velocity = Vector2.ZERO


func set_touch_axis(axis: float) -> void:
	_touch_axis = clampf(axis, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	if not _accepts_input:
		velocity = Vector2.ZERO
		return

	var direction: float = clampf(Input.get_axis("move_left", "move_right") + _touch_axis, -1.0, 1.0)
	velocity = Vector2(direction * move_speed, 0.0)
	move_and_slide()
	global_position.x = clampf(global_position.x, _horizontal_bounds.x, _horizontal_bounds.y)
	global_position.y = 500.0

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		shots_fired += 1
		shot_requested.emit(global_position + Vector2.UP * 19.0, weapon_damage)


func apply_weapon_upgrade() -> bool:
	if _weapon_definition == null:
		return false
	if weapon_level >= _weapon_definition.get_max_level():
		return false
	weapon_level += 1
	weapon_damage = _weapon_definition.get_damage(weapon_level)
	fire_interval = _weapon_definition.get_fire_interval(weapon_level)
	return true


func reset_combat_state() -> void:
	weapon_level = 1
	weapon_damage = _weapon_definition.get_damage(weapon_level) if _weapon_definition != null else 1
	fire_interval = _weapon_definition.get_fire_interval(weapon_level) if _weapon_definition != null else 0.42
	_fire_timer = 0.0
	shots_fired = 0
	_accepts_input = true
