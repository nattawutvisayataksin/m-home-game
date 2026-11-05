extends Node3D
class_name TDRun

## Greybox 3D tower-defense run: builds the scene in code, drives waves and
## economy, mediates placement. Balance numbers live in data/*.tres resources
## (enemy/tower/wave definitions); this script only wires them together.

signal run_ended(won: bool)

const HUD_SCRIPT: Script = preload("res://scripts/ui/td_hud.gd")
const METRICS_SCRIPT: Script = preload("res://scripts/systems/run_metrics.gd")
const PROFILE_SCRIPT: Script = preload("res://scripts/systems/profile_repository.gd")
const AUDIO_SCRIPT: Script = preload("res://scripts/systems/td_audio_director.gd")
const EFFECT_SCRIPT: Script = preload("res://scripts/actors/td_combat_effect.gd")
const TOWER_SLOT_PREVIEW_ENABLED: bool = false

const ENEMY_DEFS := {
	&"drifter": preload("res://data/enemies/drifter.tres"),
	&"skitter": preload("res://data/enemies/skitter.tres"),
	&"dasher": preload("res://data/enemies/dasher.tres"),
	&"warden": preload("res://data/enemies/warden.tres"),
}
const TOWER_DEFS := {
	TDTower.Kind.FIELD_TURRET: preload("res://data/towers/field_turret.tres"),
	TDTower.Kind.SONIC_RESONATOR: preload("res://data/towers/sonic_resonator.tres"),
	TDTower.Kind.TANGLE_EMITTER: preload("res://data/towers/tangle_emitter.tres"),
	TDTower.Kind.ARC_CANNON: preload("res://data/towers/arc_cannon.tres"),
}
const WAVES := [
	preload("res://data/waves/wave_01.tres"),
	preload("res://data/waves/wave_02.tres"),
	preload("res://data/waves/wave_03.tres"),
	preload("res://data/waves/wave_04.tres"),
	preload("res://data/waves/wave_05.tres"),
	preload("res://data/waves/wave_06.tres"),
	preload("res://data/waves/wave_07.tres"),
	preload("res://data/waves/wave_08.tres"),
]

# --- Greybox economy constants (session config, not unit balance) ---
const START_PARTS: int = 120
const START_INTEGRITY: int = 10
const WAVE_CLEAR_BONUS: int = 20
const INTEGRITY_BONUS: int = 5
const SELL_REFUND_RATIO: float = 0.7

const PATH_POINTS: PackedVector3Array = [
	Vector3(-14.0, 0.0, 12.0),
	Vector3(-14.0, 0.0, 0.0),
	Vector3(-12.0, 0.0, 0.0),
	Vector3(-9.0, 0.0, -2.0),
	Vector3(-6.0, 0.0, 0.0),
	Vector3(-4.0, 0.0, -4.0),
	Vector3(-4.0, 0.0, -8.0),
	Vector3(0.0, 0.0, -10.0),
	Vector3(5.0, 0.0, -8.0),
	Vector3(10.0, 0.0, -8.0),
]

const SLOTS: Array[Vector3] = [
	Vector3(-11.0, 0.0, 4.0),
	Vector3(-11.0, 0.0, -2.0),
	Vector3(-9.0, 0.0, 6.0),
	Vector3(-7.5, 0.0, -2.5),
	Vector3(-1.0, 0.0, -2.5),
	Vector3(-1.0, 0.0, 2.5),
	Vector3(-7.0, 0.0, -7.0),
	Vector3(-1.0, 0.0, -11.0),
	Vector3(2.0, 0.0, -4.5),
	Vector3(2.0, 0.0, -11.5),
	Vector3(7.0, 0.0, -4.5),
	Vector3(12.0, 0.0, -3.5),
]

# --- Run state ---
var parts: int = START_PARTS
var integrity: int = START_INTEGRITY
var wave_number: int = 0
var is_combat: bool = false
var is_over: bool = false

var _hud: TDHud
var _enemy_container: Node3D
var _projectile_container: Node3D
var _slot_towers: Array[TDTower] = []
var _slot_disks: Array[MeshInstance3D] = []
var _slot_occupied: Array[bool] = []
var _slot_invested: Array[int] = []
var _selected_kind: int = TDTower.Kind.FIELD_TURRET
var _hovered_slot: int = -1
var _last_clicked_slot: int = -1  # test seam; set by place/upgrade handlers
var _spawn_queue: Array[StringName] = []
var _spawn_cooldown: float = 0.0
var _spawn_spacing: float = 1.0
var _spawned_alive: int = 0
var _metrics: RunMetrics
var _profile_repo: ProfileRepository
var _audio: TDAudioDirector
var _effects: Node3D
var _camera_trauma: float = 0.0
var _trauma_clock: float = 0.0
var _preview_default: String = ""

var _camera: Camera3D
var _ghost: MeshInstance3D
var _placement_marker: MeshInstance3D
var _free_tower_positions: Array[Vector3] = []
var _free_towers: Array[TDTower] = []
var _free_tower_invested: Array[int] = []
var _spawn_beacon: Node3D
var _spawn_beacon_core: MeshInstance3D
var _spawn_beacon_ring: MeshInstance3D
var _world_time: float = 0.0
var _shelter_crystal: Node3D
var _tangle_effect_cooldowns: Dictionary = {}
var _resumed: bool = false


func _enemy_def(enemy_id: StringName) -> TDEnemyDefinition:
	return ENEMY_DEFS[enemy_id] as TDEnemyDefinition


func _tower_def(kind: int) -> TDTowerDefinition:
	return TOWER_DEFS[kind] as TDTowerDefinition


func _wave_def(wave_index: int) -> TDWaveDefinition:
	return WAVES[wave_index - 1] as TDWaveDefinition


