extends Area2D
class_name DrifterEnemy

signal defeated(charge_reward: int)
signal breached(integrity_damage: int)
signal boss_warning(target_x: float)
signal boss_attack(target_x: float)
signal boss_defeated
signal struck(position: Vector2)
signal health_changed(current: int, maximum: int)

enum Archetype { DRIFTER, SKITTER, DASHER, WARDEN }

const DRIFTER_TEXTURE: Texture2D = preload("res://assets/art/enemies/drifter.png")
const SKITTER_TEXTURE: Texture2D = preload("res://assets/art/enemies/skitter.png")
const DASHER_TEXTURE: Texture2D = preload("res://assets/art/enemies/dasher.png")
const WARDEN_TEXTURE: Texture2D = preload("res://assets/art/enemies/rift_warden.png")

@export var descent_speed: float = 30.0
@export var integrity_damage: int = 1
@export var archetype: Archetype = Archetype.DRIFTER

var health: int = 1
var max_health: int = 1
var _breach_y: float = 530.0
var _active: bool = true
var _elapsed: float = 0.0
var _origin_x: float = 180.0
var _horizontal_bounds: Vector2 = Vector2(30.0, 330.0)
var _dash_timer: float = 0.0
var _dash_active: bool = false
var _warden_attack_timer: float = 7.0
var _warden_warning: bool = false
var _warning_x: float = 180.0
var _resonance_reward: int = 25

@onready var _body: Polygon2D = $Body
@onready var _core: Polygon2D = $Core
@onready var _telegraph: Line2D = $Telegraph
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("last_light_enemies")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.hide()
	_core.hide()
	_build_telegraph()
	_apply_archetype_visuals()


func configure(
	start_position: Vector2,
	max_health: int,
	speed: float,
	breach_y: float,
	kind: Archetype = Archetype.DRIFTER,
	horizontal_bounds: Vector2 = Vector2(30.0, 330.0),
	resonance_reward: int = 25
) -> void:
	global_position = start_position
	health = maxi(max_health, 1)
	self.max_health = health
	descent_speed = speed
	_breach_y = breach_y
	archetype = kind
	_origin_x = start_position.x
	_horizontal_bounds = horizontal_bounds
	_resonance_reward = resonance_reward
	_dash_timer = 0.8
	_warden_attack_timer = 6.0
	if archetype == Archetype.WARDEN:
		_breach_y = 100000.0
		scale = Vector2(1.8, 1.8)
	_apply_archetype_visuals()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if archetype == Archetype.WARDEN:
		_process_warden(delta)
	elif archetype == Archetype.SKITTER:
		global_position.y += descent_speed * delta
		global_position.x = clampf(_origin_x + sin(_elapsed * 3.2) * 34.0, _horizontal_bounds.x, _horizontal_bounds.y)
	elif archetype == Archetype.DASHER:
		_process_dasher(delta)
	else:
		global_position.y += descent_speed * delta
	if global_position.y >= _breach_y:
		_active = false
		breached.emit(integrity_damage)
		queue_free()


func _process_dasher(delta: float) -> void:
	if _dash_active:
		global_position.y += descent_speed * 3.6 * delta
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dash_active = false
			_dash_timer = 1.35
			_telegraph.hide()
		return

	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dash_active = true
		_dash_timer = 0.55
		_telegraph.show()
		return
	global_position.y += descent_speed * 0.65 * delta
	_telegraph.visible = _dash_timer < 0.45


func _process_warden(delta: float) -> void:
	global_position.x = 180.0 + sin(_elapsed * 0.72) * 76.0
	global_position.y = 170.0 + sin(_elapsed * 1.1) * 10.0
	_warden_attack_timer -= delta
	if _warden_attack_timer <= 0.0:
		if not _warden_warning:
			_warden_warning = true
			_warning_x = 180.0
			boss_warning.emit(_warning_x)
			_warden_attack_timer = 1.0
		else:
			_warden_warning = false
			boss_attack.emit(_warning_x)
			_warden_attack_timer = 6.0
	_telegraph.visible = _warden_warning
	if _warden_warning:
		_telegraph.position.x = _warning_x - global_position.x


func take_damage(amount: int, grant_charge: bool = true) -> bool:
	if not _active or amount <= 0:
		return false
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	struck.emit(global_position)
	if health == 0:
		_active = false
		defeated.emit(_resonance_reward if grant_charge else 0)
		if archetype == Archetype.WARDEN:
			boss_defeated.emit()
		queue_free()
		return true
	return false


func is_boss() -> bool:
	return archetype == Archetype.WARDEN


func set_attack_target(target_x: float) -> void:
	_warning_x = clampf(target_x, _horizontal_bounds.x, _horizontal_bounds.y)


func deactivate() -> void:
	_active = false


func _build_telegraph() -> void:
	_telegraph.clear_points()
	for i: int in range(25):
		var angle: float = TAU * float(i) / 24.0
		_telegraph.add_point(Vector2(cos(angle), sin(angle)) * 23.0)
	_telegraph.width = 2.0
	_telegraph.default_color = Color("#ffc857")
	_telegraph.closed = true
	_telegraph.hide()


func _apply_archetype_visuals() -> void:
	if not is_node_ready():
		return
	match archetype:
		Archetype.SKITTER:
			_sprite.texture = SKITTER_TEXTURE
			_body.color = Color("#b18cff")
			_core.color = Color("#e8d8ff")
		Archetype.DASHER:
			_sprite.texture = DASHER_TEXTURE
			_body.color = Color("#ff9a57")
			_core.color = Color("#fff1bd")
		Archetype.WARDEN:
			_sprite.texture = WARDEN_TEXTURE
			_body.color = Color("#ff4f78")
			_core.color = Color("#ffc857")
		_:
			_sprite.texture = DRIFTER_TEXTURE
			_body.color = Color("#ff6d69")
			_core.color = Color("#ffc857")
