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
	&"splitter": preload("res://data/enemies/splitter.tres"),
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
	Vector3(-11.0, 0.0, 7.0),
	Vector3(-11.0, 0.0, -6.0),
	Vector3(-7.0, 0.0, -6.0),
	Vector3(-7.0, 0.0, 2.0),
	Vector3(0.0, 0.0, 2.0),
	Vector3(0.0, 0.0, -7.0),
	Vector3(8.0, 0.0, -7.0),
]

const SLOTS: Array[Vector3] = [
	Vector3(-13.6, 0.0, 4.6),
	Vector3(-8.4, 0.0, 5.0),
	Vector3(-13.6, 0.0, -2.0),
	Vector3(-1.8, 0.0, 4.6),
	Vector3(-9.2, 0.0, -9.2),
	Vector3(-4.8, 0.0, -8.6),
	Vector3(-4.4, 0.0, -2.2),
	Vector3(-9.4, 0.0, -0.4),
	Vector3(2.3, 0.0, -1.2),
	Vector3(-2.4, 0.0, -4.0),
	Vector3(2.4, 0.0, -9.6),
	Vector3(5.8, 0.0, -4.4),
]

# --- Scattered dressing (deterministic: identical layout every boot) ---
const DECOR_SEED: int = 20261106
const HILL_POSITIONS: Array[Vector3] = [
	Vector3(-26.0, 0.0, -24.0),
	Vector3(-10.0, 0.0, -25.0),
	Vector3(6.0, 0.0, -25.0),
	Vector3(20.0, 0.0, -23.0),
	Vector3(27.0, 0.0, -14.0),
	Vector3(30.0, 0.0, 2.0),
	Vector3(26.0, 0.0, 13.0),
	Vector3(-27.0, 0.0, -12.0),
	Vector3(-29.0, 0.0, 2.0),
	Vector3(-26.0, 0.0, 12.0),
]
const HILL_SCALES: Array[float] = [2.0, 1.8, 1.9, 1.7, 1.6, 1.5, 1.5, 1.6, 1.55, 1.5]

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
# parallel metadata per queued enemy: (spawn interval, health bonus, 0)
var _spawn_queue_meta: Array[Vector3] = []
var _spawn_cooldown: float = 0.0
var _spawned_alive: int = 0
# wave-chaining bookkeeping: merges mid-combat summons into the running wave
var _waves_in_flight: int = 0
var _pending_wave_numbers: Array[int] = []
var _metrics: RunMetrics
var _profile_repo: ProfileRepository
var _audio: TDAudioDirector
var _effects: Node3D
var _camera_trauma: float = 0.0
var _trauma_clock: float = 0.0
var _preview_default: String = ""

var _camera: Camera3D
var _ghost: MeshInstance3D
var _road_material_a: StandardMaterial3D
var _road_material_b: StandardMaterial3D
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
var _prop_points: Array[Vector3] = []


func _enemy_def(enemy_id: StringName) -> TDEnemyDefinition:
	return ENEMY_DEFS[enemy_id] as TDEnemyDefinition


func _tower_def(kind: int) -> TDTowerDefinition:
	return TOWER_DEFS[kind] as TDTowerDefinition


func _wave_def(wave_index: int) -> TDWaveDefinition:
	return WAVES[wave_index - 1] as TDWaveDefinition


## Game-time accessor for RunMetrics.game_time_provider (in-game seconds,
## unaffected by Engine.time_scale wall-clock compression in headless sims).
func _world_game_time() -> float:
	return _world_time


func _ready() -> void:
	_metrics = METRICS_SCRIPT.new()
	_metrics.begin()
	# Game-time stamping so pacing survives time-scaled headless sims.
	_metrics.game_time_provider = _world_game_time
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
	# Language switch (only reachable from the pause settings) rerenders the
	# data-driven tower cards so their text follows the new locale.
	var store := get_node_or_null("/root/TDSettings") as TDSettingsStore
	if store != null:
		store.settings_changed.connect(_on_settings_changed)
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
	# One pair of shared road materials: strips and bend patches use the exact
	# same surface so patches can never drift lighter than the strips.
	_road_material_a = StandardMaterial3D.new()
	_road_material_a.albedo_color = Color("#4b4a42")
	_road_material_b = StandardMaterial3D.new()
	_road_material_b.albedo_color = Color("#474541")

	# path strips between consecutive waypoints
	for index: int in range(PATH_POINTS.size() - 1):
		var start_point: Vector3 = PATH_POINTS[index]
		var end_point: Vector3 = PATH_POINTS[index + 1]
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		var length: float = start_point.distance_to(end_point)
		box.size = Vector3(2.6, 0.08, length)
		strip.mesh = box
		# subtle per-segment tone drift keeps long straights from reading flat
		strip.material_override = _road_material_a if index % 2 == 0 else _road_material_b
		strip.position = (start_point + end_point) * 0.5 + Vector3(0.0, 0.05, 0.0)
		var direction: Vector3 = (end_point - start_point).normalized()
		strip.look_at_from_position(strip.position, strip.position + direction, Vector3.UP)
		add_child(strip)
		_add_path_detail(start_point, end_point, index)

	# Bend seams: straight strips leave wedge gaps wherever the lane turns.
	for corner_index: int in range(1, PATH_POINTS.size() - 1):
		_add_road_corner(PATH_POINTS[corner_index], PATH_POINTS[corner_index - 1], PATH_POINTS[corner_index + 1])

	_add_spawn_beacon(PATH_POINTS[0])

	# Low-poly roadside dressing keeps the lane readable while adding scale.
	var barricade_scene: PackedScene = load("res://assets/models/props/barricade.glb")
	var street_light_scene: PackedScene = load("res://assets/models/props/street_light.glb")
	var sign_scene: PackedScene = load("res://assets/models/props/shelter_09_sign.glb")
	var tree_scene: PackedScene = load("res://assets/models/props/ash_tree.glb")
	if barricade_scene != null:
		for position: Vector3 in [Vector3(-12.8, 0.0, 8.8), Vector3(-6.6, 0.0, -10.8), Vector3(11.2, 0.0, -10.0)]:
			var barricade := barricade_scene.instantiate()
			barricade.position = position
			barricade.rotation.y = position.x * 0.08
			add_child(barricade)
			_prop_points.append(position)
	if street_light_scene != null:
		for position: Vector3 in [Vector3(-15.0, 0.0, 8.0), Vector3(10.0, 0.0, -4.4), Vector3(-4.2, 0.0, 4.6), Vector3(0.6, 0.0, -11.4)]:
			var street_light := street_light_scene.instantiate()
			street_light.position = position
			add_child(street_light)
			_prop_points.append(position)
	if tree_scene != null:
		# The tree right of the road mouth sat next to the shelter compound;
		# it moved to the far back-left so the base reads unobstructed.
		for position: Vector3 in [Vector3(-18.0, 0.0, 9.0), Vector3(-10.0, 0.0, -12.5), Vector3(14.5, 0.0, 7.5)]:
			var tree := tree_scene.instantiate()
			tree.position = position
			tree.rotation.y = position.x * 0.17
			tree.scale = Vector3.ONE * (0.85 + absf(position.z) * 0.012)
			add_child(tree)
			_prop_points.append(position)
	# One kept ruin anchors the story (the coast is broken); the settlement
	# itself is the modern survivor village built below.
	var ruin_scene: PackedScene = load("res://assets/models/props/ruined_house.glb")
	if ruin_scene != null:
		for placement: Array in [[Vector3(-15.0, 0.0, -13.5), 0.7]]:
			var ruin := ruin_scene.instantiate()
			ruin.position = placement[0]
			ruin.rotation.y = float(placement[1])
			add_child(ruin)
			_prop_points.append(placement[0])

	# the Shelter 09 blockhouse, now centered on the defensive compound east
	# of the road mouth — the whole grounds read as the valuable last holdout
	var compound_center: Vector3 = PATH_POINTS[PATH_POINTS.size() - 1] + Vector3(4.0, 0.0, 0.0)
	var shelter_scene: PackedScene = load("res://assets/models/props/shelter.glb")
	var shelter: Node3D
	if shelter_scene != null:
		shelter = shelter_scene.instantiate()
		shelter.name = "Shelter"
		shelter.position = compound_center
	else:
		var shelter_mesh := MeshInstance3D.new()
		var shelter_box := BoxMesh.new()
		shelter_box.size = Vector3(3.0, 2.2, 2.2)
		shelter_mesh.mesh = shelter_box
		var shelter_material := StandardMaterial3D.new()
		shelter_material.albedo_color = Color("#6e5c40")
		shelter_mesh.material_override = shelter_material
		shelter_mesh.position = compound_center + Vector3(0.0, 1.1, 0.0)
		shelter_mesh.name = "Shelter"
		shelter = shelter_mesh
	add_child(shelter)
	_prop_points.append(shelter.position)
	_build_shelter_grounds(compound_center)
	if sign_scene != null:
		var sign := sign_scene.instantiate()
		sign.position = PATH_POINTS[PATH_POINTS.size() - 1] + Vector3(0.0, 0.0, -2.0)
		sign.rotation.y = PI
		add_child(sign)
		_prop_points.append(sign.position)
	_add_shelter_crystal(compound_center)
	_build_spawn_portal()
	_paint_dressing_and_slot_disks()


