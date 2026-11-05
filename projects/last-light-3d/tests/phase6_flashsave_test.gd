extends SceneTree

## Phase 6: Dasher dash/telegraph cycle (GDD) + flash save / session resume.
## All checks run against seams directly — no real-time waiting.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")
const TEST_SNAPSHOT_PATH := "user://phase6_snapshot_test.json"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# --- 1) Dasher dash cycle from the .tres definition --------------------
	var dasher_def := load("res://data/enemies/dasher.tres") as TDEnemyDefinition
	if not _check(dasher_def != null and dasher_def.dash_walk_time > 0.0
			and dasher_def.dash_telegraph_time > 0.0 and dasher_def.dash_time > 0.0,
			"Dasher dash cycle fields missing in dasher.tres."):
		return

	# Teleport-for-dash must preserve the archetype's base speed average:
	# distance over a full cycle = speed * (walk + M*dash)  (telegraph stops).
	var dash_distance_norm: float = dasher_def.dash_walk_time + dasher_def.dash_speed_multiplier * dasher_def.dash_time
	var plain_distance_norm: float = dasher_def.dash_walk_time + dasher_def.dash_telegraph_time + dasher_def.dash_time
	if not _check(is_equal_approx(dash_distance_norm, plain_distance_norm),
			"Dash cycle changes the Dasher's time-averaged speed (%.3f vs %.3f)." % [dash_distance_norm, plain_distance_norm]):
		return

	# One full simulated cycle by driving the enemy's own physics loop.
	var walker := TDEnemy.new()
	var path := PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -60.0)])
	walker.setup(path, TDEnemy.Archetype.DASHER, 10.0, dasher_def.speed, 5, 1, null,
		dasher_def.dash_walk_time, dasher_def.dash_telegraph_time,
		dasher_def.dash_time, dasher_def.dash_speed_multiplier)
	root.add_child(walker)
	walker.global_position = path[0]
	var cycle_time: float = walk_time_total(dasher_def)
	var steps: int = ceili(cycle_time / 0.016) + 2
	var saw_telegraph: bool = false
	for _step: int in range(steps):
		walker._physics_process(0.016)
		if walker._dash_phase == walker.DashPhase.CYCLE_TELEGRAPH:
			saw_telegraph = true
			if not _check(walker._telegraph_ring != null and walker._telegraph_ring.visible,
					"Telegraph stop did not show the telegraph ring."):
				return
		if walker._dash_phase == walker.DashPhase.CYCLE_WALK and saw_telegraph:
			# First frame back in walk = cycle boundary reached; stop simulating.
			break
	if not _check(saw_telegraph, "Dash cycle never entered the telegraph phase."):
		return
	var traveled: float = path[0].distance_to(walker.global_position)
	var expected: float = dasher_def.speed * cycle_time
	if not _check(absf(traveled - expected) < expected * 0.08,
			"Dash cycle displaced %.2f, expected ~%.2f (average speed must hold)." % [traveled, expected]):
		return
	walker.queue_free()

	# --- 2) Flash save ------------------------------------------------------
	TDSessionSnapshot.save_path = TEST_SNAPSHOT_PATH
	TDSessionSnapshot.clear()
	if not _check(not TDSessionSnapshot.has_valid_snapshot(), "Test snapshot file already existed."):
		return
	if not _check(change_scene_to_packed(RUN_SCENE) == OK, "Could not load the run scene."):
		return
	await scene_changed
	await physics_frame
	var run_a := current_scene as TDRun
	if not _check(run_a != null, "First run scene did not instantiate TDRun."):
		return

	# Fresh run drops stale snapshots; place one slot tower + one free tower.
	run_a.parts += 500  # test-only credit so placement/upgrade are affordable
	if not _check(run_a.place_tower(3, TDTower.Kind.TANGLE_EMITTER), "Slot tower placement failed."):
		return
	if not _check(run_a.place_tower_at(Vector3(5.0, 0.0, -5.0), TDTower.Kind.FIELD_TURRET), "Free tower placement failed."):
		return
	run_a.wave_number = 3  # pretend waves 1..3 cleared, next up is wave 4
	if not _check(run_a.upgrade_tower(3), "Slot tower upgrade did not succeed."):
		return
	var slot_level: int = run_a._slot_towers[3].level
	if not _check(slot_level == 1, "Upgrade did not reach level 1."):
		return
	var saved_parts: int = run_a.parts
	var saved_integrity: int = run_a.integrity
	if not _check(run_a.save_session_snapshot(), "Snapshot save returned false."):
		return
	if not _check(TDSessionSnapshot.has_valid_snapshot(), "Valid snapshot was not readable after save."):
		return

	# --- 3) Resume ----------------------------------------------------------
	TDSessionSnapshot.resume_requested = true
	if not _check(change_scene_to_packed(RUN_SCENE) == OK, "Could not reload the run scene."):
		return
	await scene_changed
	await physics_frame
	var run_b := current_scene as TDRun
	if not _check(run_b != null and run_b != run_a, "Reloading did not produce a fresh TDRun."):
		return
	if not _check(run_b._resumed, "Second run did not enter resume mode."):
		return
	if not _check(run_b.parts == saved_parts, "Resumed Parts mismatched snapshot (%d vs %d)." % [run_b.parts, saved_parts]):
		return
	if not _check(run_b.integrity == saved_integrity, "Resumed Integrity mismatched snapshot."):
		return
	if not _check(run_b.wave_number == 3, "Resumed wave number mismatched snapshot."):
		return
	var restored_slot := run_b._slot_towers[3]
	if not _check(restored_slot != null and is_instance_valid(restored_slot) and restored_slot.kind == TDTower.Kind.TANGLE_EMITTER,
			"Slot tower was not restored into slot 3."):
		return
	if not _check(restored_slot.level == slot_level,
			"Restored tower level mismatched (%d vs %d)." % [restored_slot.level, slot_level]):
		return
	if not _check(restored_slot.level == 1, "Upgrade-then-save did not persist the level."):
		return
	if not _check(run_b._free_towers.size() == 1 and run_b._free_towers[0] != null
			and run_b._free_towers[0].kind == TDTower.Kind.FIELD_TURRET
			and is_equal_approx(run_b._free_tower_positions[0].x, 5.0) and is_equal_approx(run_b._free_tower_positions[0].z, -5.0),
			"Free tower was not restored at its flash-saved ground position."):
		return

	# --- 4) HUD combat clarity ---------------------------------------------
	var hud := run_b.get_node("HUD") as TDHud
	if not _check(hud != null and hud._enemies_label != null, "Enemies-remaining HUD label missing."):
		return
	hud.set_enemies_left(0)
	if not _check(hud._enemies_label.text == "", "Idle label should be empty outside combat."):
		return
	hud.set_enemies_left(4)
	if not _check(hud._enemies_label.text.contains("4"), "Enemies-remaining label did not show the count."):
		return
	hud.announce_boss("TEST WARDEN")
	await process_frame
	if not _check(hud._boss_banner != null and hud._boss_banner.visible, "Boss announcement banner did not appear."):
		return

	TDSessionSnapshot.clear()
	print("PHASE 6 FLASHSAVE + DASHER TEST PASSED")
	call_deferred("_finish", 0)


func walk_time_total(def: TDEnemyDefinition) -> float:
	return def.dash_walk_time + def.dash_telegraph_time + def.dash_time


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 6 FLASHSAVE TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
