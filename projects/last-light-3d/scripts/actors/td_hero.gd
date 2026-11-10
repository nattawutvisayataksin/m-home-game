class_name TDHero
extends Node3D

## Approved hero (director decision, 2026-11-09; formerly the dev-gated
## prototype): a code-built low-poly operative with smooth WASD movement, a
## leaning/bobbing gait and an emissive rifle. Movement is discrete-world WASD
## (the tactical camera faces north, so screen-up is -z). Attacks ride the
## enemy damage seam (take_damage) so the hero and towers share one balancing
## hook. All tuning lives in TDHeroDefinition (.tres); this script never
## hardcodes balance.

## Fired after a strike lands (world position of the impact) - the run spawns
## the VFX/SFX/metrics around it, keeping this node presentation-free.
signal struck(impact_position: Vector3)

## Test seam: when true, move_input is consumed as-is (headless tests never
## press real keys).
var use_seam_input: bool = false
## +x/+z world axes (camera-relative by construction); normalized lazily.
var move_input: Vector2 = Vector2.ZERO

var definition: TDHeroDefinition = null

var _velocity_smooth: Vector3 = Vector3.ZERO
var _cooldown_clock: float = 0.0
var _half_bounds: Vector2 = Vector2.ZERO
var _walk_clock: float = 0.0

var _model_yaw: Node3D
var _lean_pivot: Node3D
var _torso: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _rifle_barrel: Node3D
var _base_body_y: float = 0.0


func setup(config: TDHeroDefinition, half_ground_bounds: Vector2) -> void:
	definition = config
	_half_bounds = half_ground_bounds
	_build_body()


func muzzle_position() -> Vector3:
	if _rifle_barrel != null:
		return _rifle_barrel.to_global(Vector3(0.0, 0.02, 0.5))
	return global_position + Vector3(0.0, 1.0, 0.0)


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_cooldown_clock = maxf(_cooldown_clock - delta, 0.0)
	if not use_seam_input:
		move_input = _read_move_keys()
	_update_movement(delta)
	_update_gait(delta)


## Strikes the best target inside the range/arc cone (test seam: call it
## directly). Returns true when a target was hit.
func try_attack() -> bool:
	if definition == null or _cooldown_clock > 0.0:
		return false
	var target := _find_target()
	if target == null:
		return false
	_cooldown_clock = definition.attack_cooldown
	target.take_damage(definition.attack_damage)
	var impact: Vector3 = target.global_position + Vector3(0.0, 0.6, 0.0)
	struck.emit(impact)
	_play_recoil()
	return true


## Player-initiated strike: snap-aim at the requested world point first, then
## the range/arc/cooldown rules decide whether something is actually hit.
func strike_at(world_position: Vector3) -> bool:
	var direction := Vector3(world_position.x - global_position.x, 0.0, world_position.z - global_position.z)
	if direction.length_squared() > 0.01:
		_model_yaw.rotation.y = lerp_angle(_model_yaw.rotation.y, atan2(direction.x, direction.z), 0.6)
	return try_attack()


## Nearest living enemy inside the range circle and the facing cone.
func _find_target() -> TDEnemy:
	var best: TDEnemy = null
	var best_distance: float = definition.attack_range
	var facing := Vector3(sin(_model_yaw.rotation.y), 0.0, cos(_model_yaw.rotation.y))
	var half_arc: float = deg_to_rad(definition.attack_arc_deg) * 0.5
	for node: Node in get_tree().get_nodes_in_group("td_enemies"):
		var enemy := node as TDEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance: float = to_enemy.length()
		if distance > best_distance:
			continue
		if distance > 0.05 and facing.angle_to(to_enemy) > half_arc:
			continue
		best = enemy
		best_distance = distance
	return best


func _read_move_keys() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	return input


## Acceleration-"lerp" toward the keyed velocity (frame-rate independent),
## then facing/lean follow the smoothed velocity so the motion reads fluid.
func _update_movement(delta: float) -> void:
	var target_velocity: Vector3 = Vector3(move_input.x, 0.0, move_input.y)
	if target_velocity.length_squared() > 1.0:
		target_velocity = target_velocity.normalized()
	target_velocity *= definition.move_speed
	var smoothing: float = 1.0 - exp(-definition.move_accel * delta)
	_velocity_smooth = _velocity_smooth.lerp(target_velocity, smoothing)
	global_position += _velocity_smooth * delta
	_clamp_to_ground()

	var speed: float = Vector3(_velocity_smooth.x, 0.0, _velocity_smooth.z).length()
	if speed > 0.25:
		var desired_yaw: float = atan2(_velocity_smooth.x, _velocity_smooth.z)
		_model_yaw.rotation.y = lerp_angle(_model_yaw.rotation.y, desired_yaw, minf(delta * 14.0, 1.0))
	var lean: float = (speed / definition.move_speed) * deg_to_rad(definition.body_lean_deg)
	_lean_pivot.rotation.x = lerp_angle(_lean_pivot.rotation.x, lean, minf(delta * 10.0, 1.0))