## The enemy gate: a rift-lit ring that pulses at the walk-in end of the
## road, so players read where Hollows come from at a glance.
func _build_spawn_portal() -> void:
	var portal := Node3D.new()
	portal.name = "SpawnRift"
	portal.position = PATH_POINTS[0] + Vector3(0.0, 0.03, 0.0)
	add_child(portal)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.85
	disc_mesh.bottom_radius = 0.85
	disc_mesh.height = 0.03
	disc_mesh.radial_segments = 24
	disc.mesh = disc_mesh
	disc.material_override = _glow_material(Color(0.4, 0.2, 0.65), Color(0.55, 0.28, 0.95), 0.5)
	portal.add_child(disc)
	var outer := MeshInstance3D.new()
	var outer_mesh := TorusMesh.new()
	outer_mesh.inner_radius = 1.1
	outer_mesh.outer_radius = 1.24
	outer.mesh = outer_mesh
	outer.material_override = _glow_material(Color(0.5, 0.25, 0.8), Color(0.6, 0.32, 1.0), 1.1)
	outer.position.y = 0.12
	portal.add_child(outer)
	var inner := MeshInstance3D.new()
	var inner_mesh := TorusMesh.new()
	inner_mesh.inner_radius = 0.66
	inner_mesh.outer_radius = 0.76
	inner.mesh = inner_mesh
	inner.material_override = _glow_material(Color(0.5, 0.3, 0.8), Color(0.52, 0.3, 0.95), 0.9)
	inner.position.y = 0.16
	portal.add_child(inner)
	var pulse := outer.create_tween().set_loops()
	pulse.tween_property(outer, "scale", Vector3.ONE * 1.14, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(outer, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var swirl := inner.create_tween().set_loops()
	swirl.tween_property(inner, "rotation:y", TAU, 2.4)


## Boss arrival reads as a threat: a slow pulsing ring rides under the Warden
## while it walks. Attached to the enemy node so it follows for free.
func _attach_boss_aura(boss: TDEnemy) -> void:
	var aura := MeshInstance3D.new()
	var aura_mesh := CylinderMesh.new()
	aura_mesh.top_radius = 1.9
	aura_mesh.bottom_radius = 1.9
	aura_mesh.height = 0.05
	aura_mesh.radial_segments = 28
	aura.mesh = aura_mesh
	aura.material_override = _glow_material(Color(0.6, 0.2, 0.35), Color(0.85, 0.25, 0.45), 0.9)
	aura.position = Vector3(0.0, 0.05, 0.0)
	boss.add_child(aura)
	var pulse := aura.create_tween().set_loops()
	pulse.tween_property(aura, "scale", Vector3.ONE * 1.2, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(aura, "scale", Vector3.ONE, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Slot disks, the village district, extra trees, pond and scatter dressing:
## everything that lays down on top of the painted roads/grounds.
func _paint_dressing_and_slot_disks() -> void:
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

	_build_village()
	_build_extra_trees()
	_build_pond()
	_scatter_environment()


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


## Warm-glowing surface for lit faces (windows, wall strips, beacon tips).
func _glow_material(albedo: Color, emission_color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


## The Shelter 09 compound grounds: raised platform with a light halo, a rear
## wall arc with lit crenels, front pylons, banner pair, and a road spur into
## the open terrace mouth. The road-facing side stays wall-free so walking
## enemies reach the path end without clipping anything (verified radii).
func _build_shelter_grounds(center: Vector3) -> void:
	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 3.0
	platform_mesh.bottom_radius = 3.3
	platform_mesh.height = 0.19
	platform_mesh.radial_segments = 28
	platform.mesh = platform_mesh
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color("#4a5058")
	platform_material.metallic = 0.35
	platform_material.roughness = 0.75
	platform.material_override = platform_material
	platform.position = center + Vector3(0.0, 0.095, 0.0)
	add_child(platform)

	var edge := MeshInstance3D.new()
	var edge_mesh := TorusMesh.new()
	edge_mesh.inner_radius = 3.0
	edge_mesh.outer_radius = 3.15
	edge.mesh = edge_mesh
	edge.material_override = _glow_material(Color(0.3, 0.6, 0.9), Color(0.25, 0.6, 1.0), 1.35)
	edge.position = center + Vector3(0.0, 0.2, 0.0)
	add_child(edge)

	var wall_material := _flat_material(Color("#535a60"), 0.8)
	var crenel_material := _glow_material(Color(0.4, 0.7, 1.0), Color(0.2, 0.55, 1.0), 0.85)
	for angle_degrees: int in [15, 60, 105, 255, 300, 345]:
		var angle: float = deg_to_rad(float(angle_degrees))
		var direction := Vector3(sin(angle), 0.0, -cos(angle))  # wall long axis
		var radian_position: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * 3.9
		var wall := MeshInstance3D.new()
		var wall_box := BoxMesh.new()
		wall_box.size = Vector3(3.0, 1.0, 0.5)
		wall.mesh = wall_box
		wall.material_override = wall_material
		wall.position = radian_position + Vector3(0.0, 0.5, 0.0)
		wall.rotation.y = deg_to_rad(float(angle_degrees)) + PI / 2.0
		add_child(wall)
		var crenel := MeshInstance3D.new()
		var crenel_box := BoxMesh.new()
		crenel_box.size = Vector3(3.0, 0.08, 0.62)
		crenel.mesh = crenel_box
		crenel.material_override = crenel_material
		crenel.position = radian_position + Vector3(0.0, 1.1, 0.0)
		crenel.rotation.y = wall.rotation.y
		add_child(crenel)
		_prop_points.append(radian_position)

	# Front pylons flank the open terrace mouth (not blocking the road).
	var pylon_material := _flat_material(Color("#4c5259"), 0.75)
	var tip_material := _glow_material(Color(0.45, 0.8, 1.0), Color(0.25, 0.6, 1.0), 1.7)
	for side_z: float in [-2.9, 2.9]:
		var pylon_position: Vector3 = center + Vector3(-3.6, 0.0, side_z)
		var pylon := MeshInstance3D.new()
		var pylon_box := BoxMesh.new()
		pylon_box.size = Vector3(0.4, 2.7, 0.4)
		pylon.mesh = pylon_box
		pylon.material_override = pylon_material
		pylon.position = pylon_position + Vector3(0.0, 1.35, 0.0)
		add_child(pylon)
		var tip := MeshInstance3D.new()
		var tip_box := BoxMesh.new()
		tip_box.size = Vector3(0.3, 0.24, 0.3)
		tip.mesh = tip_box
		tip.material_override = tip_material
		tip.position = pylon_position + Vector3(0.0, 2.85, 0.0)
		add_child(tip)
		_prop_points.append(pylon_position)

	# Banner pair framing the mouth: warm amber = "the last light" held here.
	var pole_material := _flat_material(Color("#393f45"), 0.7)
	var banner_material := _glow_material(Color(0.95, 0.62, 0.2), Color(0.9, 0.5, 0.12), 1.1)
	for side_z: float in [-1.9, 1.9]:
		var pole_position: Vector3 = center + Vector3(-2.6, 0.0, side_z)
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.05
		pole_mesh.bottom_radius = 0.05
		pole_mesh.height = 3.0
		pole.mesh = pole_mesh
		pole.material_override = pole_material
		pole.position = pole_position + Vector3(0.0, 1.5, 0.0)
		add_child(pole)
		var banner := MeshInstance3D.new()
		var banner_box := BoxMesh.new()
		banner_box.size = Vector3(0.04, 0.9, 0.8)
		banner.mesh = banner_box
		banner.material_override = banner_material
		banner.position = pole_position + Vector3(0.0, 2.1, 0.0)
		add_child(banner)
		_prop_points.append(pole_position)

	# Road spur from the lane end into the compound mouth.
	var spur := MeshInstance3D.new()
	var spur_box := BoxMesh.new()
	spur_box.size = Vector3(2.4, 0.08, 2.6)
	spur.mesh = spur_box
	spur.material_override = _road_material_a
	spur.position = center + Vector3(-3.4, 0.05, 0.0)
	add_child(spur)
	_prop_points.append(spur.position)


## Survivor settlement: seven modern low-poly houses along the left ridge and
## the road-front bend, plus settlement lighting. Built in code (zero assets).
func _build_village() -> void:
	var house_layout: Array[Array] = [
		[Vector3(-17.5, 0.0, 5.5), -0.35, 1.0],
		[Vector3(-19.0, 0.0, 2.5), 0.55, 0.92],
		[Vector3(-19.0, 0.0, -1.0), 2.55, 1.06],
		[Vector3(-16.0, 0.0, 0.0), 0.15, 0.96],
		[Vector3(-14.5, 0.0, -5.5), 2.2, 1.0],
		[Vector3(4.5, 0.0, 6.6), -0.6, 0.8],
		[Vector3(7.0, 0.0, 4.2), 0.12, 0.84],
	]
	for entry: Array in house_layout:
		var position: Vector3 = entry[0]
		_build_modern_house(position, float(entry[1]), float(entry[2]))
		_prop_points.append(position)
	var street_light_scene: PackedScene = load("res://assets/models/props/street_light.glb")
	if street_light_scene != null:
		for position: Vector3 in [Vector3(-16.2, 0.0, 2.6), Vector3(-17.3, 0.0, -3.2), Vector3(5.6, 0.0, 6.3)]:
			var street_light := street_light_scene.instantiate()
			street_light.position = position
			add_child(street_light)
			_prop_points.append(position)


## One modern low-poly house: stacked slabs, flat roof with overhang, tilted
## solar panel, warm lit window bands and a doorway — a survivor-tech look
## that reads clean at the fixed iso angle.
func _build_modern_house(position: Vector3, rotation_y: float, scale_factor: float) -> void:
	var house := Node3D.new()
	house.position = position
	house.rotation.y = rotation_y
	house.scale = Vector3.ONE * scale_factor
	add_child(house)
	var wall_material := _flat_material(Color("#79817a"), 0.85)
	var upper_material := _flat_material(Color("#8a9188"), 0.85)
	var trim_material := _flat_material(Color("#31363a"), 0.7)
	var window_material := _glow_material(Color(1.0, 0.78, 0.45), Color(1.0, 0.62, 0.22), 1.6)
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.16, 0.3, 0.52)
	panel_material.metallic = 0.65
	panel_material.roughness = 0.3

	var lower := MeshInstance3D.new()
	var lower_box := BoxMesh.new()
	lower_box.size = Vector3(3.4, 1.5, 2.8)
	lower.mesh = lower_box
	lower.material_override = wall_material
	lower.position.y = 0.75
	house.add_child(lower)
	var upper := MeshInstance3D.new()
	var upper_box := BoxMesh.new()
	upper_box.size = Vector3(2.5, 1.1, 2.3)
	upper.mesh = upper_box
	upper.material_override = upper_material
	upper.position = Vector3(0.25, 2.05, 0.0)
	house.add_child(upper)
	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(3.75, 0.12, 3.15)
	roof.mesh = roof_box
	roof.material_override = trim_material
	roof.position = Vector3(0.0, 2.68, 0.0)
	house.add_child(roof)
	var front_window := MeshInstance3D.new()
	var front_window_box := BoxMesh.new()
	front_window_box.size = Vector3(3.45, 0.55, 0.05)
	front_window.mesh = front_window_box
	front_window.material_override = window_material
	front_window.position = Vector3(0.0, 1.05, 1.42)
	house.add_child(front_window)
	var back_window := MeshInstance3D.new()
	back_window.mesh = front_window_box
	back_window.material_override = window_material
	back_window.position = Vector3(0.0, 1.05, -1.42)
	house.add_child(back_window)
	var door := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.8, 1.35, 0.06)
	door.mesh = door_box
	door.material_override = trim_material
	door.position = Vector3(-0.95, 0.68, 1.42)
	house.add_child(door)
	var solar := MeshInstance3D.new()
	var solar_box := BoxMesh.new()
	solar_box.size = Vector3(1.3, 0.04, 1.0)
	solar.mesh = solar_box
	solar.material_override = panel_material
	solar.position = Vector3(0.35, 2.86, 0.7)
	solar.rotation.x = -0.42
	house.add_child(solar)
	var antenna := MeshInstance3D.new()
	var antenna_mesh := CylinderMesh.new()
	antenna_mesh.top_radius = 0.02
	antenna_mesh.bottom_radius = 0.02
	antenna_mesh.height = 0.9
	antenna.mesh = antenna_mesh
	antenna.material_override = trim_material
	antenna.position = Vector3(-0.95, 3.1, -0.65)
	house.add_child(antenna)


## Extra trees placed deliberately far from the shelter compound so the base
## stays the visual hero; positions verified clear of road, slots and hills.
func _build_extra_trees() -> void:
	var tree_scene: PackedScene = load("res://assets/models/props/ash_tree.glb")
	if tree_scene == null:
		return
	for placement: Array in [
		[Vector3(-13.5, 0.0, 8.8), 0.9, 1.0],
		[Vector3(-12.5, 0.0, -15.5), 2.4, 1.15],
		[Vector3(6.0, 0.0, 9.2), 1.6, 0.9],
		[Vector3(-6.5, 0.0, 8.6), 5.0, 0.95],
	]:
		var tree := tree_scene.instantiate()
		tree.position = placement[0]
		tree.rotation.y = float(placement[1])
		tree.scale = Vector3.ONE * float(placement[2])
		add_child(tree)
		_prop_points.append(placement[0])


## Moonlit foreground pond (shore, water with a deep tint, rim rocks and
## reeds). Pure dressing; gameplay slots stay outside the shore radius.
func _build_pond() -> void:
	var pond_center: Vector3 = Vector3(-2.5, 0.0, 10.5)
	var shore := MeshInstance3D.new()
	var shore_mesh := CylinderMesh.new()
	shore_mesh.top_radius = 4.35
	shore_mesh.bottom_radius = 4.55
	shore_mesh.height = 0.12
	shore_mesh.radial_segments = 26
	shore.mesh = shore_mesh
	shore.material_override = _flat_material(Color("#6d6555"), 1.0)
	shore.position = pond_center + Vector3(0.0, 0.05, 0.0)
	add_child(shore)
	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 4.1
	water_mesh.bottom_radius = 4.25
	water_mesh.height = 0.09
	water_mesh.radial_segments = 26
	water.mesh = water_mesh
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.13, 0.3, 0.4, 0.88)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.metallic = 0.4
	water_material.roughness = 0.12
	water_material.emission_enabled = true
	water_material.emission = Color(0.05, 0.18, 0.26)
	water_material.emission_energy_multiplier = 0.5
	water.material_override = water_material
	water.position = pond_center + Vector3(0.0, 0.09, 0.0)
	add_child(water)
	var deep := MeshInstance3D.new()
	var deep_mesh := CylinderMesh.new()
	deep_mesh.top_radius = 2.2
	deep_mesh.bottom_radius = 2.3
	deep_mesh.height = 0.05
	deep_mesh.radial_segments = 24
	deep.mesh = deep_mesh
	deep.material_override = _flat_material(Color(0.07, 0.2, 0.27), 0.15)
	deep.position = pond_center + Vector3(0.0, 0.14, 0.0)
	add_child(deep)
	# rim rocks + reeds: seeded so the shore reads the same every boot
	var rng := RandomNumberGenerator.new()
	rng.seed = DECOR_SEED + 17
	var rock_material := _flat_material(Color("#62625a"), 1.0)
	var reed_material := _flat_material(Color("#4b5c3c"), 1.0)
	for angle_degrees: int in [40, 150, 265]:
		var angle: float = deg_to_rad(float(angle_degrees))
		var rock := MeshInstance3D.new()
		rock.mesh = _build_rock_variant(rng)
		rock.material_override = rock_material
		rock.position = pond_center + Vector3(cos(angle), 0.0, sin(angle)) * 4.25 + Vector3(0.0, 0.02, 0.0)
		rock.scale = Vector3.ONE * 0.55
		add_child(rock)
	for angle_degrees: int in [110, 200, 330]:
		var angle: float = deg_to_rad(float(angle_degrees))
		for reed_index: int in range(3):
			var reed := MeshInstance3D.new()
			var reed_mesh := CylinderMesh.new()
			reed_mesh.top_radius = 0.02
			reed_mesh.bottom_radius = 0.04
			reed_mesh.height = rng.randf_range(0.5, 0.8)
			reed_mesh.radial_segments = 6
			reed.mesh = reed_mesh
			reed.material_override = reed_material
			var jitter := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
			reed.position = pond_center + Vector3(cos(angle), 0.0, sin(angle)) * 4.0 + jitter + Vector3(0.0, 0.28, 0.0)
			reed.rotation.z = rng.randf_range(-0.12, 0.12)
			add_child(reed)
	# keep-out ring so scatter never lands on the water
	for ring_radius: float in [2.0, 3.2]:
		for ring_index: int in range(8):
			var ring_angle: float = TAU * float(ring_index) / 8.0
			_prop_points.append(pond_center + Vector3(cos(ring_angle), 0.0, sin(ring_angle)) * ring_radius)
	_prop_points.append(pond_center)
	_prop_points.append(pond_center + Vector3(0.0, 0.0, 4.6))


func _add_path_detail(start_point: Vector3, end_point: Vector3, segment_index: int) -> void:
	var direction: Vector3 = (end_point - start_point).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x)
	var midpoint: Vector3 = (start_point + end_point) * 0.5
	var segment_length: float = start_point.distance_to(end_point)
	# Junction insets: shoulder curbs must stop at the rim of the corner
	# patches, otherwise their ends streak across the crossing road strip.
	var start_inset: float = _corner_inset(segment_index) if segment_index > 0 else 0.0
	var end_inset: float = _corner_inset(segment_index + 1) if segment_index < PATH_POINTS.size() - 2 else 0.0
	var curb_length: float = segment_length - start_inset - end_inset
	if curb_length > 0.05:
		var shoulder_material := StandardMaterial3D.new()
		shoulder_material.albedo_color = Color("#252b27")
		shoulder_material.roughness = 1.0
		for side_sign: float in [-1.0, 1.0]:
			var shoulder := MeshInstance3D.new()
			var shoulder_mesh := BoxMesh.new()
			shoulder_mesh.size = Vector3(0.38, 0.035, curb_length)
			shoulder.mesh = shoulder_mesh
			shoulder.material_override = shoulder_material
			var shoulder_position: Vector3 = midpoint + direction * ((start_inset - end_inset) * 0.5) + side * side_sign * 1.52 + Vector3(0.0, 0.11, 0.0)
			shoulder.look_at_from_position(shoulder_position, shoulder_position + direction, Vector3.UP)
			add_child(shoulder)
	var dash_start: float = start_inset + 0.5
	var dash_end: float = segment_length - end_inset - 0.3
	var mark_along: float = dash_start
	while mark_along <= dash_end:
		var mark := MeshInstance3D.new()
		var mark_mesh := BoxMesh.new()
		mark_mesh.size = Vector3(0.09, 0.018, 1.0)
		mark.mesh = mark_mesh
		var mark_position: Vector3 = start_point + direction * mark_along + Vector3(0.0, 0.105, 0.0)
		mark.position = mark_position
		mark.look_at_from_position(mark_position, mark_position + direction, Vector3.UP)
		var mark_material := StandardMaterial3D.new()
		mark_material.albedo_color = Color("#a99873")
		mark.material_override = mark_material
		add_child(mark)
		mark_along += 3.0


## Junction geometry shared by the road painter: the patch radius at a corner
## (from how sharply the two legs bend) and how far along each leg the patch
## reaches at curb offset, so curbs and caps can end flush on the patch rim.
func _corner_patch_radius(turn_dot: float) -> float:
	# right-angle zigzag bends: the outer wedge apex sits ~1.84 m out on the
	# diagonal, so the disc must reach that far or a grass nick survives
	if absf(turn_dot) <= 0.15:
		return 1.86
	if turn_dot < -0.05:
		return 1.66
	return 1.44


func _corner_inset(corner_index: int) -> float:
	var incoming_dir: Vector3 = (PATH_POINTS[corner_index] - PATH_POINTS[corner_index - 1]).normalized()
	var outgoing_dir: Vector3 = (PATH_POINTS[corner_index + 1] - PATH_POINTS[corner_index]).normalized()
	var radius: float = _corner_patch_radius(incoming_dir.dot(outgoing_dir))
	return sqrt(maxf(radius * radius - 1.52 * 1.52, 0.0))


# --- Road bends & environment dressing ------------------------------------
# The straight road strips leave wedge seams of raw ground at every turning
# point; these helpers quilt the bends shut and pitch in the low-poly dressing.

func _flat_material(albedo_color: Color, roughness_value: float = 0.95) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo_color
	material.roughness = roughness_value
	return material


## One bend of the road: straight strips leave wedge seams at turning points,
## so a round asphalt patch (a hair above the strips so nothing z-fights)
## quilts the bend shut. It reuses the strip material so its tone can never
## drift, and curb-end caps sit on the patch rim to keep the shoulder line
## reading continuously through the junction.
func _add_road_corner(point: Vector3, incoming: Vector3, outgoing: Vector3) -> void:
	var incoming_dir: Vector3 = (point - incoming).normalized()
	var outgoing_dir: Vector3 = (outgoing - point).normalized()
	var turn_dot: float = incoming_dir.dot(outgoing_dir)

	var patch_radius: float = _corner_patch_radius(turn_dot)
	var patch := MeshInstance3D.new()
	var patch_mesh := CylinderMesh.new()
	patch_mesh.top_radius = patch_radius
	patch_mesh.bottom_radius = patch_radius
	patch_mesh.height = 0.084
	patch.mesh = patch_mesh
	patch.material_override = _road_material_a
	patch.position = point + Vector3(0.0, 0.052, 0.0)
	add_child(patch)

	# how far the patch reaches along each leg at curb offset — the curb ends
	# and their caps land exactly on that rim
	var inset: float = sqrt(maxf(patch_radius * patch_radius - 1.52 * 1.52, 0.0))
	var curb_material := _flat_material(Color("#252b27"), 1.0)
	var incoming_side: Vector3 = Vector3(-incoming_dir.z, 0.0, incoming_dir.x)
	var outgoing_side: Vector3 = Vector3(-outgoing_dir.z, 0.0, outgoing_dir.x)
	for side_sign: float in [-1.0, 1.0]:
		for cap_spot: Vector3 in [
			point - incoming_dir * inset + incoming_side * side_sign * 1.52,
			point + outgoing_dir * inset + outgoing_side * side_sign * 1.52,
		]:
			var cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.24
			cap_mesh.bottom_radius = 0.24
			cap_mesh.height = 0.035
			cap.mesh = cap_mesh
			cap.material_override = curb_material
			cap.position = cap_spot + Vector3(0.0, 0.113, 0.0)
			add_child(cap)


## Shortest distance from a point to the whole enemy path (segment-wise).
func _path_distance_to(point: Vector3) -> float:
	var best: float = INF
	for index: int in range(PATH_POINTS.size() - 1):
		var to_end: Vector3 = PATH_POINTS[index + 1] - PATH_POINTS[index]
		var along: float = clampf((point - PATH_POINTS[index]).dot(to_end) / to_end.length_squared(), 0.0, 1.0)
		best = minf(best, (PATH_POINTS[index] + to_end * along).distance_to(point))
	return best


## Finds a position on open ground away from the road and placed props;
## Vector3.INF when nothing qualifies after the attempts budget. z_min/z_max
## bound the search band (tall props keep away from the camera frustum).
func _open_ground(rng: RandomNumberGenerator, path_min: float, path_max: float = 0.0, prop_min: float = 2.0, z_min: float = -15.5, z_max: float = 15.5) -> Vector3:
	for _attempt: int in range(40):
		var candidate := Vector3(rng.randf_range(-19.0, 19.0), 0.0, rng.randf_range(z_min, z_max))
		var path_distance: float = _path_distance_to(candidate)
		if path_distance < path_min:
			continue
		if path_max > 0.0 and path_distance > path_max:
			continue
		var blocked := false
		for prop_position: Vector3 in _prop_points:
			if prop_position.distance_to(candidate) < prop_min:
				blocked = true
				break
		if blocked:
			continue
		return candidate
	return Vector3.INF


func _scatter_environment() -> void:
	# Deterministic seed: identical dressing every boot keeps selfshots and
	# player learning stable.
	var rng := RandomNumberGenerator.new()
	rng.seed = DECOR_SEED
	_scatter_dirt_patches(rng)
	_scatter_rocks(rng)
	_scatter_grass(rng)
	_scatter_rift_shards(rng)
	_scatter_distant_hills()
	_scatter_extra_props(rng)


func _scatter_dirt_patches(rng: RandomNumberGenerator) -> void:
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.024
	disc_mesh.radial_segments = 24
	# all tones sit just darker than the ground: reads as damp ground, not mud
	var dirt_colors := [Color("#383f35"), Color("#343a31"), Color("#3a4036"), Color("#333830")]
	for _index: int in range(12):
		var raw: Vector3 = _open_ground(rng, 2.8)
		if raw == Vector3.INF:
			continue
		var patch := MeshInstance3D.new()
		patch.mesh = disc_mesh
		patch.material_override = _flat_material(dirt_colors[rng.randi_range(0, dirt_colors.size() - 1)], 1.0)
		patch.position = raw + Vector3(0.0, 0.022, 0.0)
		patch.scale = Vector3(rng.randf_range(0.8, 1.8), 1.0, rng.randf_range(0.8, 1.6))
		patch.rotation.y = rng.randf() * TAU
		add_child(patch)


func _scatter_rocks(rng: RandomNumberGenerator) -> void:
	var rock_material := _flat_material(Color("#62625a"), 1.0)
	var variants: Array[Mesh] = []
	for _variant: int in range(3):
		variants.append(_build_rock_variant(rng))
	for index: int in range(26):
		var raw: Vector3
		if index < 10:
			raw = _open_ground(rng, 2.3, 4.2, 2.4)  # shoulder boulders road-side
		else:
			raw = _open_ground(rng, 5.5, 0.0, 2.2)
		if raw == Vector3.INF:
			continue
		var rock := MeshInstance3D.new()
		rock.mesh = variants[rng.randi_range(0, variants.size() - 1)]
		rock.material_override = rock_material
		var size_factor: float = rng.randf_range(0.5, 1.0)
		rock.scale = Vector3(size_factor, size_factor * rng.randf_range(0.6, 0.85), size_factor * rng.randf_range(0.85, 1.15))
		rock.position = raw + Vector3(0.0, -0.03, 0.0)
		rock.rotation.y = rng.randf() * TAU
		add_child(rock)
		_prop_points.append(raw)


## Deforms a unit icosahedron once; per-face normals on the unindexed surface
## give the flat-shaded low-poly boulder look with zero imported assets.
func _build_rock_variant(rng: RandomNumberGenerator) -> ArrayMesh:
	var unit_vertices := PackedVector3Array([
		Vector3(-1.0, 1.618, 0.0), Vector3(1.0, 1.618, 0.0), Vector3(-1.0, -1.618, 0.0), Vector3(1.0, -1.618, 0.0),
		Vector3(0.0, -1.0, 1.618), Vector3(0.0, 1.0, 1.618), Vector3(0.0, -1.0, -1.618), Vector3(0.0, 1.0, -1.618),
		Vector3(1.618, 0.0, -1.0), Vector3(1.618, 0.0, 1.0), Vector3(-1.618, 0.0, -1.0), Vector3(-1.618, 0.0, 1.0),
	])
	var unit_faces := [
		PackedInt32Array([0, 11, 5]), PackedInt32Array([0, 5, 1]), PackedInt32Array([0, 1, 7]), PackedInt32Array([0, 7, 10]), PackedInt32Array([0, 10, 11]),
		PackedInt32Array([1, 5, 9]), PackedInt32Array([5, 11, 4]), PackedInt32Array([11, 10, 2]), PackedInt32Array([10, 7, 6]), PackedInt32Array([7, 1, 8]),
		PackedInt32Array([3, 9, 4]), PackedInt32Array([3, 4, 2]), PackedInt32Array([3, 2, 6]), PackedInt32Array([3, 6, 8]), PackedInt32Array([3, 8, 9]),
		PackedInt32Array([4, 9, 5]), PackedInt32Array([2, 4, 11]), PackedInt32Array([6, 2, 10]), PackedInt32Array([8, 6, 7]), PackedInt32Array([9, 8, 1]),
	]
	var deformed_vertices: Array[Vector3] = []
	for unit_vertex: Vector3 in unit_vertices:
		var deformed := unit_vertex.normalized() * rng.randf_range(0.72, 1.05)
		deformed.y *= 0.75
		deformed_vertices.append(deformed)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: PackedInt32Array in unit_faces:
		for vertex_index: int in range(3):
			surface.add_vertex(deformed_vertices[face[vertex_index]])
	surface.generate_normals()
	return surface.commit()


func _scatter_grass(rng: RandomNumberGenerator) -> void:
	var tuft_mesh := CylinderMesh.new()
	tuft_mesh.top_radius = 0.01
	tuft_mesh.bottom_radius = 0.13
	tuft_mesh.height = 0.5
	tuft_mesh.radial_segments = 7
	var grass_colors := [Color("#54624a"), Color("#4c5942"), Color("#5b684f"), Color("#45523d")]
	for index: int in range(56):
		var raw: Vector3 = _open_ground(rng, 2.1, 0.0, 1.2)
		if raw == Vector3.INF:
			continue
		var tuft := MeshInstance3D.new()
		tuft.mesh = tuft_mesh
		tuft.material_override = _flat_material(grass_colors[index % grass_colors.size()], 1.0)
		tuft.position = raw + Vector3(0.0, 0.22, 0.0)
		var tuft_scale: float = rng.randf_range(0.7, 1.3)
		tuft.scale = Vector3(tuft_scale, tuft_scale, tuft_scale)
		tuft.rotation = Vector3(rng.randf_range(-0.16, 0.16), rng.randf() * TAU, rng.randf_range(-0.16, 0.16))
		add_child(tuft)


func _scatter_rift_shards(rng: RandomNumberGenerator) -> void:
	var shard_mesh := PrismMesh.new()
	shard_mesh.size = Vector3(0.22, 0.6, 0.22)
	var shard_material := _flat_material(Color(0.28, 0.18, 0.42), 0.6)
	shard_material.emission_enabled = true
	shard_material.emission = Color(0.38, 0.1, 0.62)
	shard_material.emission_energy_multiplier = 0.55
	for _index: int in range(3):
		var raw: Vector3 = _open_ground(rng, 2.2, 4.0, 2.2)
		if raw == Vector3.INF:
			continue
		var shard := MeshInstance3D.new()
		shard.mesh = shard_mesh
		shard.material_override = shard_material
		shard.position = raw + Vector3(0.0, 0.12, 0.0)
		shard.scale = Vector3.ONE * rng.randf_range(0.55, 0.9)
		shard.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		add_child(shard)


func _scatter_distant_hills() -> void:
	var hill_mesh := SphereMesh.new()
	hill_mesh.radius = 7.0
	hill_mesh.height = 14.0
	hill_mesh.radial_segments = 24
	hill_mesh.rings = 14
	# hazy tones so the ridge reads as distant landscape, not heavy props
	var hill_materials := [_flat_material(Color("#3a4138"), 1.0), _flat_material(Color("#3e443b"), 1.0)]
	for index: int in range(HILL_POSITIONS.size()):
		var hill := MeshInstance3D.new()
		hill.mesh = hill_mesh
		var scale_base: float = HILL_SCALES[index]
		hill.scale = Vector3(scale_base, 0.42, scale_base)
		hill.position = HILL_POSITIONS[index] + Vector3(0.0, -1.6, 0.0)
		hill.material_override = hill_materials[index % 2]
		add_child(hill)


func _scatter_extra_props(rng: RandomNumberGenerator) -> void:
	var tree_scene: PackedScene = load("res://assets/models/props/ash_tree.glb")
	if tree_scene != null:
		for _index: int in range(7):
			# z capped at 8.5: closer to the camera a tree fills the frustum
			# as a beige blob instead of reading as a tree
			var raw: Vector3 = _open_ground(rng, 3.4, 0.0, 3.2, -15.5, 8.5)
			if raw == Vector3.INF:
				continue
			var tree := tree_scene.instantiate()
			tree.position = raw
			tree.rotation.y = rng.randf() * TAU
			tree.scale = Vector3.ONE * rng.randf_range(0.85, 1.25)
			add_child(tree)
			_prop_points.append(raw)
	var house_scene: PackedScene = load("res://assets/models/props/ruined_house.glb")
	if house_scene != null:
		# houses stay deep in the field (z <= 6): near the camera they tower
		# over the lane instead of dressing the horizon
		var raw_house: Vector3 = _open_ground(rng, 7.0, 0.0, 5.0, -15.5, 6.0)
		if raw_house != Vector3.INF:
			var house := house_scene.instantiate()
			house.position = raw_house
			house.rotation.y = rng.randf() * TAU
			house.scale = Vector3.ONE * 0.9
			add_child(house)
			_prop_points.append(raw_house)


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
	_refresh_tower_cards()
	_hud.tower_selected.connect(_on_tower_selected)
	_hud.start_wave_pressed.connect(start_wave)
	_hud.restart_pressed.connect(_restart)
	_hud.resume_pressed.connect(toggle_pause)
	_hud.title_pressed.connect(_go_to_title)


func _on_tower_selected(kind: int) -> void:
	_select_kind(kind)


## Language switch rerenders the data-driven cards; everything else flows
## through the HUD registry already.
func _on_settings_changed(section: StringName, key: StringName) -> void:
	if section == &"localization" and key == &"locale":
		_refresh_tower_cards()


# --- Tower cards & hover (งานข้อ 1/2/4: พลัง+ราคาต่อระดับบน HUD) ----------

## Data-driven tower cards: label = name + price, tooltip lists every level's
## power from the .tres arrays so pricing/power stay readable in-game.
func _refresh_tower_cards() -> void:
	if _hud == null:
		return
	var labels: Array[String] = []
	var tooltips: Array[String] = []
	for kind: int in TOWER_DEFS.keys():
		var stats: TDTowerDefinition = TOWER_DEFS[kind] as TDTowerDefinition
		labels.append(tr("TOWER_CARD_LABEL") % [kind + 1, stats.display_name, stats.cost])
		tooltips.append(_tower_stats_text(stats))
	_hud.set_tower_cards(labels, tooltips)


## One line per level: "Lv0: ดาเมจ 6 · 0.45 วิ/นัด · DPS 13.3" (+ splash/slow).
func _tower_stats_text(stats: TDTowerDefinition) -> String:
	var lines: Array[String] = []
	for level: int in range(TDTower.MAX_LEVEL + 1):
		lines.append(_tower_level_summary(stats, level))
	return "\n".join(lines)


func _tower_level_summary(stats: TDTowerDefinition, level: int) -> String:
	if stats.tower_kind == TDTower.Kind.TANGLE_EMITTER:
		var range_text: String = tr("TOWER_RANGE") % stats.level_range[level]
		return tr("TOWER_SLOW") % [level, stats.level_slow[level], range_text]
	var damage: float = stats.level_damage[level]
	var interval: float = stats.level_fire_interval[level]
	var dps: float = damage / maxf(interval, 0.01)
	var summary: String = tr("TOWER_SUMMARY") % [level, damage, interval, dps]
	if stats.level_splash[level] > 0.0:
		summary += " · " + (tr("TOWER_SPLASH") % stats.level_splash[level])
	return summary


## Hover on an occupied slot: current stats plus what the next level buys.
func _occupied_hover_text(tower: TDTower) -> String:
	var stats: TDTowerDefinition = _tower_def(tower.kind)
	var current_line: String = "%s Lv%d · %s" % [stats.display_name, tower.level, _tower_level_summary(stats, tower.level)]
	if tower.level >= TDTower.MAX_LEVEL:
		return "%s\n%s" % [current_line, tr("HOVER_MAXED")]
	var next_level: int = tower.level + 1
	var upgrade_cost: int = stats.upgrade_costs[tower.level]
	return "%s\n%s" % [
		current_line,
		tr("HOVER_UPGRADE") % [upgrade_cost, next_level, _tower_level_summary(stats, next_level)],
	]


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
		stats.level_range[0],
		stats.level_damage[0],
		stats.level_fire_interval[0],
		stats.level_splash[0],
		stats.level_slow[0],
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
	tower.setup(stats.tower_kind, stats.level_range[0], stats.level_damage[0], stats.level_fire_interval[0],
		stats.level_splash[0], stats.level_slow[0], _projectile_container, stats.model_scene)
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
	_apply_upgrade_level(tower, stats, tower.level + 1)
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
	_apply_upgrade_level(tower, stats, tower.level + 1)
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
			if _slot_occupied[slot] and _slot_towers[slot] != null:
				_hud.show_wave_preview(_occupied_hover_text(_slot_towers[slot]))
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

## Chaining: starting a wave while another is still running merges the new
## composition into the same spawn queue; clear bonuses pay per queued wave
## (_pending_wave_numbers tracks who has not been paid yet).

func start_wave() -> void:
	if is_over or wave_number >= WAVES.size():
		return
	wave_number += 1  # works in prep (first call) and mid-combat (chains)
	is_combat = true
	var wave: TDWaveDefinition = _wave_def(wave_number)
	for enemy_id: StringName in wave.composition.keys():
		var count: int = int(wave.composition[enemy_id])
		for _index: int in range(count):
			_spawn_queue.append(enemy_id)
			# per-entry spacing/health so mixed waves behave correctly
			_spawn_queue_meta.append(Vector3(wave.spawn_interval, wave.health_bonus, 0.0))
	_waves_in_flight += 1
	_pending_wave_numbers.append(wave_number)
	_hud.set_combat_state(true, wave_number < WAVES.size())
	_spawn_effect(TDCombatEffect.KIND_WAVE, PATH_POINTS[0])
	_audio.play_sfx("wave_horn")
	_metrics.record(&"wave_started", {"wave": wave_number})


func _spawn_tick(delta: float) -> void:
	if _spawn_queue.is_empty():
		if _spawned_alive <= 0 and _waves_in_flight > 0:
			_clear_wave()
		return
	_spawn_cooldown = maxf(_spawn_cooldown - delta, 0.0)
	if _spawn_cooldown > 0.0:
		return
	_spawn_cooldown = _spawn_queue_meta[0].x
	var enemy_id: StringName = _spawn_queue.pop_front()
	var spawn_meta: Vector3 = _spawn_queue_meta.pop_front()
	var stats: TDEnemyDefinition = _enemy_def(enemy_id)
	_instantiate_enemy(stats, spawn_meta.y, stats.bounty, PATH_POINTS[0], stats)


## Shared spawn path for wave spawns and splitter children: builds the enemy,
## wires signals, registers live count and announces the boss archetype.
func _instantiate_enemy(stats: TDEnemyDefinition, health_bonus: float,
		bounty: int, spawn_position: Vector3, source: TDEnemyDefinition) -> TDEnemy:
	var enemy := TDEnemy.new()
	enemy.setup(
		PATH_POINTS,
		stats.archetype,
		stats.base_health * (1.0 + health_bonus),
		stats.speed,
		bounty,
		stats.integrity_damage,
		stats.model_scene,
		stats.dash_walk_time,
		stats.dash_telegraph_time,
		stats.dash_time,
		stats.dash_speed_multiplier
	)
	enemy.source_definition = source
	enemy.spawn_health_bonus = health_bonus
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	_enemy_container.add_child(enemy)
	enemy.global_position = spawn_position
	_spawned_alive += 1
	if stats.archetype == TDEnemy.Archetype.WARDEN:
		_announce_boss()
		_attach_boss_aura(enemy)
	return enemy


func _clear_wave() -> void:
	is_combat = false
	# every merged wave pays its own clear bonus
	for pending_wave_number: int in _pending_wave_numbers:
		parts += WAVE_CLEAR_BONUS + INTEGRITY_BONUS * integrity
		_metrics.record(&"wave_cleared", {"wave": pending_wave_number, "integrity": integrity, "parts_after": parts})
	_waves_in_flight = 0
	_pending_wave_numbers.clear()
	# Flash save: the prep boundary is the only coherent checkpoint.
	save_session_snapshot()
	if wave_number >= WAVES.size():
		_end_run(true)
		return
	_hud.set_combat_state(false, false)
	_preview_default = _composition_text(wave_number + 1)
	_hud.show_wave_preview(_preview_default)


func _on_enemy_died(enemy: TDEnemy) -> void:
	parts += enemy.parts_bounty
	_spawned_alive = maxi(_spawned_alive - 1, 0)
	_spawn_effect(TDCombatEffect.KIND_DEATH, enemy.global_position)
	_audio.play_sfx("hit", 0.06)
	_metrics.record(&"enemy_killed", {"bounty": enemy.parts_bounty, "wave": wave_number})
	_spawn_splitter_children(enemy)
	enemy.queue_free()


## Splitter parent: on death spawns its children around the corpse. Children
## inherit the parent's wave health bonus (scaled in the definition) and the
## child definition carries its own amounts (scaled for economy fairness).
func _spawn_splitter_children(enemy: TDEnemy) -> void:
	var parent_def: TDEnemyDefinition = enemy.source_definition
	if parent_def == null or enemy.is_split_child:
		return
	if parent_def.split_count <= 0 or parent_def.split_into == &"":
		return
	if not ENEMY_DEFS.has(parent_def.split_into):
		push_warning("Splitter child id not registered: %s" % parent_def.split_into)
		return
	var child_def: TDEnemyDefinition = _enemy_def(parent_def.split_into)
	var corpse_position: Vector3 = enemy.global_position
	var count: int = parent_def.split_count
	var child_bounty: int = maxi(int(round(float(child_def.bounty) * parent_def.split_child_bounty_scale)), 1)
	for child_index: int in range(count):
		var ring_angle: float = TAU * float(child_index) / float(count)
		var offset: Vector3 = Vector3(cos(ring_angle), 0.0, sin(ring_angle)) * 0.7
		var child := _instantiate_enemy(child_def, enemy.spawn_health_bonus, child_bounty,
				corpse_position + offset, child_def)
		child.is_split_child = true
	_spawn_effect(TDCombatEffect.KIND_SPLIT, corpse_position)
	_metrics.record(&"enemy_split", {"count": count, "into": parent_def.split_into, "wave": wave_number})


## Rift-lit burst when a splitter cracks open (violet twin of KIND_DEATH).



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
	tower.setup(stats.tower_kind, stats.level_range[0], stats.level_damage[0], stats.level_fire_interval[0],
		stats.level_splash[0], stats.level_slow[0], _projectile_container, stats.model_scene)
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


## Shared upgrade math: run it on click and on restore alike — per-level stats
## all read from the definition arrays (data .tres), levels index 0..2.
func _apply_upgrade_level(tower: TDTower, stats: TDTowerDefinition, level: int) -> void:
	tower.apply_upgrade(
		stats.level_damage[level],
		stats.level_fire_interval[level],
		stats.level_range[level],
		stats.level_slow[level],
		level,
		stats.level_splash[level]
	)


## One readable telegraph for the boss spawn (docs/GDD_3DTD.md line 96).
func _announce_boss() -> void:
	_hud.announce_boss(tr("BOSS_INCOMING"))
	_audio.play_sfx("wave_horn", 0.0, 0.68)
	_spawn_effect(TDCombatEffect.KIND_WAVE, PATH_POINTS[0])
	_metrics.record(&"boss_spawned", {"wave": wave_number})