func _ready() -> void:
	_metrics = METRICS_SCRIPT.new()
	_metrics.begin()
	_profile_repo = PROFILE_SCRIPT.new()
	var profile: Dictionary = _profile_repo.load_profile()
	var barricade_level: int = int(profile.get("barricade_level", 0))
	# Barricade bonus: +2 Integrity per level
	integrity = START_INTEGRITY + barricade_level * 2
	_build_world()
	_build_camera_and_light()
	_build_env()
	_build_hud()
	_build_audio()
	# Flash-save resume: the title menu sets resume_requested before entering.
	if TDSessionSnapshot.resume_requested:
		TDSessionSnapshot.resume_requested = false
		_restore_session(TDSessionSnapshot.load_state())
	# No clearing here: a stale snapshot survives until a real wave-clear (or a
	# run end) supersedes it, so an accidental fresh start keeps old progress.
	_preview_default = _composition_text(maxi(wave_number + 1, 1))
	_hud.show_wave_preview(_preview_default)
	_hud.update_status(parts, integrity, maxi(wave_number, 1), WAVES.size())
	_metrics.record(&"run_started", {"starting_integrity": integrity, "barricade_level": barricade_level})
	if _resumed:
		_metrics.record(&"run_resumed", {"wave": wave_number, "parts": parts, "integrity": integrity})


func _build_world() -> void:
	_enemy_container = Node3D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)
	_projectile_container = Node3D.new()
	_projectile_container.name = "Projectiles"
	add_child(_projectile_container)

	var ground := MeshInstance3D.new()
	var ground_plane := PlaneMesh.new()
	ground_plane.size = Vector2(64.0, 48.0)
	ground.mesh = ground_plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#3f463c")
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	ground.name = "Ground"
	add_child(ground)

	_paint_path_shelter_and_slots()


func _paint_path_shelter_and_slots() -> void:
	# path strips between consecutive waypoints
	for index: int in range(PATH_POINTS.size() - 1):
		var start_point: Vector3 = PATH_POINTS[index]
		var end_point: Vector3 = PATH_POINTS[index + 1]
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		var length: float = start_point.distance_to(end_point)
		box.size = Vector3(2.6, 0.08, length)
		strip.mesh = box
		var strip_material := StandardMaterial3D.new()
		strip_material.albedo_color = Color("#4b4a42")
		strip.material_override = strip_material
		strip.position = (start_point + end_point) * 0.5 + Vector3(0.0, 0.05, 0.0)
		var direction: Vector3 = (end_point - start_point).normalized()
		strip.look_at_from_position(strip.position, strip.position + direction, Vector3.UP)
		add_child(strip)
		_add_path_detail(start_point, end_point, index)

	_add_spawn_beacon(PATH_POINTS[0])

	# Low-poly roadside dressing keeps the lane readable while adding scale.
	var barricade_scene: PackedScene = load("res://assets/models/props/barricade.glb")
	var street_light_scene: PackedScene = load("res://assets/models/props/street_light.glb")
	var sign_scene: PackedScene = load("res://assets/models/props/shelter_09_sign.glb")
	var tree_scene: PackedScene = load("res://assets/models/props/ash_tree.glb")
	var house_scene: PackedScene = load("res://assets/models/props/ruined_house.glb")
	if barricade_scene != null:
		for position: Vector3 in [Vector3(-12.8, 0.0, 8.8), Vector3(-5.4, 0.0, -9.3), Vector3(9.2, 0.0, -6.8)]:
			var barricade := barricade_scene.instantiate()
			barricade.position = position
			barricade.rotation.y = position.x * 0.08
			add_child(barricade)
	if street_light_scene != null:
		for position: Vector3 in [Vector3(-15.0, 0.0, 8.0), Vector3(8.5, 0.0, -9.0)]:
			var street_light := street_light_scene.instantiate()
			street_light.position = position
			add_child(street_light)
	if tree_scene != null:
		for position: Vector3 in [Vector3(-18.0, 0.0, 11.0), Vector3(-10.0, 0.0, -12.5), Vector3(14.5, 0.0, 7.5), Vector3(16.0, 0.0, -11.5)]:
			var tree := tree_scene.instantiate()
			tree.position = position
			tree.rotation.y = position.x * 0.17
			tree.scale = Vector3.ONE * (0.85 + absf(position.z) * 0.012)
			add_child(tree)
	if house_scene != null:
		for position: Vector3 in [Vector3(16.0, 0.0, 11.0), Vector3(-17.0, 0.0, -7.5)]:
			var house := house_scene.instantiate()
			house.position = position
			house.rotation.y = -0.35 if position.x > 0.0 else 0.55
			house.scale = Vector3.ONE * 0.9
			add_child(house)

	# the Shelter 09 blockhouse at path end
	var shelter_scene: PackedScene = load("res://assets/models/props/shelter.glb")
	var shelter: Node3D
	if shelter_scene != null:
		shelter = shelter_scene.instantiate()
		shelter.name = "Shelter"
		shelter.position = PATH_POINTS[PATH_POINTS.size() - 1] + Vector3(2.4, 0.0, 0.0)
	else:
		var shelter_mesh := MeshInstance3D.new()
		var shelter_box := BoxMesh.new()
		shelter_box.size = Vector3(3.0, 2.2, 2.2)
		shelter_mesh.mesh = shelter_box
		var shelter_material := StandardMaterial3D.new()
		shelter_material.albedo_color = Color("#6e5c40")
		shelter_mesh.material_override = shelter_material
		shelter_mesh.position = PATH_POINTS[PATH_POINTS.size() - 1] + Vector3(2.4, 1.1, 0.0)
		shelter_mesh.name = "Shelter"
		shelter = shelter_mesh
	add_child(shelter)
	if sign_scene != null:
		var sign := sign_scene.instantiate()
		sign.position = PATH_POINTS[PATH_POINTS.size() - 1] + Vector3(0.0, 0.0, -2.0)
		sign.rotation.y = PI
		add_child(sign)
	_add_shelter_crystal(PATH_POINTS[PATH_POINTS.size() - 1] + Vector3(2.4, 0.0, 0.0))

	for slot_index: int in range(SLOTS.size()):
		var disk := MeshInstance3D.new()
		var disk_cylinder := CylinderMesh.new()
		disk_cylinder.top_radius = 0.7
		disk_cylinder.bottom_radius = 0.7
		disk_cylinder.height = 0.06
		disk.mesh = disk_cylinder
		var disk_material := StandardMaterial3D.new()
		disk_material.albedo_color = Color(0.75, 0.66, 0.4, 0.5)
		disk_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disk.material_override = disk_material
		disk.position = SLOTS[slot_index] + Vector3(0.0, 0.09, 0.0)
		add_child(disk)
		_slot_disks.append(disk)
		_slot_occupied.append(false)
		_slot_invested.append(0)
		_slot_towers.append(null)
		disk.visible = TOWER_SLOT_PREVIEW_ENABLED