## The hero stays on the walkable ground plane with a small margin.
func _clamp_to_ground() -> void:
	var margin: float = 1.0
	var x: float = clampf(global_position.x, -_half_bounds.x + margin, _half_bounds.x - margin)
	var z: float = clampf(global_position.z, -_half_bounds.y + margin, _half_bounds.y - margin)
	global_position = Vector3(x, 0.0, z)


## Gait + idle life all in one place: leg swing, body bob and rifle sway.
func _update_gait(delta: float) -> void:
	var speed: float = Vector3(_velocity_smooth.x, 0.0, _velocity_smooth.z).length()
	var stride_rate: float = 9.0 * (speed / definition.move_speed)
	_walk_clock += delta * maxf(stride_rate, 0.0)
	var stride := sin(_walk_clock) * clampf(speed / definition.move_speed, 0.0, 1.0)
	_leg_left.rotation.x = stride * 0.55
	_leg_right.rotation.x = -stride * 0.55
	var hover: float = absf(sin(_walk_clock * 0.5)) * 0.03 if speed > 0.25 else sin(_walk_clock * 0.24) * 0.02
	_torso.position.y = _base_body_y + hover


## Recoil kicks the rifle up: energy without a full animation set.
func _play_recoil() -> void:
	if _rifle_barrel == null:
		return
	var tween := create_tween()
	_rifle_barrel.rotation.x = 0.0
	tween.tween_property(_rifle_barrel, "rotation:x", -0.35, 0.05)
	tween.tween_property(_rifle_barrel, "rotation:x", 0.0, 0.18)


# --- Code-built low-poly body (no model import) ---------------------------

func _build_body() -> void:
	# Soft grounding disc so the hero never floats visually.
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.5
	shadow_mesh.bottom_radius = 0.55
	shadow_mesh.height = 0.02
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.28)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.mesh = shadow_mesh
	shadow.material_override = shadow_material
	shadow.position = Vector3(0.0, 0.012, 0.0)
	add_child(shadow)

	_model_yaw = Node3D.new()
	_model_yaw.name = "Yaw"
	add_child(_model_yaw)
	# Model convention: front is +z (yaw = atan2(dir.x, dir.z) faces dir).
	_model_yaw.position = Vector3(0.0, 0.42, 0.0)

	_lean_pivot = Node3D.new()
	_lean_pivot.name = "Lean"
	_model_yaw.add_child(_lean_pivot)

	_torso = Node3D.new()
	_torso.name = "Torso"
	_base_body_y = 0.28
	_torso.position = Vector3(0.0, _base_body_y, 0.0)
	_lean_pivot.add_child(_torso)

	_add_part(_torso, Vector3(0.4, 0.72, 0.34), Vector3.ZERO, Color("#2d5f66"))  # jacket
	_add_part(_torso, Vector3(0.3, 0.26, 0.28), Vector3(0.0, 0.5, 0.02), Color("#e8c39a"))
	# visor: the one glowing landmark in the silhouette from any camera angle
	_add_part(_torso, Vector3(0.26, 0.07, 0.05), Vector3(0.0, 0.47, 0.14), Color(0.2, 0.95, 1.0), true)
	_add_part(_torso, Vector3(0.14, 0.3, 0.34), Vector3(0.24, 0.05, 0.02), Color("#24525a"))  # right arm
	_add_part(_torso, Vector3(0.14, 0.3, 0.34), Vector3(-0.24, 0.05, 0.02), Color("#24525a"))  # left arm
	# backpack keeps the back from reading flat
	_add_part(_torso, Vector3(0.3, 0.4, 0.16), Vector3(0.0, 0.05, -0.24), Color("#3a4d46"))

	_leg_left = _add_part(_model_yaw, Vector3(0.16, 0.44, 0.18), Vector3(0.14, -0.12, 0.12), Color("#33413c"))
	_leg_right = _add_part(_model_yaw, Vector3(0.16, 0.44, 0.18), Vector3(-0.14, -0.12, 0.12), Color("#33413c"))

	# Rifle rides the right arm, points +z with the body.
	_rifle_barrel = Node3D.new()
	_rifle_barrel.name = "Rifle"
	_rifle_barrel.position = Vector3(0.26, 0.16, 0.14)
	_torso.add_child(_rifle_barrel)
	_add_part(_rifle_barrel, Vector3(0.09, 0.12, 0.7), Vector3.ZERO, Color("#22303b"))
	_add_part(_rifle_barrel, Vector3(0.05, 0.05, 0.24), Vector3(0.0, 0.02, 0.42), Color(0.25, 0.9, 1.0), true)
	_add_part(_rifle_barrel, Vector3(0.06, 0.18, 0.14), Vector3(0.0, -0.02, -0.22), Color("#2c3a46"))


func _add_part(parent: Node3D, part_size: Vector3, part_position: Vector3,
		part_color: Color, emissive: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = part_size
	part.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = part_color
	if emissive:
		material.emission_enabled = true
		material.emission = part_color
		material.emission_energy_multiplier = 1.6
	part.material_override = material
	part.position = part_position
	parent.add_child(part)
	return part
