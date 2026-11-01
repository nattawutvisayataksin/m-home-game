extends Node2D
class_name LastLightRun

signal integrity_changed(value: int)
signal resonance_changed(value: int)
signal weapon_changed(level: int)
signal run_ended

const PLAYER_SCENE: PackedScene = preload("res://scenes/gameplay/actors/player.tscn")
const MISSION: MissionDefinition = preload("res://data/missions/beacon_09.tres")
const WEAPON: WeaponDefinition = preload("res://data/weapons/beacon_cannon.tres")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectiles/player_bullet.tscn")
const HUD_SCRIPT: Script = preload("res://scripts/ui/hud.gd")
const EFFECT_SCRIPT: Script = preload("res://scripts/gameplay/combat_effect.gd")
const AUDIO_DIRECTOR_SCRIPT: Script = preload("res://scripts/systems/audio_director.gd")

const FIELD_LEFT: float = 26.0
const FIELD_RIGHT: float = 334.0
const SPAWN_Y: float = 86.0
const BREACH_Y: float = 530.0
const RESONANCE_REQUIRED: int = 100
const LANES: Array[float] = [66.0, 123.0, 180.0, 237.0, 294.0]

var integrity: int = MISSION.starting_integrity
var resonance: int = 0
var wave: int = 1
var elapsed_seconds: float = 0.0
var is_over: bool = false
var is_paused: bool = false
var mission_won: bool = false
var enemies_defeated: int = 0
var breaches: int = 0

var _player: FieldSurvivor
var _hud: RunHud
var _enemy_container: Node2D
var _projectile_container: Node2D
var _effects_container: Node2D
var _audio: RunAudioDirector
var _spawn_timer: Timer
var _warden: DrifterEnemy
var _spawn_index: int = 0
var _last_displayed_second: int = -1
var _reduce_flashes: bool = false
var _reduce_motion: bool = false
var _barricade_level: int = 0
var _save_error_message: String = ""
var _rng := RandomNumberGenerator.new()
var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _low_health_warned: bool = false


func _ready() -> void:
	var profile: Dictionary = get_node("/root/ProgressionService").call("get_profile")
	_barricade_level = int(profile.get("barricade_level", 0))
	integrity = MISSION.starting_integrity + _barricade_level
	_configure_input_actions()
	_rng.randomize()
	_load_accessibility_settings()
	_create_world_containers()
	_create_audio()
	_create_player()
	_create_hud()
	_create_timers()
	_publish_status()
	queue_redraw()


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - delta, 0.0)
		var amt: float = _shake_strength * (_shake_time / 0.35)
		var ox: float = _rng.randf_range(-amt, amt)
		var oy: float = _rng.randf_range(-amt, amt)
		if _enemy_container != null:
			_enemy_container.position = Vector2(ox, oy)
		if _projectile_container != null:
			_projectile_container.position = Vector2(ox * 0.6, oy * 0.6)
		if _effects_container != null:
			_effects_container.position = Vector2(ox * 0.8, oy * 0.8)
		if _shake_time <= 0.0:
			if _enemy_container != null:
				_enemy_container.position = Vector2.ZERO
			if _projectile_container != null:
				_projectile_container.position = Vector2.ZERO
			if _effects_container != null:
				_effects_container.position = Vector2.ZERO
	if is_over or is_paused:
		return
	elapsed_seconds += delta
	var current_wave: int = mini(int(elapsed_seconds / float(MISSION.wave_duration_seconds)) + 1, MISSION.duration_seconds / MISSION.wave_duration_seconds)
	if current_wave != wave:
		wave = current_wave
		_publish_status()
	var remaining: int = maxi(MISSION.duration_seconds - int(elapsed_seconds), 0)
	if remaining != _last_displayed_second:
		_last_displayed_second = remaining
		_publish_status()
	if elapsed_seconds >= MISSION.boss_start_seconds and _warden == null:
		_spawn_warden()
	if elapsed_seconds >= MISSION.duration_seconds:
		_end_run(false)


