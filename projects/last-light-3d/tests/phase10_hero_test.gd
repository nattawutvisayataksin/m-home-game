extends SceneTree

## Hero feature test (approved 2026-11-09): the hero auto-deploys at run
## start, the H-toggle recalls and re-summons her, movement smooths (no
## snapping) and respects the ground bounds, the HUD control card follows the
## deployed state, and the strike seam damages an enemy through take_damage
## with the cooldown guarding repeats. No real-time waits.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")

const TEST_SNAPSHOT_PATH: String = "user://tests/phase10_snapshot.json"
const TEST_PROFILE_PATH: String = "user://tests/phase10_profile.json"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("HERO TEST FAILED: " + message)
		_failures += 1
	return condition


func _run_tests() -> void:
	TDSessionSnapshot.save_path = TEST_SNAPSHOT_PATH
	TDSessionSnapshot.clear()
	var passed: bool = await _test_all()
	_remove_test_files()
	if passed and _failures == 0:
		print("PHASE 10 HERO TEST PASSED")
		quit(0)
	else:
		quit(1)


func _test_all() -> bool:
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await physics_frame
	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return false
	run._profile_repo.save_path = TEST_PROFILE_PATH

	# Approved behavior: the hero auto-deploys with the run and her control
	# card shows in the HUD immediately.
	var auto_hero := run._hero as TDHero
	if not _check(auto_hero != null, "Hero did not auto-deploy at run start."):
		return false
	if not _check(is_instance_valid(auto_hero.definition), "Hero launched without a definition resource."):
		return false
	var hud_card := run._hud._hero_panel
	if not _check(hud_card != null and hud_card.visible, "HUD hero card missing or hidden while the hero is deployed."):
		return false

	# H recall: despawns and hides the card.
	run._toggle_hero()
	if not _check(run._hero == null, "Toggle did not recall the auto-deployed hero."):
		return false
	if not _check(not hud_card.visible, "HUD hero card stayed visible after recall."):
		return false
	# Re-summon via the same toggle (the H switch keeps working).
	run._toggle_hero()
	var hero := run._hero as TDHero
	if not _check(hero != null, "Toggle did not re-summon the hero."):
		return false
	if not _check(is_instance_valid(hero.definition), "Re-summoned hero launched without a definition resource."):
		return false
	if not _check(hud_card.visible, "HUD hero card did not reappear with the re-summoned hero."):
		return false

	# Movement: seam input east (+x). One physics frame must move less than a
	# full-speed step (the approach is smoothed, not a snap).
	hero.use_seam_input = true
	var spawn_position: Vector3 = hero.global_position
	hero.move_input = Vector2(1.0, 0.0)
	await physics_frame
	var first_step: float = hero.global_position.distance_to(spawn_position)
	if not _check(first_step > 0.001, "Hero did not move at all with input on."):
		return false
	if not _check(first_step < hero.definition.move_speed / 60.0 * 0.5, "Hero movement snapped instead of smoothing (first step %f)." % first_step):
		return false
	# ..and over a longer burst it approaches full speed (~1.2 s of stride).
	var near_position: Vector3 = hero.global_position
	for _frame: int in range(70):
		await physics_frame
	var traveled: float = hero.global_position.distance_to(near_position)
	if not _check(traveled >= hero.definition.move_speed * 0.5, "Hero never approaches full speed (traveled %f)." % traveled):
		return false
	var half: Vector2 = run.map_layout.ground_size * 0.5
	if not _check(absf(hero.global_position.x) <= half.x and absf(hero.global_position.z) <= half.y, "Hero escaped the ground bounds (x=%f z=%f)." % [hero.global_position.x, hero.global_position.z]):
		return false

	# Strike: reset the seam to standstill and face the model's home yaw (+z).
	hero.move_input = Vector2.ZERO
	hero._velocity_smooth = Vector3.ZERO
	hero._model_yaw.rotation.y = 0.0
	await physics_frame
	var drifter: TDEnemyDefinition = run._enemy_def(&"drifter")
	var enemy := run._instantiate_enemy(drifter, 0.0, drifter.bounty, hero.global_position + Vector3(0.0, 0.0, 2.0), drifter) as TDEnemy
	await physics_frame
	var health_before: float = enemy.health
	if not _check(hero.try_attack() and enemy.health < health_before, "Strike did not damage the front enemy through take_damage."):
		return false
	# Cooldown: an immediate repeat must not fire.
	if not _check(not hero.try_attack(), "Attack cooldown did not guard a repeat strike."):
		return false
	# Remove the struck enemy: it keeps walking during the cooldown frames
	# and could steal the cooled strike from the fresh frontal spawn.
	enemy.queue_free()
	# Metrics recorded the strike via the run's connected handler.
	if not _check(_has_event(run._metrics.events, "hero_strike"), "hero_strike metrics event missing."):
		return false

	# Attack cooldown spans 0.4 s: 26 physics frames later it is ready again.
	for _cooldown_frame: int in range(26):
		await physics_frame
	# Fresh frontal enemy plus a rear one: the frontal cone must keep the rear
	# safe even though it is inside the range circle too.
	var front := run._instantiate_enemy(drifter, 0.0, drifter.bounty, hero.global_position + Vector3(0.0, 0.0, 2.0), drifter) as TDEnemy
	var skitter: TDEnemyDefinition = run._enemy_def(&"skitter")
	var rear := run._instantiate_enemy(skitter, 0.0, skitter.bounty, hero.global_position + Vector3(0.0, 0.0, -2.2), skitter) as TDEnemy
	await physics_frame
	var front_health: float = front.health
	var rear_health: float = rear.health
	if not _check(hero.try_attack() and front.health < front_health, "Cooled strike did not damage the fresh frontal enemy."):
		return false
	if not _check(rear.health == rear_health, "Rear enemy took damage from a frontal-cone strike."):
		return false

	# Toggle off despawns and leaves no strays.
	run._toggle_hero()
	if not _check(run._hero == null, "Second toggle did not despawn the hero."):
		return false
	return true


func _has_event(events: Array, name: String) -> bool:
	for event: Variant in events:
		if typeof(event) == TYPE_DICTIONARY and String(event.get("type", "")) == name:
			return true
	return false


func _remove_test_files() -> void:
	for path: String in [TEST_SNAPSHOT_PATH, TEST_PROFILE_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