func _add_shelter_crystal(position: Vector3) -> void:
	_shelter_crystal = Node3D.new()
	_shelter_crystal.name = "ShelterCoreCrystal"
	_shelter_crystal.position = position + Vector3(0.0, 1.3, 0.0)
	add_child(_shelter_crystal)
	var crystal := MeshInstance3D.new()
	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(1.0, 2.3, 1.0)
	crystal.mesh = crystal_mesh
	var crystal_material := StandardMaterial3D.new()
	crystal_material.albedo_color = Color(0.22, 0.65, 0.95, 0.92)
	crystal_material.emission_enabled = true
	crystal_material.emission = Color(0.08, 0.5, 1.0)
	crystal_material.emission_energy_multiplier = 3.0
	crystal.material_override = crystal_material
	crystal.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	_shelter_crystal.add_child(crystal)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.9
	base_mesh.bottom_radius = 1.1
	base_mesh.height = 0.18
	base.mesh = base_mesh
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.12, 0.16, 0.2)
	base_material.metallic = 0.7
	base.material_override = base_material
	base.position.y = -1.15
	_shelter_crystal.add_child(base)
	var light := OmniLight3D.new()
	light.light_color = Color(0.12, 0.55, 1.0)
	light.light_energy = 2.2
	light.omni_range = 7.0
	_shelter_crystal.add_child(light)


func _add_path_detail(start_point: Vector3, end_point: Vector3, segment_index: int) -> void:
	var direction: Vector3 = (end_point - start_point).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x)
	var midpoint: Vector3 = (start_point + end_point) * 0.5
	var segment_length: float = start_point.distance_to(end_point)
	var shoulder_material := StandardMaterial3D.new()
	shoulder_material.albedo_color = Color("#252b27")
	shoulder_material.roughness = 1.0
	for side_sign: float in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := BoxMesh.new()
		shoulder_mesh.size = Vector3(0.38, 0.035, segment_length)
		shoulder.mesh = shoulder_mesh
		shoulder.material_override = shoulder_material
		shoulder.position = midpoint + side * side_sign * 1.52 + Vector3(0.0, 0.11, 0.0)
		shoulder.look_at_from_position(shoulder.position, shoulder.position + direction, Vector3.UP)
		add_child(shoulder)
	for mark_index: int in range(ceili(segment_length / 3.0)):
		var mark := MeshInstance3D.new()
		var mark_mesh := BoxMesh.new()
		mark_mesh.size = Vector3(0.09, 0.018, 1.0)
		mark.mesh = mark_mesh
		var mark_position: Vector3 = start_point + direction * (float(mark_index) * 3.0 + 1.5) + Vector3(0.0, 0.105, 0.0)
		mark.position = mark_position
		mark.look_at_from_position(mark_position, mark_position + direction, Vector3.UP)
		var mark_material := StandardMaterial3D.new()
		mark_material.albedo_color = Color("#a99873")
		mark.material_override = mark_material
		add_child(mark)


func _add_spawn_beacon(position: Vector3) -> void:
	_spawn_beacon = Node3D.new()
	_spawn_beacon.name = "HollowSpawnBeacon"
	_spawn_beacon.position = position
	add_child(_spawn_beacon)
	_spawn_beacon_core = MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.18
	core_mesh.bottom_radius = 0.42
	core_mesh.height = 0.7
	_spawn_beacon_core.mesh = core_mesh
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(0.34, 0.16, 0.48, 0.72)
	core_material.emission_enabled = true
	core_material.emission = Color(0.42, 0.12, 0.72)
	core_material.emission_energy_multiplier = 2.5
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spawn_beacon_core.material_override = core_material
	_spawn_beacon_core.position.y = 0.36
	_spawn_beacon.add_child(_spawn_beacon_core)
	_spawn_beacon_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.68
	_spawn_beacon_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.48, 0.2, 0.72, 0.65)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.42, 0.12, 0.7)
	ring_material.emission_energy_multiplier = 1.5
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spawn_beacon_ring.material_override = ring_material
	_spawn_beacon_ring.position.y = 0.08
	_spawn_beacon.add_child(_spawn_beacon_ring)
	var beacon_light := OmniLight3D.new()
	beacon_light.light_color = Color(0.48, 0.2, 0.72)
	beacon_light.light_energy = 1.1
	beacon_light.omni_range = 5.0
	beacon_light.position.y = 0.5
	_spawn_beacon.add_child(beacon_light)


func _build_camera_and_light() -> void:
	_camera = Camera3D.new()
	_camera.fov = 42.0
	add_child(_camera)
	_camera.look_at_from_position(Vector3(4.0, 17.0, 15.0), Vector3(0.0, 0.0, -2.0), Vector3.UP)
	_camera.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#ffd8b0")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(1.0, 7.0, 1.0)
	fill.light_color = Color("#9db7d1")
	fill.light_energy = 0.45
	fill.omni_range = 35.0
	add_child(fill)


