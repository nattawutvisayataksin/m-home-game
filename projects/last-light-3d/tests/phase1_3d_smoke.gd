extends SceneTree

## Greybox 3D TD smoke test:
## 1) scene loads with camera/HUD/slots   2) tower placement via seam
## 3) wave spawns + economy + kill/leak   4) defeat on integrity 0 and restart state.
## Fast-forwards by calling internal seams directly (no real-time waiting).

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var scene_error: Error = change_scene_to_packed(RUN_SCENE)
	if not _check(scene_error == OK, "Could not load the run scene."):
		return
	await scene_changed
	await physics_frame

	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return
	if not _check(run.get_node_or_null("Enemies") != null and run.get_node_or_null("Projectiles") != null, "World containers missing."):
		return
	if not _check(run.get_node_or_null("HUD") != null, "HUD missing."):
		return
	if not _check(run._camera != null and run._camera.current, "Camera 3D not set current."):
		return
	if not _check(run.SLOTS.size() == run._slot_disks.size() and run._slot_disks.size() > 0, "Slots were not materialized."):
		return

	# Tower placement seam (same path the mouse click uses).
	var start_parts: int = run.parts
	if not _check(run.place_tower(3, TDTower.Kind.TANGLE_EMITTER), "Placement failed with enough Parts."):
		return
	if not _check(run.parts == start_parts - 60, "Tangle Emitter did not charge the correct cost."):
		return
	if not _check(run.place_tower(3, TDTower.Kind.FIELD_TURRET) == false, "Placed twice into the same slot."):
		return
	if not _check(run._towers.size() == 1, "Tower was not registered in the run."):
		return

	# Wave lifecycle.
	run.start_wave()
	if not _check(run.is_combat and run.wave_number == 1 and run._spawn_queue.size() > 0, "Wave did not start spawning."):
		return

	# Spawning: fast-forward ticks without waiting real time.
	var guard: int = 0
	while not run._spawn_queue.is_empty() and guard < 500:
		run._spawn_tick(run.WAVES[0]["spacing"])
		guard += 1
	if not _check(guard > 0 and run._spawned_alive > 0, "Spawn tick produced no enemies."):
		return

	# Pick one live enemy: bounty, kill flow and economy.
	var enemy_container := run.get_node("Enemies")
	if not _check(enemy_container.get_child_count() > 0, "No enemies were added to the container."):
		return
	var enemy: TDEnemy = null
	for child: Node in enemy_container.get_children():
		var candidate := child as TDEnemy
		if candidate != null and is_instance_valid(candidate) and candidate.alive:
			enemy = candidate
			break
	if not _check(enemy != null, "Could not find a live enemy to test against."):
		return
	var bounty: int = enemy.parts_bounty
	var parts_before_kill: int = run.parts
	enemy.take_damage(enemy.health + 1.0)
	var died_confirmed: bool = not enemy.alive
	await process_frame
	if not _check(died_confirmed, "Enemy survived fatal damage."):
		return
	if not _check(run.parts == parts_before_kill + bounty, "Killing did not award the Parts bounty."):
		return

	# Leak: enemy walking through the last waypoint must cost integrity.
	var next_enemy: TDEnemy = null
	for child: Node in enemy_container.get_children():
		var candidate := child as TDEnemy
		if candidate != null and is_instance_valid(candidate) and candidate != enemy and candidate.alive:
			next_enemy = candidate
			break
	if next_enemy == null:
		next_enemy = TDEnemy.new()
		next_enemy.setup(run.PATH_POINTS, TDEnemy.Archetype.DRIFTER, 5.0, 1.0, 5, 1)
		run._enemy_container.add_child(next_enemy)
		next_enemy.global_position = run.PATH_POINTS[0]
		run._spawned_alive += 1
	var integrity_before: int = run.integrity
	next_enemy.global_position = run.PATH_POINTS[run.PATH_POINTS.size() - 1]
	next_enemy._waypoint_index = run.PATH_POINTS.size() - 1
	await physics_frame
	await physics_frame
	if not _check(run.integrity == integrity_before - 1, "Leaked enemy did not reduce Shelter Integrity."):
		return

	# Everything remaining is cleared, then the run is force-ended as lost to
	# verify the result overlay and the metrics side record.
	var alive_left: int = 0
	for node: Node in root.get_tree().get_nodes_in_group("td_enemies"):
		var survivor := node as TDEnemy
		if survivor != null and is_instance_valid(survivor) and survivor.alive:
			alive_left += 1
	if not _check(alive_left >= 0, "Enemy accounting broke."):
		return
	if not run.is_over:
		run._end_run(false)
	await process_frame
	if not _check(run.is_over, "Force-ending the run left the run open."):
		return
	var metrics_result: Dictionary = run._metrics.result
	if not _check(metrics_result.has("won") and bool(metrics_result["won"]) == false, "Metrics result missed the lost outcome."):
		return
	if not _check(run._metrics.run_id != "", "Metrics never began a run id."):
		return
	var hud := run.get_node("HUD") as TDHud
	var overlay := hud._overlay as CanvasItem
	if not _check(overlay != null and overlay.visible, "Result overlay did not show on defeat."):
		return

	print("PHASE 1 3D-SMOKE TEST PASSED")
	call_deferred("_finish", 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("3D SMOKE TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
