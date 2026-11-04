class_name TDEnemy
extends Node3D

## Enemy walking a fixed waypoint path toward the Shelter.
## When a model_scene is provided via setup(), instantiates the low-poly .glb;
## otherwise falls back to greybox primitives.
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
var _body: Node3D  ## MeshInstance3D for greybox, or the .glb root node
var _world_time: float = 0.0
var _base_body_position: Vector3 = Vector3.ZERO
var _slow_visual: MeshInstance3D


func setup(path: PackedVector3Array, archetype: Archetype, new_health: float,
		new_speed: float, bounty: int, breach_damage: int,
		model_scene: PackedScene = null) -> void:
	_path = path
	health = maxf(new_health, 1.0)
	max_health = health
	speed = maxf(new_speed, 0.1)
	parts_bounty = bounty
	integrity_damage = breach_damage
	is_boss = archetype == Archetype.WARDEN
	alive = true
	add_to_group("td_enemies")
	_build_body(archetype, model_scene)


func _build_body(archetype: Archetype, model_scene: PackedScene = null) -> void:
	if model_scene != null:
		_body = model_scene.instantiate()
		_body.name = "Model"
		add_child(_body)
		_base_body_position = _body.position
		_add_slow_visual()
		return

	var mesh_inst := MeshInstance3D.new()
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
	mesh_inst.mesh = mesh
	mesh_inst.material_override = material
	mesh_inst.position = Vector3(0.0, body_height * 0.5, 0.0)
	_body = mesh_inst
	add_child(_body)
	_base_body_position = _body.position
	_add_slow_visual()


func _add_slow_visual() -> void:
	_slow_visual = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.42
	ring_mesh.outer_radius = 0.5
	_slow_visual.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.1, 0.7, 1.0, 0.78)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.08, 0.65, 1.0)
	ring_material.emission_energy_multiplier = 2.8
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slow_visual.material_override = ring_material
	_slow_visual.position = Vector3(0.0, 0.1, 0.0)
	_slow_visual.visible = false
	add_child(_slow_visual)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_world_time += delta
	if _body != null and is_instance_valid(_body):
		var bob_amount: float = 0.035 if not is_boss else 0.06
		_body.position = _base_body_position + Vector3(0.0, sin(_world_time * 5.0 + progress) * bob_amount, 0.0)
		_body.rotation.y = sin(_world_time * 1.7 + progress) * 0.035
	if _slow_visual != null:
		_slow_visual.visible = slow_factor < 0.99
		if _slow_visual.visible:
			_slow_visual.rotation.y += delta * 5.0
			_slow_visual.scale = Vector3.ONE * (1.0 + sin(_world_time * 8.0) * 0.12)
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
