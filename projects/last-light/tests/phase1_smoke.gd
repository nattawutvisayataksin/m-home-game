extends SceneTree

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/gameplay/actors/enemies/drifter.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")
const WEAPON: WeaponDefinition = preload("res://data/weapons/beacon_cannon.tres")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var progression_service: Node = root.get_node("ProgressionService")
	progression_service.call("set_test_mode", true)
	var test_profile: Dictionary = progression_service.call("get_profile")
	test_profile["salvage"] = 100
	progression_service.call("set_test_profile", test_profile)
	if not _check(progression_service.call("get_barricade_upgrade_cost") == 30, "First base upgrade has the wrong cost."):
		return
	if not _check(progression_service.call("upgrade_barricade"), "Could not buy the first barricade upgrade with enough Salvage."):
		return
	if not _check(progression_service.call("get_barricade_upgrade_cost") == 70, "Second base upgrade has the wrong cost."):
		return
	if not _check(progression_service.call("upgrade_barricade"), "Could not buy the second barricade upgrade with enough Salvage."):
		return
	if not _check(progression_service.call("get_barricade_upgrade_cost") == 0 and not progression_service.call("upgrade_barricade"), "Barricade upgrades did not stop at the cap."):
		return
	var scene_error: Error = change_scene_to_packed(TITLE_SCENE)
	if not _check(scene_error == OK, "Could not load the title screen."):
		return
	await scene_changed
	var title := current_scene
	if not _check(title != null and title.get_script() != null, "Title screen did not initialize."):
		return
	TranslationServer.set_locale("en")
	if not _check(TranslationServer.translate(&"START_MISSION") == "START MISSION", "English translation table did not load."):
		return
	TranslationServer.set_locale("th")
	if not _check(TranslationServer.translate(&"START_MISSION") == "เริ่มภารกิจ", "Thai translation table did not load."):
		return
	TranslationServer.set_locale("en")
	title.call("_start_mission")
	await scene_changed
	await physics_frame

	var run := current_scene as LastLightRun
	if not _check(run != null, "Title screen did not launch the run scene."):
		return
	var expected_integrity: int = 5 + int(get_root().get_node("ProgressionService").call("get_profile").get("barricade_level", 0))
	if not _check(run.integrity == expected_integrity and run.resonance == 0 and not run.is_over, "Run did not start with clean state."):
		return

	var player := run.get_node("Player") as FieldSurvivor
	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	for _frame: int in range(12):
		await physics_frame
	Input.action_release("move_right")
	if not _check(player.global_position.x > start_x + 20.0, "Player did not move right from the named input action."):
		return
	if not _check(player.shots_fired > 0, "Auto-fire did not produce any shots."):
		return

	var target := ENEMY_SCENE.instantiate() as DrifterEnemy
	target.configure(Vector2(player.global_position.x, 380.0), 1, 0.0, 530.0)
	run.get_node("Enemies").add_child(target)
	target.defeated.connect(run._on_enemy_defeated)
	for _frame: int in range(80):
		await physics_frame
		if not is_instance_valid(target):
			break
	if not _check(not is_instance_valid(target), "Player projectile did not defeat the aligned enemy."):
		return
	if not _check(run.enemies_defeated == 1 and run.resonance == 25, "Enemy defeat did not award the expected Parts."):
		return

	run.resonance = 100
	if not _check(run.upgrade_weapon(), "Weapon Upgrade was unavailable with full Parts."):
		return
	if not _check(player.weapon_level == 2 and run.resonance == 0, "Weapon Upgrade did not upgrade the weapon and consume Parts."):
		return
	while player.weapon_level < WEAPON.get_max_level():
		run.resonance = 100
		if not _check(run.upgrade_weapon(), "Could not continue upgrading the weapon during the run."):
			return
	if not _check(player.weapon_damage == 6 and is_equal_approx(player.fire_interval, 0.20), "Weapon upgrade levels did not reach the expected combat stats."):
		return

	var pulse_target := ENEMY_SCENE.instantiate() as DrifterEnemy
	pulse_target.configure(Vector2(180.0, 420.0), 1, 0.0, 530.0)
	run.get_node("Enemies").add_child(pulse_target)
	pulse_target.defeated.connect(run._on_enemy_defeated)
	run.resonance = 100
	if not _check(run.activate_pulse(), "Emergency Blast was unavailable with full Parts."):
		return
	await process_frame
	if not _check(not is_instance_valid(pulse_target), "Emergency Blast did not clear a nearby enemy."):
		return
	if not _check(run.resonance == 0, "Enemies cleared by Emergency Blast incorrectly refunded Parts."):
		return

	run._on_enemy_breached(run.integrity)
	if not _check(run.is_over and run.integrity == 0, "Shelter defeat did not end the run."):
		return
	run.restart_run()
	await scene_changed
	var restarted := current_scene as LastLightRun
	if not _check(restarted != null and restarted.integrity == expected_integrity and restarted.resonance == 0 and not restarted.is_over, "Restart did not reset the run."):
		return
	restarted._pause_run()
	if not _check(restarted.is_paused and paused, "Pause overlay did not pause the game."):
		return
	restarted._resume_run()
	if not _check(not restarted.is_paused and not paused, "Resume did not unpause the game."):
		return
	restarted.elapsed_seconds = 239.9
	restarted._process(0.2)
	if not _check(restarted._warden != null and restarted._warden.is_boss(), "Rift Warden did not spawn at the boss phase."):
		return
	var boss_lane: float = 66.0
	restarted._player.global_position.x = boss_lane
	restarted._on_boss_warning(180.0)
	var effects: Node2D = restarted.get_node("Effects")
	if not _check(effects.get_child_count() > 0, "Boss warning did not show a lane telegraph."):
		return
	var lane_telegraph := effects.get_child(0) as Node2D
	if not _check(is_equal_approx(lane_telegraph.global_position.x, boss_lane), "Boss telegraph did not mark the targeted lane."):
		return
	restarted._player.global_position.x = 180.0
	restarted._on_boss_attack(boss_lane)
	if not _check(restarted.integrity == expected_integrity, "Boss attack hit after the player left the warned lane."):
		return
	restarted._player.global_position.x = boss_lane
	restarted._on_boss_attack(boss_lane)
	if not _check(restarted.integrity == expected_integrity - 1, "Boss attack did not hit the player inside the warned lane."):
		return
	restarted._warden.take_damage(999)
	if not _check(restarted.is_over and restarted.mission_won, "Defeating the Rift Warden did not complete the mission."):
		return

	print("PHASE 1 + VERTICAL SLICE SMOKE TEST PASSED")
	call_deferred("_finish", 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 1 SMOKE TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