func _unhandled_input(event: InputEvent) -> void:
	if is_over or is_paused:
		return
	if event.is_action_pressed("activate_pulse"):
		activate_pulse()
	elif event.is_action_pressed("upgrade_weapon"):
		upgrade_weapon()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not is_over and not is_paused:
		_pause_run()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 360.0, 640.0), Color("#202722"))
	draw_rect(Rect2(38.0, 76.0, 284.0, 454.0), Color("#343a32"))
	draw_rect(Rect2(42.0, 76.0, 276.0, 454.0), Color("#3d4036"), false, 2.0)
	for i: int in range(7):
		var y: float = 112.0 + float(i) * 58.0
		draw_line(Vector2(48.0, y), Vector2(312.0, y), Color(0.16, 0.19, 0.16, 0.32), 1.0)
	for i: int in range(12):
		var x: float = float((i * 83 + 29) % 360)
		var y: float = float((i * 137 + 41) % 520)
		draw_rect(Rect2(x, y, 3.0, 2.0), Color(0.65, 0.58, 0.42, 0.25))
	draw_rect(Rect2(18.0, 480.0, 324.0, 50.0), Color("#5b513c"))
	for layer: int in range(_barricade_level + 1):
		var barricade_y: float = 516.0 - float(layer) * 9.0
		draw_rect(Rect2(28.0, barricade_y, 304.0, 8.0), Color("#756545"))
		for bag: int in range(8):
			var bag_x: float = 31.0 + float(bag) * 42.0
			draw_rect(Rect2(bag_x, barricade_y + 1.0, 37.0, 6.0), Color("#a28a5e"), false, 1.0)
	draw_line(Vector2(18.0, BREACH_Y), Vector2(342.0, BREACH_Y), Color("#d6a453"), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(24.0, BREACH_Y - 9.0), "SHELTER DEFENSE LINE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#e8c27d"))
	for lane_x: float in LANES:
		draw_line(Vector2(lane_x, 82.0), Vector2(lane_x, BREACH_Y - 2.0), Color(0.76, 0.68, 0.49, 0.10), 1.0)


func activate_pulse() -> bool:
	if is_over or resonance < RESONANCE_REQUIRED:
		return false
	resonance -= RESONANCE_REQUIRED
	_audio.play_sfx("pulse")
	_spawn_pulse_effect()
	for node: Node in get_tree().get_nodes_in_group("last_light_enemies"):
		var enemy := node as DrifterEnemy
		if is_instance_valid(enemy) and enemy.global_position.y >= 300.0:
			enemy.take_damage(999, false)
	_publish_status()
	return true


func upgrade_weapon() -> bool:
	if is_over or resonance < RESONANCE_REQUIRED or _player == null:
		return false
	if not _player.apply_weapon_upgrade():
		_publish_status()
		return false
	resonance -= RESONANCE_REQUIRED
	_audio.play_sfx("upgrade")
	_spawn_upgrade_burst(_player.global_position + Vector2.UP * 8.0)
	weapon_changed.emit(_player.weapon_level)
	_publish_status()
	return true


func restart_run() -> void:
	get_tree().reload_current_scene()


func _configure_input_actions() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("activate_pulse", KEY_SPACE)
	_add_key_action("upgrade_weapon", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)


func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)


func _create_world_containers() -> void:
	_enemy_container = Node2D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)
	_projectile_container = Node2D.new()
	_projectile_container.name = "Projectiles"
	add_child(_projectile_container)
	_effects_container = Node2D.new()
	_effects_container.name = "Effects"
	add_child(_effects_container)
	_create_ambient_dust()


