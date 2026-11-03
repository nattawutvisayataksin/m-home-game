class_name TDEnemy
extends Node3D

## Greybox enemy walking a fixed waypoint path toward the Shelter.
## Movement is owned by TDEnemy (_physics_process); the run resets slow_factor
## each physics frame before children process, then Tangle sites apply it.

signal died(enemy: TDEnemy)
signal leaked(enemy: TDEnemy)

enum Archetype { DRIFTER, SKITTER, DASHER, WARDEN }

var health: float = 1.0
var max_health: float = 1.0
var speed: float = 2.0
var parts_bounty: int = 10
var integrity_damage: int = 1
var slow_factor: float = 1.0
var progress: float = 0.0
var is_boss: bool = false
var alive: bool = true

var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_index: int = 1
var _body: MeshInstance3D


func setup(path: PackedVector3Array, archetype: Archetype, new_health: float,
		new_speed: float, bounty: int, breach_damage: int) -> void:
	_path = path
	health = maxf(new_health, 1.0)
	max_health = health
	speed = maxf(new_speed, 0.1)
	parts_bounty = bounty
	integrity_damage = breach_damage
	is_boss = archetype == Archetype.WARDEN
	alive = true
	add_to_group("td_enemies")
	_build_body(archetype)


func _build_body(archetype: Archetype) -> void:
	_body = MeshInstance3D.new()
	var mesh: Mesh
	var tint: Color
	var body_height: float
	match archetype:
		Archetype.SKITTER:
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.35
			capsule.height = 0.9
			mesh = capsule
			tint = Color(0.78, 0.7, 0.4)
			body_height = 0.9
		Archetype.DASHER:
			var wedge := BoxMesh.new()
			wedge.size = Vector3(0.6, 1.4, 1.4)
			mesh = wedge
			tint = Color(0.75, 0.42, 0.3)
			body_height = 1.4
		Archetype.WARDEN:
			var boss_box := BoxMesh.new()
			boss_box.size = Vector3(2.4, 3.2, 2.4)
			mesh = boss_box
			tint = Color(0.55, 0.2, 0.24)
			body_height = 3.2
		_:
			var drifter_box := BoxMesh.new()
			drifter_box.size = Vector3(1.0, 1.6, 1.0)
			mesh = drifter_box
			tint = Color(0.62, 0.66, 0.58)
			body_height = 1.6
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	_body.mesh = mesh
	_body.material_override = material
	_body.position = Vector3(0.0, body_height * 0.5, 0.0)
	add_child(_body)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var step: float = speed * slow_factor * delta
	while step > 0.0 and _waypoint_index < _path.size():
		var target: Vector3 = _path[_waypoint_index]
		var remaining: float = global_position.distance_to(target)
		if step >= remaining:
			global_position = target
			step -= remaining
			_waypoint_index += 1
			if _waypoint_index >= _path.size():
				alive = false
				leaked.emit(self)
				return
		else:
			global_position = global_position.move_toward(target, step)
			step = 0.0
	progress += speed * slow_factor * delta


func take_damage(amount: float) -> void:
	if not alive:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		alive = false
		died.emit(self)


# Replaced later by a real telegraph; greybox Dashers just spawn faster.
func dash_speed_scale(_scale: float) -> void:
	pass
