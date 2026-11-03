extends Node3D
class_name TDRun

## Greybox 3D tower-defense run: builds the scene in code, drives waves and
## economy, mediates placement. Data constants live at the top in ONE place so
## they can be moved into .tres resources at the vertical-slice phase.

signal run_ended(won: bool)

const HUD_SCRIPT: Script = preload("res://scripts/ui/td_hud.gd")
const METRICS_SCRIPT: Script = preload("res://scripts/systems/run_metrics.gd")
const ENEMY_SCRIPT: Script = preload("res://scripts/actors/td_enemy.gd")
const TOWER_SCRIPT: Script = preload("res://scripts/actors/td_tower.gd")

# --- Greybox balance data (source of truth until .tres migration) ---
const START_PARTS: int = 120
const START_INTEGRITY: int = 10
const WAVE_CLEAR_BONUS: int = 20
const INTEGRITY_BONUS: int = 5

const ENEMY_STATS: Dictionary = {
	&"drifter": {"health": 40.0, "speed": 1.6, "bounty": 12, "damage": 1, "archetype": 0},
	&"skitter": {"health": 20.0, "speed": 2.8, "bounty": 8, "damage": 1, "archetype": 1},
	&"dasher": {"health": 30.0, "speed": 1.3, "bounty": 15, "damage": 1, "archetype": 2},
	&"warden": {"health": 900.0, "speed": 0.8, "bounty": 300, "damage": 3, "archetype": 3},
}

const TOWER_STATS: Dictionary = {
	TDTower.Kind.FIELD_TURRET: {"cost": 80, "range": 5.5, "damage": 6.0, "interval": 0.45, "splash": 0.0, "slow": 1.0},
	TDTower.Kind.SONIC_RESONATOR: {"cost": 120, "range": 6.0, "damage": 10.0, "interval": 1.8, "splash": 2.8, "slow": 1.0},
	TDTower.Kind.TANGLE_EMITTER: {"cost": 60, "range": 4.0, "damage": 0.0, "interval": 0.0, "splash": 0.0, "slow": 0.7},
}

const WAVES: Array[Dictionary] = [
	{"composition": {&"drifter": 6}, "spacing": 1.0, "hp_bonus": 0.0},
	{"composition": {&"drifter": 6, &"skitter": 4}, "spacing": 0.8, "hp_bonus": 0.15},
	{"composition": {&"drifter": 8, &"skitter": 6}, "spacing": 0.7, "hp_bonus": 0.30},
	{"composition": {&"dasher": 4, &"drifter": 6}, "spacing": 0.7, "hp_bonus": 0.45},
	{"composition": {&"skitter": 12, &"drifter": 4}, "spacing": 0.5, "hp_bonus": 0.60},
	{"composition": {&"dasher": 6, &"skitter": 6, &"drifter": 6}, "spacing": 0.6, "hp_bonus": 0.75},
	{"composition": {&"drifter": 12, &"dasher": 4, &"skitter": 8}, "spacing": 0.5, "hp_bonus": 0.90},
	{"composition": {&"warden": 1, &"drifter": 8}, "spacing": 1.6, "hp_bonus": 1.10},
]

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
var _towers: Array[TDTower] = []
var _slot_disks: Array[MeshInstance3D] = []
var _slot_occupied: Array[bool] = []
var _selected_kind: int = TDTower.Kind.FIELD_TURRET
var _hovered_slot: int = -1
var _last_clicked_slot: int = -1  # test seam; set by place handlers
var _spawn_queue: Array[StringName] = []
var _spawn_cooldown: float = 0.0
var _spawn_spacing: float = 1.0
var _spawned_alive: int = 0
var _metrics: RunMetrics

var _camera: Camera3D
var _ghost: MeshInstance3D


