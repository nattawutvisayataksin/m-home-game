class_name TDTower
extends Node3D

## Tower: auto-acquires enemies inside range and fires projectiles; Tangle
## applies a slow aura. Targeting mode is per-tower and player-cycled (GDD §5
## post-vertical-slice): FIRST (default) / LAST / STRONGEST / WEAKEST.
## When a model_scene is provided via setup(), instantiates the low-poly .glb;
## otherwise falls back to greybox primitives.

signal fired(kind: Kind, from_position: Vector3)

enum Kind { FIELD_TURRET, SONIC_RESONATOR, TANGLE_EMITTER, ARC_CANNON }

## Per-tower target preference, cycled by the player with T (localized chip
## label above the turret nods the current mode; local keys TARGET_MODE_*).
enum TargetingMode { FIRST, LAST, STRONGEST, WEAKEST }

const MAX_LEVEL: int = 2

var kind: Kind = Kind.FIELD_TURRET
var damage: float = 0.0
var fire_interval: float = 1.0
var range_radius: float = 5.0
var splash_radius: float = 0.0
var slow_factor: float = 1.0
var level: int = 0
## Player-called targeting mode; FIRST keeps the pre-mode behavior exactly.
var targeting_mode: TargetingMode = TargetingMode.FIRST

var _mode_label: Label3D

var _cooldown: float = 0.0
var _projectile_parent: Node3D
var _model_scene: PackedScene  ## cached for potential level-visual swap later
var _model_node: Node3D  ## root of the instantiated .glb, null when greybox
var _aim_target: TDEnemy
var _recoil_tween: Tween
var _idle_time: float = 0.0
var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _barrel_nodes: Array[Node3D] = []
var _level_markers: Array[Node3D] = []


func setup(tower_kind: Kind, new_range: float, new_damage: float,
		new_interval: float, splash: float, slow: float,
		projectile_parent: Node3D, model_scene: PackedScene = null) -> void:
	kind = tower_kind
	range_radius = new_range
	damage = new_damage
	fire_interval = new_interval
	splash_radius = splash
	slow_factor = slow
	_projectile_parent = projectile_parent
	_model_scene = model_scene
	_build_body()


func can_upgrade() -> bool:
	return level < MAX_LEVEL


## Cycles the player-facing targeting mode; returns the new mode so the
## caller can refresh the chip label, show a toast and record metrics.
func cycle_targeting() -> TargetingMode:
	targeting_mode = TargetingMode.values()[(int(targeting_mode) + 1) % TargetingMode.size()]
	return targeting_mode


## Sets the localized mode chip above the turret. Hidden for FIRST so towers
## stay clean until the player actually uses the feature.
func set_mode_label_text(text: String) -> void:
	if _mode_label == null:
		_mode_label = Label3D.new()
		_mode_label.name = "TargetingMode"
		_mode_label.font_size = 26
		_mode_label.outline_size = 6
		_mode_label.position = Vector3(0.0, 2.0, 0.0)
		_mode_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mode_label.no_depth_test = true
		add_child(_mode_label)
	_mode_label.text = text
	_mode_label.visible = targeting_mode != TargetingMode.FIRST


## Applies a new level with recomputed stats. Caller owns cost math.
func apply_upgrade(new_damage: float, new_interval: float, new_range: float,
		new_slow: float, new_level: int, new_splash: float = -1.0) -> void:
	damage = new_damage
	fire_interval = new_interval
	range_radius = new_range
	slow_factor = new_slow
	if new_splash >= 0.0:
		splash_radius = new_splash
	level = new_level
	_refresh_visual_level()


func _refresh_visual_level() -> void:
	# Level cue: body scale plus floating chevrons that read from any angle
	# (the camera is fixed iso, so no billboard is needed).
	scale = Vector3.ONE * (1.0 + 0.12 * float(level))
	for marker: Node in _level_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_level_markers.clear()
	# L1: one amber chevron; L2: two ember chevrons (clearly distinct species)
	var trim_colors: Array[Color] = [Color("#e0a93f"), Color("#e0552a")]
	for chevron_index: int in range(level):
		_level_markers.append(_build_level_chevron(chevron_index, trim_colors[level - 1]))


## Small hovering cone marker above the turret; hue/position encode the level.
func _build_level_chevron(chevron_index: int, trim_color: Color) -> MeshInstance3D:
	var chevron := MeshInstance3D.new()
	chevron.name = "LevelChevron%d" % chevron_index
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.14
	cone.height = 0.34
	cone.radial_segments = 10
	chevron.mesh = cone
	var chevron_material := StandardMaterial3D.new()
	chevron_material.albedo_color = trim_color
	chevron_material.emission_enabled = true
	chevron_material.emission = trim_color
	chevron_material.emission_energy_multiplier = 0.55
	chevron.material_override = chevron_material
	var slots: int = level
	var slot_width: float = 0.3
	var x_offset: float = (float(chevron_index) - float(slots - 1) * 0.5) * slot_width
	chevron.position = Vector3(x_offset, 1.55, 0.0)
	add_child(chevron)
	return chevron