func _build_env() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.2, 0.26)
	sky_material.sky_horizon_color = Color(0.62, 0.5, 0.4)
	sky_material.ground_bottom_color = Color(0.1, 0.11, 0.1)
	sky_material.ground_horizon_color = Color(0.5, 0.42, 0.34)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color("#4d4c55")
	env.fog_light_energy = 0.35
	env.fog_density = 0.008
	world_environment.environment = env
	add_child(world_environment)

	# ghost preview ring shown on hovered slot for the selected tower type
	_ghost = MeshInstance3D.new()
	var selected_stats: TDTowerDefinition = _tower_def(_selected_kind)
	var ghost_cylinder := CylinderMesh.new()
	ghost_cylinder.top_radius = selected_stats.range_radius
	ghost_cylinder.bottom_radius = selected_stats.range_radius
	ghost_cylinder.height = 0.04
	var ghost_material := StandardMaterial3D.new()
	ghost_material.albedo_color = Color(0.8, 0.8, 0.55, 0.25)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.mesh = ghost_cylinder
	_ghost.material_override = ghost_material
	_ghost.visible = false
	add_child(_ghost)
	_placement_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.72
	marker_mesh.bottom_radius = 0.72
	marker_mesh.height = 0.035
	_placement_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.4, 0.85, 0.5, 0.65)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_placement_marker.material_override = marker_material
	_placement_marker.visible = false
	add_child(_placement_marker)


func _composition_text(wave_index: int) -> String:
	if wave_index < 1 or wave_index > WAVES.size():
		return "-"
	var wave: TDWaveDefinition = _wave_def(wave_index)
	var labels: Array[String] = []
	for enemy_id: StringName in wave.composition.keys():
		labels.append("%s x%d" % [String(enemy_id).capitalize(), wave.composition[enemy_id]])
	return ", ".join(labels)


func _build_audio() -> void:
	# The run owns audio: towers/enemies never play sounds directly; their
	# state changes surface here as signals and this node plays the SFX.
	_audio = AUDIO_SCRIPT.new()
	_audio.name = "AudioDirector"
	add_child(_audio)
	# Same ownership for the transient VFX nodes.
	_effects = Node3D.new()
	_effects.name = "Effects"
	add_child(_effects)
	# Route projectile impacts into the run so visual feedback stays event-driven.
	_projectile_container.child_entered_tree.connect(_on_projectile_entered)


func _spawn_effect(kind: int, position: Vector3) -> void:
	var effect: TDCombatEffect = EFFECT_SCRIPT.new() as TDCombatEffect
	effect.effect_kind = kind
	_effects.add_child(effect)
	effect.global_position = position


