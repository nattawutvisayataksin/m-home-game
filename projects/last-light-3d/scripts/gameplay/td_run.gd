extends Node3D
class_name TDRun

## Greybox 3D tower-defense run: builds the scene in code, drives waves and
## economy, mediates placement. Balance numbers live in data/*.tres resources
## (enemy/tower/wave definitions); this script only wires them together.

signal run_ended(won: bool)

const HUD_SCRIPT: Script = preload("res://scripts/ui/td_hud.gd")
const METRICS_SCRIPT: Script = preload("res://scripts/systems/run_metrics.gd")
const PROFILE_SCRIPT: Script = preload("res://scripts/systems/profile_repository.gd")

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
	Vector3(-4.0, 0.0, 0.0),
	Vector3(-4.0, 0.0, -8.0),
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
var _preview_default: String = ""

var _camera: Camera3D
var _ghost: MeshInstance3D


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
	_preview_default = _composition_text(1)
	_hud.show_wave_preview(_preview_default)
	_hud.update_status(parts, integrity, 0, WAVES.size())
	_metrics.record(&"run_started", {"starting_integrity": integrity, "barricade_level": barricade_level})


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


func _build_camera_and_light() -> void:
	_camera = Camera3D.new()
	_camera.fov = 42.0
	add_child(_camera)
	_camera.look_at_from_position(Vector3(4.0, 17.0, 15.0), Vector3(0.0, 0.0, -2.0), Vector3.UP)
	_camera.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.shadow_enabled = false
	add_child(sun)


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
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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


func _composition_text(wave_index: int) -> String:
	if wave_index < 1 or wave_index > WAVES.size():
		return "-"
	var wave: TDWaveDefinition = _wave_def(wave_index)
	var labels: Array[String] = []
	for enemy_id: StringName in wave.composition.keys():
		labels.append("%s x%d" % [String(enemy_id).capitalize(), wave.composition[enemy_id]])
	return ", ".join(labels)


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
		var slot: int = _slot_from_mouse(mouse_event.position)
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if slot >= 0:
				if _slot_occupied[slot]:
					upgrade_tower(slot)
				else:
					place_tower(slot, _selected_kind)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and slot >= 0 and _slot_occupied[slot]:
			sell_tower(slot)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.physical_keycode:
			KEY_1:
				_select_kind(TDTower.Kind.FIELD_TURRET)
			KEY_2:
				_select_kind(TDTower.Kind.SONIC_RESONATOR)
			KEY_3:
				_select_kind(TDTower.Kind.TANGLE_EMITTER)
			KEY_SPACE:
				start_wave()
			KEY_ESCAPE:
				toggle_pause()


func _select_kind(kind: int) -> void:
	_selected_kind = kind
	var stats: TDTowerDefinition = _tower_def(kind)
	var ghost_cylinder := _ghost.mesh as CylinderMesh
	ghost_cylinder.top_radius = stats.range_radius
	ghost_cylinder.bottom_radius = stats.range_radius


func _slot_from_mouse(screen_position: Vector2) -> int:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return -1
	var distance_to_ground: float = (ray_origin.y) / -ray_direction.y
	if distance_to_ground < 0.0:
		return -1
	var ground_hit: Vector3 = ray_origin + ray_direction * distance_to_ground
	var best_slot: int = -1
	var best_distance: float = 1.4
	for slot_index: int in range(SLOTS.size()):
		var distance: float = Vector2(ground_hit.x, ground_hit.z).distance_to(Vector2(SLOTS[slot_index].x, SLOTS[slot_index].z))
		if distance < best_distance:
			best_distance = distance
			best_slot = slot_index
	return best_slot


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
	_slot_towers[slot_index] = tower
	_slot_occupied[slot_index] = true
	_slot_invested[slot_index] = stats.cost
	var disk := _slot_disks[slot_index] as MeshInstance3D
	var disk_material := disk.material_override as StandardMaterial3D
	disk_material.albedo_color = Color(0.35, 0.8, 0.4, 0.5)
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_metrics.record(&"tower_placed", {"kind": kind, "slot": slot_index, "parts_after": parts})
	_last_clicked_slot = slot_index
	_hovered_slot = -1
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
	_last_clicked_slot = slot_index
	return true


func _physics_process(delta: float) -> void:
	if is_over:
		return
	_update_slows()
	_update_hover()
	if is_combat:
		_spawn_tick(delta)
	_hud.update_status(parts, integrity, maxi(wave_number, 1), WAVES.size())


func _update_slows() -> void:
	for slot_index: int in range(_slot_towers.size()):
		var tower: TDTower = _slot_towers[slot_index]
		if tower == null or not is_instance_valid(tower) or tower.kind != TDTower.Kind.TANGLE_EMITTER:
			continue
		for node: Node in get_tree().get_nodes_in_group("td_enemies"):
			var enemy := node as TDEnemy
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.alive and enemy.global_position.distance_to(tower.global_position) <= tower.range_radius:
				enemy.slow_factor = minf(enemy.slow_factor, tower.slow_factor)


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
	var has_selection: bool = _hovered_slot >= 0 and not _slot_occupied[_hovered_slot]
	_ghost.visible = has_selection
	var ghost_material := _ghost.material_override as StandardMaterial3D
	var selected_stats: TDTowerDefinition = _tower_def(_selected_kind)
	if _ghost.visible:
		_ghost.global_position = SLOTS[_hovered_slot] + Vector3(0.0, 0.1, 0.0)
	var afford: bool = parts >= selected_stats.cost
	if not afford and has_selection:
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
		stats.model_scene
	)
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	_enemy_container.add_child(enemy)
	enemy.global_position = PATH_POINTS[0]
	_spawned_alive += 1


func _clear_wave() -> void:
	is_combat = false
	parts += WAVE_CLEAR_BONUS + INTEGRITY_BONUS * integrity
	_metrics.record(&"wave_cleared", {"wave": wave_number, "integrity": integrity, "parts_after": parts})
	if wave_number >= WAVES.size():
		_end_run(true)
		return
	_hud.set_combat_state(false)
	_preview_default = _composition_text(wave_number + 1)
	_hud.show_wave_preview(_preview_default)


func _on_enemy_died(enemy: TDEnemy) -> void:
	parts += enemy.parts_bounty
	_spawned_alive = maxi(_spawned_alive - 1, 0)
	_metrics.record(&"enemy_killed", {"bounty": enemy.parts_bounty, "wave": wave_number})
	enemy.queue_free()


func _on_enemy_leaked(enemy: TDEnemy) -> void:
	_spawned_alive = maxi(_spawned_alive - 1, 0)
	if is_over:
		enemy.queue_free()
		return
	integrity = maxi(integrity - enemy.integrity_damage, 0)
	_metrics.record(&"enemy_leaked", {"damage": enemy.integrity_damage, "integrity_after": integrity, "wave": wave_number})
	if integrity <= 0:
		_end_run(false)
	enemy.queue_free()


func _end_run(won: bool) -> void:
	if is_over:
		return
	is_over = true
	is_combat = false
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