func _create_ambient_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.name = "AmbientDust"
	dust.amount = 26
	dust.lifetime = 6.0
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(140.0, 200.0)
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = 25.0
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 18.0
	dust.gravity = Vector2(0.0, -2.0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	dust.color = Color(0.65, 0.58, 0.42, 0.18)
	dust.z_index = -1
	dust.position = Vector2(180.0, 320.0)
	add_child(dust)


func _create_audio() -> void:
	var audio_node := Node.new()
	audio_node.set_script(AUDIO_DIRECTOR_SCRIPT)
	audio_node.name = "AudioDirector"
	_audio = audio_node as RunAudioDirector
	if _audio == null:
		push_error("Failed to instantiate the run audio director.")
		return
	add_child(audio_node)


func _create_player() -> void:
	_player = PLAYER_SCENE.instantiate() as FieldSurvivor
	_player.name = "Player"
	_player.configure(Vector2(FIELD_LEFT, FIELD_RIGHT), Vector2(180.0, 500.0))
	_player.configure_weapon(WEAPON)
	_player.shot_requested.connect(_on_shot_requested)
	add_child(_player)


func _create_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.set_script(HUD_SCRIPT)
	hud_layer.name = "HUD"
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = hud_layer as RunHud
	if _hud == null:
		push_error("Failed to instantiate the run HUD script.")
		return
	_hud.pulse_pressed.connect(activate_pulse)
	_hud.overclock_pressed.connect(upgrade_weapon)
	_hud.restart_pressed.connect(restart_run)
	_hud.pause_pressed.connect(_pause_run)
	_hud.resume_pressed.connect(_resume_run)
	_hud.title_pressed.connect(_return_to_title)
	_hud.move_axis_changed.connect(_player.set_touch_axis)
	get_node("/root/ProgressionService").connect("save_failed", _on_save_failed)
	add_child(hud_layer)


func _create_timers() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = MISSION.starting_spawn_interval
	_spawn_timer.timeout.connect(_spawn_enemy)
	add_child(_spawn_timer)
	_spawn_timer.start()


func _spawn_enemy() -> void:
	if is_over or is_paused or elapsed_seconds >= MISSION.boss_start_seconds:
		return
	var wave_definition: WaveDefinition = MISSION.get_wave_definition(wave)
	var eligible_ids: Array[StringName] = wave_definition.available_enemy_ids if wave_definition != null else [&"drifter"]
	var eligible_enemies: Array[EnemyDefinition] = []
	for candidate: EnemyDefinition in MISSION.enemy_roster:
		if eligible_ids.has(candidate.enemy_id) and wave >= candidate.minimum_wave:
			eligible_enemies.append(candidate)
	if eligible_enemies.is_empty():
		push_error("Mission %s has no eligible enemy for wave %d." % [MISSION.mission_id, wave])
		return
	var definition: EnemyDefinition = eligible_enemies[_spawn_index % eligible_enemies.size()]
	if definition.scene == null:
		push_error("Enemy definition %s has no scene." % definition.enemy_id)
		return
	var enemy := definition.scene.instantiate() as DrifterEnemy
	if enemy == null:
		push_error("Enemy scene %s does not use DrifterEnemy." % definition.enemy_id)
		return
	enemy.name = "%s_%03d" % [String(definition.enemy_id).capitalize(), _spawn_index]
	var lane_x: float = LANES[_spawn_index % LANES.size()]
	var jitter: float = _rng.randf_range(-8.0, 8.0)
	var health_bonus: int = wave_definition.enemy_health_bonus if wave_definition != null else int((wave - 1) / 2)
	var speed_bonus: float = wave_definition.enemy_speed_bonus if wave_definition != null else minf(float(wave - 1) * 2.0, 17.0)
	var enemy_health: int = definition.health + health_bonus
	var speed: float = definition.descent_speed + speed_bonus
	enemy.configure(
		Vector2(clampf(lane_x + jitter, FIELD_LEFT, FIELD_RIGHT), SPAWN_Y),
		enemy_health,
		speed,
		BREACH_Y,
		definition.archetype,
		Vector2(FIELD_LEFT, FIELD_RIGHT),
		definition.resonance_reward
	)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy.breached.connect(_on_enemy_breached)
	enemy.struck.connect(_spawn_hit_effect)
	enemy.struck.connect(_on_enemy_struck)
	_enemy_container.add_child(enemy)
	_spawn_index += 1
	_spawn_timer.wait_time = MISSION.get_spawn_interval(wave)


func _spawn_warden() -> void:
	if is_over or _warden != null:
		return
	_spawn_timer.stop()
	var boss_definition: EnemyDefinition = MISSION.boss_definition
	if boss_definition == null or boss_definition.scene == null:
		push_error("Mission %s has no configured boss definition." % MISSION.mission_id)
		return
	_warden = boss_definition.scene.instantiate() as DrifterEnemy
	if _warden == null:
		push_error("Configured boss scene does not use DrifterEnemy.")
		return
	_warden.name = "RiftWarden"
	_warden.configure(
		Vector2(180.0, 170.0),
		boss_definition.health,
		boss_definition.descent_speed,
		BREACH_Y,
		boss_definition.archetype,
		Vector2(FIELD_LEFT, FIELD_RIGHT),
		boss_definition.resonance_reward
	)
	_warden.defeated.connect(_on_enemy_defeated)
	_warden.destroyed.connect(_on_enemy_destroyed)
	_warden.breached.connect(_on_enemy_breached)
	_warden.struck.connect(_spawn_hit_effect)
	_warden.struck.connect(_on_enemy_struck)
	_warden.boss_warning.connect(_on_boss_warning)
	_warden.boss_attack.connect(_on_boss_attack)
	_warden.boss_defeated.connect(_on_warden_defeated)
	_warden.health_changed.connect(_hud.update_boss_health)
	_enemy_container.add_child(_warden)
	_audio.play_sfx("boss")
	_audio.intensify()
	_hud.show_boss_health(_warden.max_health)


func _on_shot_requested(origin: Vector2, damage: int) -> void:
	if is_over:
		return
	_audio.play_sfx("shot")
	_spawn_muzzle_flash(origin)
	var projectile := PROJECTILE_SCENE.instantiate() as PlayerProjectile
	projectile.launch(origin, damage)
	_projectile_container.add_child(projectile)


func _on_enemy_defeated(charge_reward: int) -> void:
	if is_over:
		return
	enemies_defeated += 1
	_hud.update_kills(enemies_defeated)
	var previous_resonance: int = resonance
	resonance = mini(resonance + charge_reward, RESONANCE_REQUIRED)
	if previous_resonance < RESONANCE_REQUIRED and resonance >= RESONANCE_REQUIRED:
		_audio.play_sfx("charge")
		_spawn_upgrade_burst(_player.global_position + Vector2(0.0, -12.0))
	resonance_changed.emit(resonance)
	_publish_status()


func _on_warden_defeated() -> void:
	if is_over:
		return
	_spawn_pulse_effect()
	if _warden != null:
		_spawn_effect(_warden.global_position, 5)
		_spawn_effect(_warden.global_position, 3)
	_trigger_shake(0.5)
	_end_run(true)


func _on_enemy_breached(integrity_damage: int) -> void:
	if is_over:
		return
	breaches += 1
	_audio.play_sfx("breach")
	_spawn_breach_flash()
	_trigger_shake(0.35)
	integrity = maxi(integrity - integrity_damage, 0)
	integrity_changed.emit(integrity)
	if integrity <= 2 and not _low_health_warned and integrity > 0:
		_low_health_warned = true
		_audio.play_sfx("warning")
		_trigger_shake(0.2)
	_publish_status()
	if integrity <= 0:
		_end_run(false)


func _on_boss_warning(target_x: float) -> void:
	if _warden == null or target_x < 0.0:
		return
	_warden.set_attack_target(_player.global_position.x)
	_audio.play_sfx("warning")
	_spawn_warning_effect(_player.global_position.x)


func _on_boss_attack(target_x: float) -> void:
	_trigger_shake(0.25)
	if absf(_player.global_position.x - target_x) <= 32.0:
		_on_enemy_breached(1)


func _on_enemy_struck(_at: Vector2) -> void:
	_audio.play_sfx("hit")


func _on_save_failed(message: String) -> void:
	_save_error_message = message


func _spawn_hit_effect(at: Vector2) -> void:
	_spawn_effect(at, 0)


func _on_enemy_destroyed(at: Vector2, color: Color) -> void:
	_audio.play_sfx("death")
	if _reduce_flashes:
		return
	var effect := Node2D.new()
	effect.set_script(EFFECT_SCRIPT)
	effect.global_position = at
	effect.set("effect_kind", 3)
	effect.set_meta("burst_color", color)
	_effects_container.add_child(effect)


func _spawn_muzzle_flash(at: Vector2) -> void:
	_spawn_effect(at, 4)


func _spawn_upgrade_burst(at: Vector2) -> void:
	_spawn_effect(at, 5)


func _spawn_breach_flash() -> void:
	_spawn_effect(Vector2(180.0, BREACH_Y), 6)


func _trigger_shake(duration: float) -> void:
	if _reduce_flashes or _reduce_motion:
		return
	_shake_time = duration
	_shake_strength = 6.0


func _spawn_pulse_effect() -> void:
	_spawn_effect(_player.global_position, 1)


func _spawn_warning_effect(at_x: float) -> void:
	_spawn_effect(Vector2(at_x, 500.0), 2)


func _spawn_effect(at: Vector2, kind: int) -> void:
	if _reduce_flashes and kind != 2:
		return
	var effect := Node2D.new()
	effect.set_script(EFFECT_SCRIPT)
	effect.global_position = at
	effect.set("effect_kind", kind)
	if kind == 2:
		effect.set_meta("reduce_flashes", _reduce_flashes)
	_effects_container.add_child(effect)


func _publish_status() -> void:
	if _hud == null or _player == null:
		return
	integrity_changed.emit(integrity)
	resonance_changed.emit(resonance)
	weapon_changed.emit(_player.weapon_level)
	var remaining: int = maxi(MISSION.duration_seconds - int(elapsed_seconds), 0)
	_hud.update_status(integrity, resonance, _player.weapon_level, wave, _player.weapon_level < WEAPON.get_max_level(), remaining)


func _pause_run() -> void:
	if is_over or is_paused:
		return
	_shake_time = 0.0
	if _enemy_container != null:
		_enemy_container.position = Vector2.ZERO
	if _projectile_container != null:
		_projectile_container.position = Vector2.ZERO
	if _effects_container != null:
		_effects_container.position = Vector2.ZERO
	is_paused = true
	_spawn_timer.paused = true
	get_tree().paused = true
	_hud.show_pause()


func _resume_run() -> void:
	if not is_paused:
		return
	get_tree().paused = false
	is_paused = false
	_spawn_timer.paused = false
	_hud.hide_overlay()


func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


func _load_accessibility_settings() -> void:
	var settings := ConfigFile.new()
	var error: Error = settings.load("user://settings.cfg")
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load accessibility settings: %s" % error_string(error))
	_reduce_flashes = bool(settings.get_value("accessibility", "reduce_flashes", false))
	_reduce_motion = bool(settings.get_value("accessibility", "reduce_motion", false))


func _end_run(won: bool) -> void:
	if is_over:
		return
	is_over = true
	_shake_time = 0.0
	if _enemy_container != null:
		_enemy_container.position = Vector2.ZERO
	if _projectile_container != null:
		_projectile_container.position = Vector2.ZERO
	if _effects_container != null:
		_effects_container.position = Vector2.ZERO
	mission_won = won
	_spawn_timer.stop()
	_player.set_active(false)
	for node: Node in get_tree().get_nodes_in_group("last_light_enemies"):
		if node.has_method("deactivate"):
			node.call("deactivate")
	var progression_service: Node = get_node("/root/ProgressionService")
	var salvage_earned: int = int(progression_service.call("record_run",
		won,
		enemies_defeated,
		breaches,
		integrity,
		wave,
		int(elapsed_seconds)
	))
	_hud.show_result(won, salvage_earned, progression_service.call("get_profile"), enemies_defeated, breaches, wave, int(elapsed_seconds))
	if not _save_error_message.is_empty():
		_hud.show_save_error(_save_error_message)
	run_ended.emit()
