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

# Dasher dash cycle (docs/GDD_3DTD.md): walk -> telegraph stop -> speed burst.
# Zero-length cycle means plain walking; the definition owns all four numbers.
enum DashPhase { CYCLE_WALK, CYCLE_TELEGRAPH, CYCLE_DASH }
var _dash_walk_time: float = 0.0
var _dash_telegraph_time: float = 0.0
var _dash_time: float = 0.0
var _dash_speed_multiplier: float = 1.0
var _dashes: bool = false
var _dash_phase: DashPhase = DashPhase.CYCLE_WALK
var _dash_phase_clock: float = 0.0
var _telegraph_ring: MeshInstance3D


func setup(path: PackedVector3Array, archetype: Archetype, new_health: float,
		new_speed: float, bounty: int, breach_damage: int,
		model_scene: PackedScene = null, dash_walk: float = 0.0,
		dash_telegraph: float = 0.0, dash_time: float = 0.0,
		dash_multiplier: float = 1.0) -> void:
	_path = path
	health = maxf(new_health, 1.0)
	max_health = health
	speed = maxf(new_speed, 0.1)
	parts_bounty = bounty
	integrity_damage = breach_damage
	is_boss = archetype == Archetype.WARDEN
	alive = true
	_dash_walk_time = maxf(dash_walk, 0.0)
	_dash_telegraph_time = maxf(dash_telegraph, 0.0)
	_dash_time = maxf(dash_time, 0.0)
	_dash_speed_multiplier = maxf(dash_multiplier, 0.1)
	_dashes = _dash_walk_time > 0.0 and _dash_telegraph_time > 0.0 and _dash_time > 0.0
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
	_add_telegraph_ring()


## Telegraph ground ring for a Dasher's pre-dash stop (GDD requires a readable
## telegraph). Scales up over the telegraph window, hidden otherwise.
func _add_telegraph_ring() -> void:
	if _dash_telegraph_time <= 0.0 or _dash_time <= 0.0:
		return
	_telegraph_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.38
	_telegraph_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.45, 0.15, 0.85)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.35, 0.05)
	ring_material.emission_energy_multiplier = 2.4
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_ring.material_override = ring_material
	_telegraph_ring.position = Vector3(0.0, 0.07, 0.0)
	_telegraph_ring.visible = false
	add_child(_telegraph_ring)


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
	var effective_speed: float = speed * slow_factor
	_update_dash_cycle(delta)
	if _dash_phase == DashPhase.CYCLE_TELEGRAPH:
		# Full stop while telegraphing: the readability window is the point.
		effective_speed = 0.0
	elif _dash_phase == DashPhase.CYCLE_DASH:
		effective_speed = speed * slow_factor * _dash_speed_multiplier
	# Cap the movement budget at the phase boundary so a dash never bleeds
	# past its own window and keeps the cycle's average rate deterministic.
	var phase_left: float = _remaining_phase_time()
	apply_step(effective_speed * minf(delta, phase_left / maxf(effective_speed, 0.0001)) if effective_speed > 0.0 else 0.0)
	_update_telegraph_visual()


## Moves along the waypoint path by at most `distance`, converting leftover
## into the next segments (matches the original overshoot-walk semantics).
func apply_step(distance: float) -> void:
	var step: float = distance
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
	if step < distance:
		# progress tracks actual distance covered, not wall-clock speed.
		progress += distance - step


func _phase_duration(phase: DashPhase) -> float:
	match phase:
		DashPhase.CYCLE_WALK:
			return _dash_walk_time
		DashPhase.CYCLE_TELEGRAPH:
			return _dash_telegraph_time
		DashPhase.CYCLE_DASH:
			return _dash_time
	return 0.0


func _remaining_phase_time() -> float:
	if not _dashes:
		return INF  # plain walkers never clamp
	return maxf(_phase_duration(_dash_phase) - _dash_phase_clock, 0.05)


func _update_dash_cycle(delta: float) -> void:
	if not _dashes:
		return
	_dash_phase_clock += delta
	if _dash_phase_clock >= _phase_duration(_dash_phase):
		_dash_phase_clock = 0.0
		match _dash_phase:
			DashPhase.CYCLE_WALK:
				_dash_phase = DashPhase.CYCLE_TELEGRAPH
			DashPhase.CYCLE_TELEGRAPH:
				_dash_phase = DashPhase.CYCLE_DASH
			DashPhase.CYCLE_DASH:
				_dash_phase = DashPhase.CYCLE_WALK


func _update_telegraph_visual() -> void:
	if _telegraph_ring == null:
		return
	_telegraph_ring.visible = _dash_phase == DashPhase.CYCLE_TELEGRAPH and alive
	if _telegraph_ring.visible:
		var phase_progress: float = clampf(_dash_phase_clock / maxf(_dash_telegraph_time, 0.01), 0.0, 1.0)
		var ring_scale: float = 1.0 + phase_progress * 0.9
		_telegraph_ring.scale = Vector3(ring_scale, 1.0, ring_scale)


func take_damage(amount: float) -> void:
	if not alive:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		alive = false
		died.emit(self)