func _ready() -> void:
	_metrics = METRICS_SCRIPT.new()
	_metrics.begin()
	_build_world()
	_build_camera_and_light()
	_build_env()
	_build_hud()
	_hud.show_wave_preview(_composition_text(1))
	_hud.update_status(parts, integrity, 0, WAVES.size())
	_metrics.record(&"run_started", {"starting_integrity": integrity})


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

	# the Shelter 09 blockhouse at path end, vertically oriented
	var shelter := MeshInstance3D.new()
	var shelter_box := BoxMesh.new()
	shelter_box.size = Vector3(3.0, 2.2, 2.2)
	shelter.mesh = shelter_box
	var shelter_material := StandardMaterial3D.new()
	shelter_material.albedo_color = Color("#6e5c40")
	shelter.material_override = shelter_material
	shelter.position = PATH_POINTS[PATH_POINTS.size() - 1] + Vector3(2.4, 1.1, 0.0)
	shelter.name = "Shelter"
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
		disk.set_meta("slot_index", slot_index)


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
	var selected_stats: Dictionary = TOWER_STATS[_selected_kind]
	var ghost_cylinder := CylinderMesh.new()
	ghost_cylinder.top_radius = selected_stats["range"]
	ghost_cylinder.bottom_radius = selected_stats["range"]
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
	var composition: Dictionary = WAVES[wave_index - 1]["composition"]
	var labels: Array[String] = []
	for enemy_id: StringName in composition.keys():
		labels.append("%s x%d" % [String(enemy_id).capitalize(), composition[enemy_id]])
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


func _on_tower_selected(kind: int) -> void:
	_select_kind(kind)


# --- Input & placement -------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var slot: int = _slot_from_mouse(event.position)
		if slot >= 0 and not _slot_occupied[slot]:
			place_tower(slot, _selected_kind)
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
				pass  # pause arrives after the vertical-slice gate


func _select_kind(kind: int) -> void:
	_selected_kind = kind
	var stats: Dictionary = TOWER_STATS[kind]
	var ghost_cylinder := _ghost.mesh as CylinderMesh
	ghost_cylinder.top_radius = stats["range"]
	ghost_cylinder.bottom_radius = stats["range"]


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
	var stats: Dictionary = TOWER_STATS[kind]
	if parts < int(stats["cost"]):
		return false
	parts -= int(stats["cost"])
	_slot_occupied[slot_index] = true
	var tower := TDTower.new()
	tower.setup(
		kind,
		stats["range"],
		stats["damage"],
		stats["interval"],
		stats["splash"],
		stats["slow"],
		_projectile_container
	)
	add_child(tower)
	tower.global_position = SLOTS[slot_index]
	_towers.append(tower)
	var disk := _slot_disks[slot_index] as MeshInstance3D
	var disk_material := disk.material_override as StandardMaterial3D
	disk_material.albedo_color = Color(0.35, 0.8, 0.4, 0.5)
	_hud.update_status(parts, integrity, wave_number, WAVES.size())
	_metrics.record(&"tower_placed", {"kind": kind, "slot": slot_index, "parts_after": parts})
	_last_clicked_slot = slot_index
	_hovered_slot = -1
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
	for node: Node in get_tree().get_nodes_in_group("td_enemies"):
		var enemy := node as TDEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.slow_factor = 1.0
		for tower: TDTower in _towers:
			if tower.kind == TDTower.Kind.TANGLE_EMITTER and enemy.alive:
				if enemy.global_position.distance_to(tower.global_position) <= tower.range_radius:
					enemy.slow_factor = minf(enemy.slow_factor, tower.slow_factor)


func _update_hover() -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var slot: int = _slot_from_mouse(mouse_position)
	if slot != _hovered_slot:
		_hovered_slot = slot
	var has_selection: bool = _hovered_slot >= 0 and not _slot_occupied[_hovered_slot]
	_ghost.visible = has_selection
	var ghost_material := _ghost.material_override as StandardMaterial3D
	var selected_stats: Dictionary = TOWER_STATS[_selected_kind]
	if _ghost.visible:
		_ghost.global_position = SLOTS[_hovered_slot] + Vector3(0.0, 0.1, 0.0)
	var afford: bool = parts >= int(selected_stats["cost"])
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
	var wave: Dictionary = WAVES[wave_number - 1]
	_spawn_spacing = float(wave["spacing"])
	_spawn_queue.clear()
	var composition: Dictionary = wave["composition"]
	for enemy_id: StringName in composition.keys():
		var count: int = int(composition[enemy_id])
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
	var stats: Dictionary = ENEMY_STATS[enemy_id]
	var bonus: float = float(WAVES[wave_number - 1]["hp_bonus"])
	var enemy := TDEnemy.new()
	var archetype: TDEnemy.Archetype = stats["archetype"]
	enemy.setup(
		PATH_POINTS,
		archetype,
		stats["health"] * (1.0 + bonus),
		stats["speed"],
		int(stats["bounty"]),
		int(stats["damage"])
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
	_hud.show_wave_preview(_composition_text(wave_number + 1))


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
		"towers": _towers.size(),
	})
	_metrics.save_file()
	_hud.show_result(won, parts)
	run_ended.emit(won)


func _restart() -> void:
	get_tree().reload_current_scene()