func _add_camera_trauma(amount: float) -> void:
	var store := get_node_or_null("/root/TDSettings") as TDSettingsStore
	if store != null and store.get_reduce_motion():
		return  # reduce_motion opts out of camera shake entirely
	_camera_trauma = clampf(_camera_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	# Decaying trauma shake on the camera OFFSETS only (never the game state).
	if _camera_trauma <= 0.0:
		return
	_camera_trauma = maxf(_camera_trauma - 1.2 * delta, 0.0)
	if _camera_trauma <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	_trauma_clock += delta * 30.0
	var shake: float = _camera_trauma * _camera_trauma
	_camera.h_offset = 0.5 * shake * sin(_trauma_clock * 1.7)
	_camera.v_offset = 0.5 * shake * sin(_trauma_clock * 2.3)


func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.set_script(HUD_SCRIPT)
	_hud = hud_layer as TDHud
	if _hud == null:
		push_error("HUD script failed to load.")
		return
	add_child(hud_layer)
	_hud.build_ui()
	_hud.tower_selected.connect(_on_tower_selected)
	_hud.start_wave_pressed.connect(start_wave)
	_hud.restart_pressed.connect(_restart)
	_hud.resume_pressed.connect(toggle_pause)
	_hud.title_pressed.connect(_go_to_title)


func _on_tower_selected(kind: int) -> void:
	_select_kind(kind)


# --- Input & placement -------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_over:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var placement_position: Vector3 = _ground_position_from_mouse(mouse_event.position)
		var slot: int = _slot_from_mouse(mouse_event.position)
		var free_tower_index: int = _free_tower_from_position(placement_position)
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if slot >= 0 and _slot_occupied[slot]:
				upgrade_tower(slot)
			elif free_tower_index >= 0:
				upgrade_free_tower(free_tower_index)
			elif placement_position != Vector3.INF:
				place_tower_at(placement_position, _selected_kind)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if slot >= 0 and _slot_occupied[slot]:
				sell_tower(slot)
			elif free_tower_index >= 0:
				sell_free_tower(free_tower_index)
	# KEY_ESCAPE is handled by the HUD (PROCESS_MODE_ALWAYS): it must work
	# while the tree is paused (close settings, resume) and toggles pause
	# otherwise; run nodes are pausable and would miss those events.
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.physical_keycode:
			KEY_1:
				_select_kind(TDTower.Kind.FIELD_TURRET)
			KEY_2:
				_select_kind(TDTower.Kind.SONIC_RESONATOR)
			KEY_3:
				_select_kind(TDTower.Kind.TANGLE_EMITTER)
			KEY_4:
				_select_kind(TDTower.Kind.ARC_CANNON)
			KEY_SPACE:
				start_wave()


func _select_kind(kind: int) -> void:
	_selected_kind = kind
	var stats: TDTowerDefinition = _tower_def(kind)
	var ghost_cylinder := _ghost.mesh as CylinderMesh
	ghost_cylinder.top_radius = stats.range_radius
	ghost_cylinder.bottom_radius = stats.range_radius


func _slot_from_mouse(screen_position: Vector2) -> int:
	var ground_hit := _ground_position_from_mouse(screen_position)
	if ground_hit == Vector3.INF:
		return -1
	var best_slot: int = -1
	var best_distance: float = 1.4
	for slot_index: int in range(SLOTS.size()):
		var distance: float = Vector2(ground_hit.x, ground_hit.z).distance_to(Vector2(SLOTS[slot_index].x, SLOTS[slot_index].z))
		if distance < best_distance:
			best_distance = distance
			best_slot = slot_index
	return best_slot


func _ground_position_from_mouse(screen_position: Vector2) -> Vector3:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return Vector3.INF
	var distance_to_ground: float = (ray_origin.y) / -ray_direction.y
	if distance_to_ground < 0.0:
		return Vector3.INF
	return ray_origin + ray_direction * distance_to_ground


func _free_tower_from_position(world_position: Vector3) -> int:
	if world_position == Vector3.INF:
		return -1
	for index: int in range(_free_towers.size()):
		var tower: TDTower = _free_towers[index]
		if tower != null and is_instance_valid(tower) and tower.global_position.distance_to(world_position) < 1.1:
			return index
	return -1


func place_tower(slot_index: int, kind: int) -> bool:
	if is_over or slot_index < 0 or slot_index >= SLOTS.size() or _slot_occupied[slot_index]:
		return false
	var stats: TDTowerDefinition = _tower_def(kind)
	if parts < stats.cost:
		return false
	parts -= stats.cost
	var tower := TDTower.new()
	tower.setup(
		stats.tower_kind,
		stats.range_radius,
		stats.damage,
		stats.fire_interval,
		stats.splash_radius,
		stats.slow_factor,
		_projectile_container,
		stats.model_scene
	)
	add_child(tower)
	tower.global_position = SLOTS[slot_index]
	tower.fired.connect(_on_tower_fired)
	_slot_towers[slot_index] = tower
	_slot_occupied[slot_index] = true
	_slot_invested[slot_index] = stats.cost
	_spawn_effect(TDCombatEffect.KIND_PLACED, SLOTS[slot_index])
	_audio.play_sfx("build")
	var disk := _slot_disks[slot_index] as MeshInstance3D
	var disk_material := disk.material_override as StandardMaterial3D
	disk_material.albedo_color = Color(0.35, 0.8, 0.4, 0.5)
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_metrics.record(&"tower_placed", {"kind": kind, "slot": slot_index, "parts_after": parts})
	_last_clicked_slot = slot_index
	_hovered_slot = -1
	return true


func place_tower_at(world_position: Vector3, kind: int) -> bool:
	if is_over or not _can_place_free_position(world_position):
		return false
	var stats: TDTowerDefinition = _tower_def(kind)
	if parts < stats.cost:
		return false
	parts -= stats.cost
	var tower := TDTower.new()
	tower.setup(stats.tower_kind, stats.range_radius, stats.damage, stats.fire_interval,
		stats.splash_radius, stats.slow_factor, _projectile_container, stats.model_scene)
	add_child(tower)
	tower.global_position = world_position
	tower.fired.connect(_on_tower_fired)
	_free_tower_positions.append(world_position)
	_free_towers.append(tower)
	_free_tower_invested.append(stats.cost)
	_spawn_effect(TDCombatEffect.KIND_PLACED, world_position)
	_audio.play_sfx("build")
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_metrics.record(&"tower_placed", {"kind": kind, "free_position": world_position, "parts_after": parts})
	return true


func upgrade_free_tower(index: int) -> bool:
	if is_over or index < 0 or index >= _free_towers.size():
		return false
	var tower: TDTower = _free_towers[index]
	if tower == null or not is_instance_valid(tower) or not tower.can_upgrade():
		return false
	var stats: TDTowerDefinition = _tower_def(tower.kind)
	var cost: int = stats.upgrade_costs[tower.level]
	if parts < cost:
		return false
	parts -= cost
	_free_tower_invested[index] += cost
	var next_level: int = tower.level + 1
	tower.apply_upgrade(stats.damage * pow(stats.upgrade_damage_factor, next_level),
		stats.fire_interval * pow(stats.upgrade_rate_factor, next_level),
		stats.range_radius + stats.upgrade_range_bonus * float(next_level),
		stats.slow_factor * pow(stats.upgrade_slow_factor, next_level), next_level)
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_spawn_effect(TDCombatEffect.KIND_UPGRADE, tower.global_position)
	_audio.play_sfx("upgrade")
	return true


func sell_free_tower(index: int) -> bool:
	if is_over or index < 0 or index >= _free_towers.size():
		return false
	var tower: TDTower = _free_towers[index]
	if tower == null or not is_instance_valid(tower):
		return false
	var position: Vector3 = tower.global_position
	parts += int(float(_free_tower_invested[index]) * SELL_REFUND_RATIO)
	tower.queue_free()
	_free_towers.remove_at(index)
	_free_tower_positions.remove_at(index)
	_free_tower_invested.remove_at(index)
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_spawn_effect(TDCombatEffect.KIND_SOLD, position)
	_audio.play_sfx("sell")
	return true


func _can_place_free_position(world_position: Vector3) -> bool:
	if world_position.x < -19.0 or world_position.x > 19.0 or world_position.z < -15.0 or world_position.z > 15.0:
		return false
	for existing_position: Vector3 in _free_tower_positions:
		if existing_position.distance_to(world_position) < 1.8:
			return false
	return true


func upgrade_tower(slot_index: int) -> bool:
	if is_over or slot_index < 0 or slot_index >= SLOTS.size():
		return false
	var tower: TDTower = _slot_towers[slot_index]
	if tower == null or not tower.can_upgrade():
		return false
	var stats: TDTowerDefinition = _tower_def(tower.kind)
	var cost: int = stats.upgrade_costs[tower.level]
	if parts < cost:
		return false
	parts -= cost
	_slot_invested[slot_index] += cost
	var next_level: int = tower.level + 1
	tower.apply_upgrade(
		stats.damage * pow(stats.upgrade_damage_factor, next_level),
		stats.fire_interval * pow(stats.upgrade_rate_factor, next_level),
		stats.range_radius + stats.upgrade_range_bonus * float(next_level),
		stats.slow_factor * pow(stats.upgrade_slow_factor, next_level),
		next_level
	)
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_metrics.record(&"tower_upgraded", {"kind": tower.kind, "level": tower.level, "cost": cost, "parts_after": parts})
	_spawn_effect(TDCombatEffect.KIND_UPGRADE, tower.global_position)
	_audio.play_sfx("upgrade")
	_last_clicked_slot = slot_index
	return true


func sell_tower(slot_index: int) -> bool:
	if is_over or slot_index < 0 or slot_index >= SLOTS.size():
		return false
	var tower: TDTower = _slot_towers[slot_index]
	if tower == null:
		return false
	var refund: int = int(float(_slot_invested[slot_index]) * SELL_REFUND_RATIO)
	parts += refund
	tower.queue_free()
	_slot_towers[slot_index] = null
	_slot_occupied[slot_index] = false
	_slot_invested[slot_index] = 0
	var disk := _slot_disks[slot_index] as MeshInstance3D
	var disk_material := disk.material_override as StandardMaterial3D
	disk_material.albedo_color = Color(0.75, 0.66, 0.4, 0.5)
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_metrics.record(&"tower_sold", {"slot": slot_index, "refund": refund, "parts_after": parts})
	_spawn_effect(TDCombatEffect.KIND_SOLD, SLOTS[slot_index])
	_audio.play_sfx("sell")
	_last_clicked_slot = slot_index
	return true


func _physics_process(delta: float) -> void:
	if is_over:
		return
	_world_time += delta
	if _spawn_beacon != null:
		_spawn_beacon.rotation.y += delta * 0.8
		_spawn_beacon.scale = Vector3.ONE * (1.0 + sin(_world_time * 2.2) * 0.06)
	if _spawn_beacon_core != null:
		_spawn_beacon_core.position.y = 0.36 + sin(_world_time * 2.8) * 0.08
	if _spawn_beacon_ring != null:
		_spawn_beacon_ring.rotation.x = sin(_world_time * 1.7) * 0.18
	if _shelter_crystal != null:
		_shelter_crystal.rotation.y += delta * 0.35
		_shelter_crystal.scale = Vector3.ONE * (1.0 + sin(_world_time * 1.8) * 0.035)
	_update_slows()
	_update_hover()
	if is_combat:
		_spawn_tick(delta)
	_hud.update_status(parts, integrity, maxi(wave_number, 1), WAVES.size())
	# Same event source the HUD uses for spawn count (GDD: spawn quantity).
	_hud.set_enemies_left(_spawned_alive + _spawn_queue.size())


func _update_slows() -> void:
	var active_towers: Array[TDTower] = []
	for slot_tower: TDTower in _slot_towers:
		if slot_tower != null:
			active_towers.append(slot_tower)
	for free_tower: TDTower in _free_towers:
		if free_tower != null:
			active_towers.append(free_tower)
	for tower: TDTower in active_towers:
		if tower == null or not is_instance_valid(tower) or tower.kind != TDTower.Kind.TANGLE_EMITTER:
			continue
		for node: Node in get_tree().get_nodes_in_group("td_enemies"):
			var enemy := node as TDEnemy
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.alive and enemy.global_position.distance_to(tower.global_position) <= tower.range_radius:
				enemy.slow_factor = minf(enemy.slow_factor, tower.slow_factor)
				var cooldown_key: String = "%s:%s" % [tower.get_instance_id(), enemy.get_instance_id()]
				var cooldown: float = float(_tangle_effect_cooldowns.get(cooldown_key, 0.0))
				if cooldown <= 0.0:
					_spawn_effect(TDCombatEffect.KIND_ELECTRIC, enemy.global_position + Vector3(0.0, 0.55, 0.0))
					_tangle_effect_cooldowns[cooldown_key] = 0.22
	for cooldown_key: Variant in _tangle_effect_cooldowns.keys():
		_tangle_effect_cooldowns[cooldown_key] = maxf(float(_tangle_effect_cooldowns[cooldown_key]) - get_physics_process_delta_time(), 0.0)


func _update_hover() -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var slot: int = _slot_from_mouse(mouse_position)
	if slot != _hovered_slot:
		_hovered_slot = slot
		if slot >= 0:
			if _slot_occupied[slot]:
				_hud.show_wave_preview("Occupied: LMB upgrade, RMB sell")
			else:
				_hud.show_wave_preview(_preview_default)
		else:
			var default_text: String = _composition_text(wave_number + 1) if not is_combat else _composition_text(wave_number)
			_preview_default = default_text if not is_combat else _preview_default
			_hud.show_wave_preview(default_text)
	var ground_position := _ground_position_from_mouse(mouse_position)
	var has_selection: bool = ground_position != Vector3.INF and slot < 0
	_ghost.visible = has_selection
	_placement_marker.visible = has_selection
	var ghost_material := _ghost.material_override as StandardMaterial3D
	var selected_stats: TDTowerDefinition = _tower_def(_selected_kind)
	if _ghost.visible:
		_ghost.global_position = ground_position + Vector3(0.0, 0.1, 0.0)
		_placement_marker.global_position = ground_position + Vector3(0.0, 0.03, 0.0)
	var afford: bool = parts >= selected_stats.cost
	var can_place: bool = _can_place_free_position(ground_position) if has_selection else true
	if (not afford or not can_place) and has_selection:
		ghost_material.albedo_color = Color(0.8, 0.3, 0.3, 0.25)
	else:
		ghost_material.albedo_color = Color(0.8, 0.8, 0.55, 0.25)


# --- Waves -------------------------------------------------------------

func start_wave() -> void:
	if is_combat or is_over or wave_number >= WAVES.size():
		return
	wave_number += 1
	is_combat = true
	var wave: TDWaveDefinition = _wave_def(wave_number)
	_spawn_spacing = wave.spawn_interval
	_spawn_queue.clear()
	for enemy_id: StringName in wave.composition.keys():
		var count: int = int(wave.composition[enemy_id])
		for _index: int in range(count):
			_spawn_queue.append(enemy_id)
	_hud.set_combat_state(true)
	_spawn_effect(TDCombatEffect.KIND_WAVE, PATH_POINTS[0])
	_audio.play_sfx("wave_horn")
	_metrics.record(&"wave_started", {"wave": wave_number})


func _spawn_tick(delta: float) -> void:
	if _spawn_queue.is_empty():
		if _spawned_alive <= 0:
			_clear_wave()
		return
	_spawn_cooldown = maxf(_spawn_cooldown - delta, 0.0)
	if _spawn_cooldown > 0.0:
		return
	_spawn_cooldown = _spawn_spacing
	var enemy_id: StringName = _spawn_queue.pop_front()
	var stats: TDEnemyDefinition = _enemy_def(enemy_id)
	var wave: TDWaveDefinition = _wave_def(wave_number)
	var enemy := TDEnemy.new()
	enemy.setup(
		PATH_POINTS,
		stats.archetype,
		stats.base_health * (1.0 + wave.health_bonus),
		stats.speed,
		stats.bounty,
		stats.integrity_damage,
		stats.model_scene,
		stats.dash_walk_time,
		stats.dash_telegraph_time,
		stats.dash_time,
		stats.dash_speed_multiplier
	)
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	_enemy_container.add_child(enemy)
	enemy.global_position = PATH_POINTS[0]
	_spawned_alive += 1
	if stats.archetype == TDEnemy.Archetype.WARDEN:
		_announce_boss()


func _clear_wave() -> void:
	is_combat = false
	parts += WAVE_CLEAR_BONUS + INTEGRITY_BONUS * integrity
	_metrics.record(&"wave_cleared", {"wave": wave_number, "integrity": integrity, "parts_after": parts})
	# Flash save: the prep boundary is the only coherent checkpoint.
	save_session_snapshot()
	if wave_number >= WAVES.size():
		_end_run(true)
		return
	_hud.set_combat_state(false)
	_preview_default = _composition_text(wave_number + 1)
	_hud.show_wave_preview(_preview_default)


func _on_enemy_died(enemy: TDEnemy) -> void:
	parts += enemy.parts_bounty
	_spawned_alive = maxi(_spawned_alive - 1, 0)
	_spawn_effect(TDCombatEffect.KIND_DEATH, enemy.global_position)
	_audio.play_sfx("hit", 0.06)
	_metrics.record(&"enemy_killed", {"bounty": enemy.parts_bounty, "wave": wave_number})
	enemy.queue_free()


func _on_enemy_leaked(enemy: TDEnemy) -> void:
	_spawned_alive = maxi(_spawned_alive - 1, 0)
	if is_over:
		enemy.queue_free()
		return
	_audio.play_sfx("leak", 0.05)
	_spawn_effect(TDCombatEffect.KIND_LEAK, PATH_POINTS[PATH_POINTS.size() - 1])
	_add_camera_trauma(0.35)
	if _hud != null:
		_hud.flash_leak()
	integrity = maxi(integrity - enemy.integrity_damage, 0)
	_metrics.record(&"enemy_leaked", {"damage": enemy.integrity_damage, "integrity_after": integrity, "wave": wave_number})
	if integrity <= 0:
		_end_run(false)
	enemy.queue_free()


func _on_projectile_entered(node: Node) -> void:
	var projectile := node as TDProjectile
	if projectile == null:
		return
	projectile.impacted.connect(_on_projectile_impacted)


func _on_projectile_impacted(impact_position: Vector3, splash: bool) -> void:
	_spawn_effect(
		TDCombatEffect.KIND_HIT if not splash else TDCombatEffect.KIND_DEATH,
		impact_position
	)


func _on_tower_fired(kind: int, from_position: Vector3) -> void:
	match kind:
		TDTower.Kind.ARC_CANNON:
			_audio.play_sfx("arc_burst")
			_spawn_effect(TDCombatEffect.KIND_UPGRADE, from_position)
		TDTower.Kind.SONIC_RESONATOR:
			_audio.play_sfx("resonator_pulse")
		TDTower.Kind.TANGLE_EMITTER:
			_audio.play_sfx("tangle_cast")
		_:
			_audio.play_sfx("turret_shot", 0.08)
	_spawn_effect(TDCombatEffect.KIND_MUZZLE, from_position)


func _end_run(won: bool) -> void:
	if is_over:
		return
	is_over = true
	is_combat = false
	TDSessionSnapshot.clear()  # a finished run has nothing to resume
	_hud.set_combat_state(false)
	_metrics.record(&"run_ended", {"won": won, "wave": wave_number, "integrity_remaining": integrity})
	_metrics.finalize_run({
		"won": won,
		"wave": wave_number,
		"integrity_remaining": integrity,
		"parts": parts,
		"towers": _slot_occupied.filter(func(occupied: bool) -> bool: return occupied).size(),
	})
	_metrics.save_file()
	if _profile_repo != null:
		var profile: Dictionary = _profile_repo.load_profile()
		profile["total_runs"] = int(profile.get("total_runs", 0)) + 1
		if won:
			profile["victories"] = int(profile.get("victories", 0)) + 1
		profile["best_wave"] = maxi(int(profile.get("best_wave", 1)), wave_number)
		profile["best_integrity"] = maxi(int(profile.get("best_integrity", 0)), integrity)
		var salvage_gain: int = (wave_number * 10) + (integrity * 2) if not won else (150 + integrity * 5)
		profile["salvage"] = int(profile.get("salvage", 0)) + salvage_gain
		profile["lifetime_salvage"] = int(profile.get("lifetime_salvage", 0)) + salvage_gain
		_profile_repo.save_profile(profile)
	_hud.show_result(won, parts)
	_audio.play_sfx("breach" if not won else "upgrade")
	_add_camera_trauma(0.7 if not won else 0.3)
	run_ended.emit(won)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func toggle_pause() -> void:
	if is_over:
		return
	var should_pause: bool = not get_tree().paused
	get_tree().paused = should_pause
	_hud.set_pause_menu(should_pause)


func _go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


# --- Flash save / session resume -----------------------------------------

## Window close flash save: only runs with actual progress write a snapshot
## (design: a truly fresh run never clobbers an older snapshot on close).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not is_over and _has_run_progress():
		save_session_snapshot()


## Something worth flash-saving: towers placed, a wave in flight, or a resumed
## run. A bare prep-phase fresh start has nothing to preserve.
func _has_run_progress() -> bool:
	if _resumed:
		return true
	for slot_tower: TDTower in _slot_towers:
		if slot_tower != null:
			return true
	return _free_towers.size() > 0


## Number of fully cleared waves: mid-combat close rewinds to replay the wave.
func _cleared_waves_for_snapshot() -> int:
	return wave_number - 1 if is_combat else wave_number


func save_session_snapshot() -> bool:
	if is_over:
		return false
	var towers: Array = []
	for slot_index: int in range(SLOTS.size()):
		var slot_tower: TDTower = _slot_towers[slot_index]
		if not _slot_occupied[slot_index] or slot_tower == null:
			continue
		towers.append({
			"place": "slot",
			"slot": slot_index,
			"kind": slot_tower.kind,
			"level": slot_tower.level,
			"invested": _slot_invested[slot_index],
		})
	for index: int in range(_free_towers.size()):
		var free_tower: TDTower = _free_towers[index]
		if free_tower == null or not is_instance_valid(free_tower):
			continue
		towers.append({
			"place": "free",
			"position": [free_tower.global_position.x, free_tower.global_position.y, free_tower.global_position.z],
			"kind": free_tower.kind,
			"level": free_tower.level,
			"invested": _free_tower_invested[index],
		})
	return TDSessionSnapshot.save_state({
		"wave": clampi(_cleared_waves_for_snapshot(), 0, WAVES.size()),
		"parts": parts,
		"integrity": integrity,
		"towers": towers,
	})


func _restore_session(state: Dictionary) -> void:
	if state.is_empty():
		return
	parts = maxi(int(state.get("parts", START_PARTS)), 0)
	integrity = clampi(int(state.get("integrity", START_INTEGRITY)), 0, 99)
	wave_number = clampi(int(state.get("wave", 0)), 0, WAVES.size() - 1)
	var tower_data_list: Array = state.get("towers", [])
	for tower_data: Variant in tower_data_list:
		if typeof(tower_data) == TYPE_DICTIONARY:
			_restore_tower(tower_data as Dictionary)
	_resumed = true


func _restore_tower(tower_data: Dictionary) -> void:
	var kind: int = int(tower_data.get("kind", TDTower.Kind.FIELD_TURRET))
	if not TOWER_DEFS.has(kind):
		return
	var stats: TDTowerDefinition = TOWER_DEFS[kind] as TDTowerDefinition
	var level: int = clampi(int(tower_data.get("level", 0)), 0, TDTower.MAX_LEVEL)
	var invested: int = maxi(int(tower_data.get("invested", 0)), 0)
	var tower := TDTower.new()
	tower.setup(stats.tower_kind, stats.range_radius, stats.damage, stats.fire_interval,
		stats.splash_radius, stats.slow_factor, _projectile_container, stats.model_scene)
	add_child(tower)
	tower.fired.connect(_on_tower_fired)
	if level > 0:
		_apply_upgrade_level(tower, stats, level)
	if String(tower_data.get("place", "free")) == "slot":
		var slot_index: int = int(tower_data.get("slot", -1))
		if slot_index < 0 or slot_index >= SLOTS.size() or _slot_occupied[slot_index]:
			tower.queue_free()
			return
		tower.global_position = SLOTS[slot_index]
		_slot_towers[slot_index] = tower
		_slot_occupied[slot_index] = true
		_slot_invested[slot_index] = invested
		var disk := _slot_disks[slot_index] as MeshInstance3D
		var disk_material := disk.material_override as StandardMaterial3D
		disk_material.albedo_color = Color(0.35, 0.8, 0.4, 0.5)
		return
	var raw_position: Array = tower_data.get("position", [])
	if raw_position.size() < 3:
		tower.queue_free()
		return
	var world_position := Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	tower.global_position = world_position
	_free_tower_positions.append(world_position)
	_free_towers.append(tower)
	_free_tower_invested.append(invested)


## Shared upgrade math: run it on click and on restore alike (same definition).
func _apply_upgrade_level(tower: TDTower, stats: TDTowerDefinition, level: int) -> void:
	tower.apply_upgrade(
		stats.damage * pow(stats.upgrade_damage_factor, level),
		stats.fire_interval * pow(stats.upgrade_rate_factor, level),
		stats.range_radius + stats.upgrade_range_bonus * float(level),
		stats.slow_factor * pow(stats.upgrade_slow_factor, level),
		level
	)


## One readable telegraph for the boss spawn (docs/GDD_3DTD.md line 96).
func _announce_boss() -> void:
	_hud.announce_boss("RIFT WARDEN เคลื่อนเข้ามาแล้ว!")
	_audio.play_sfx("wave_horn", 0.0, 0.68)
	_spawn_effect(TDCombatEffect.KIND_WAVE, PATH_POINTS[0])
	_metrics.record(&"boss_spawned", {"wave": wave_number})
