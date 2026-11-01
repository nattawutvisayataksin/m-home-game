extends SceneTree

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/gameplay/actors/enemies/drifter.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectiles/player_bullet.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	root.get_node("ProgressionService").call("set_test_mode", true)
	var error: Error = change_scene_to_packed(RUN_SCENE)
	if not _check(error == OK, "Could not load the run scene."):
		return
	await scene_changed
	var run := current_scene as LastLightRun
	if not _check(run != null, "Run scene did not initialize."):
		return
	var enemies: Node2D = run.get_node("Enemies")
	var projectiles: Node2D = run.get_node("Projectiles")
	for index: int in range(100):
		var enemy := ENEMY_SCENE.instantiate() as DrifterEnemy
		enemy.configure(
			Vector2(26.0 + float(index % 20) * 16.0, 100.0 + float(index % 25) * 15.0),
			100,
			0.0,
			620.0
		)
		enemies.add_child(enemy)
	for index: int in range(200):
		var projectile := PROJECTILE_SCENE.instantiate() as PlayerProjectile
		projectile.launch(Vector2(30.0 + float(index % 20) * 15.0, 520.0), 1)
		projectiles.add_child(projectile)
	if not _check(enemies.get_child_count() == 100 and projectiles.get_child_count() == 200, "Stress fixture counts did not match the target population."):
		return

	var start_usec: int = Time.get_ticks_usec()
	for _frame: int in range(60):
		await physics_frame
	var elapsed_usec: int = maxi(Time.get_ticks_usec() - start_usec, 1)
	var simulated_fps: float = 60.0 * 1000000.0 / float(elapsed_usec)
	print("PHASE 4 STRESS TEST PASSED — 100 enemies + 200 projectiles; headless tick rate %.1f (not a device benchmark)" % simulated_fps)
	call_deferred("_finish", 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 4 STRESS TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