func _aim_at(target: TDEnemy, delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_position: Vector3 = target.global_position
	var flat_direction := target_position - global_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() < 0.001:
		return
	var desired_yaw: float = atan2(flat_direction.x, flat_direction.z)
	var desired_pitch: float = 0.0
	var vertical_delta: float = target_position.y - global_position.y
	var horizontal_distance: float = maxf(flat_direction.length(), 0.1)
	desired_pitch = -atan2(vertical_delta, horizontal_distance)
	if _yaw_pivot != null:
		_yaw_pivot.rotation.y = lerp_angle(_yaw_pivot.rotation.y, desired_yaw, minf(delta * 12.0, 1.0))
	else:
		rotation.y = lerp_angle(rotation.y, desired_yaw, minf(delta * 12.0, 1.0))
	if _pitch_pivot != null:
		_pitch_pivot.rotation.x = lerp_angle(_pitch_pivot.rotation.x, desired_pitch, minf(delta * 10.0, 1.0))


func _play_recoil() -> void:
	if _model_node == null or not is_instance_valid(_model_node):
		return
	if _barrel_nodes.is_empty():
		return
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	for barrel: Node3D in _barrel_nodes:
		barrel.position.z = 0.0
	_recoil_tween = create_tween()
	for barrel_index: int in range(_barrel_nodes.size()):
		var barrel: Node3D = _barrel_nodes[barrel_index]
		_recoil_tween.parallel().tween_property(barrel, "position:z", -0.12, 0.045)
		_recoil_tween.chain().tween_property(barrel, "position:z", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_body() -> void:
	if _model_scene != null:
		_model_node = _model_scene.instantiate()
		_model_node.name = "Model"
		add_child(_model_node)
		_cache_motion_parts()
		return

	# --- Greybox fallback ---
	var base := MeshInstance3D.new()
	var base_cylinder := CylinderMesh.new()
	base_cylinder.top_radius = 0.6
	base_cylinder.bottom_radius = 0.8
	base_cylinder.height = 0.5
	base.mesh = base_cylinder
	base.position = Vector3(0.0, 0.25, 0.0)
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.36, 0.4, 0.36)
	base.material_override = base_material
	add_child(base)

	if kind == Kind.TANGLE_EMITTER:
		# Tangle communicates its active radius through electric hit pulses.
		pass
	else:
		var barrel := MeshInstance3D.new()
		var barrel_box := BoxMesh.new()
		barrel_box.size = Vector3(0.3, 0.3, 1.2)
		barrel.mesh = barrel_box
		var barrel_material := StandardMaterial3D.new()
		if kind == Kind.SONIC_RESONATOR:
			barrel_material.albedo_color = Color(0.45, 0.5, 0.75)
		elif kind == Kind.ARC_CANNON:
			barrel_material.albedo_color = Color(0.55, 0.25, 0.9)
		else:
			barrel_material.albedo_color = Color(0.7, 0.5, 0.3)
		barrel.material_override = barrel_material
		barrel.position = Vector3(0.0, 0.65, 0.4)
		add_child(barrel)


func _cache_motion_parts() -> void:
	if _model_node == null:
		return
	_yaw_pivot = _model_node.get_node_or_null("YawPivot") as Node3D
	_pitch_pivot = _model_node.get_node_or_null("YawPivot/PitchPivot") as Node3D
	for barrel_name: StringName in [&"Barrel_L", &"Barrel_R"]:
		var barrel := _model_node.get_node_or_null("YawPivot/PitchPivot/" + String(barrel_name)) as Node3D
		if barrel != null:
			_barrel_nodes.append(barrel)


## Procedural aura ring for the Tangle Emitter; added on top of both model and
## greybox bodies so the range feedback is always visible.
func _add_aura_ring() -> void:
	var aura := MeshInstance3D.new()
	var aura_cylinder := CylinderMesh.new()
	aura_cylinder.top_radius = range_radius
	aura_cylinder.bottom_radius = range_radius
	aura_cylinder.height = 0.02
	var aura_material := StandardMaterial3D.new()
	aura_material.albedo_color = Color(0.35, 0.65, 0.8, 0.25)
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.mesh = aura_cylinder
	aura.material_override = aura_material
	aura.position = Vector3(0.0, 0.05, 0.0)
	add_child(aura)


func _physics_process(delta: float) -> void:
	_idle_time += delta
	if kind == Kind.TANGLE_EMITTER:
		if _model_node != null:
			_model_node.rotation.y = sin(_idle_time * 1.4) * 0.12
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target: TDEnemy = _acquire_target()
	if target != null:
		_aim_target = target
		_aim_at(target, delta)
	if _cooldown <= 0.0 and target != null:
		_cooldown = fire_interval
		_fire(target)


func _acquire_target() -> TDEnemy:
	var best: TDEnemy = null
	var best_score: float = -INF
	for node: Node in _projectile_parent.get_tree().get_nodes_in_group("td_enemies"):
		var enemy := node as TDEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			continue
		if enemy.global_position.distance_to(global_position) > range_radius:
			continue
		# FIRST keeps the legacy hook: highest path progress (furthest along).
		var score: float = enemy.progress
		match targeting_mode:
			TargetingMode.LAST:
				score = -enemy.progress
			TargetingMode.STRONGEST:
				score = enemy.health
			TargetingMode.WEAKEST:
				score = -enemy.health
		if best == null or score > best_score:
			best = enemy
			best_score = score
	return best


func _fire(target: TDEnemy) -> void:
	if _projectile_parent == null:
		return
	fired.emit(kind, global_position)
	_play_recoil()
	var projectile := TDProjectile.new()
	projectile.damage = damage
	projectile.splash_radius = splash_radius
	projectile.tower_kind = int(kind)
	projectile.configure_target(target)
	_projectile_parent.add_child(projectile)
	projectile.global_position = global_position + Vector3(0.0, 1.0, 0.0)
