extends SceneTree

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var progression_service: Node = root.get_node("ProgressionService")
	progression_service.call("set_test_mode", true)
	var scene_error: Error = change_scene_to_packed(TITLE_SCENE)
	if not _check(scene_error == OK, "Could not load title."):
		return
	await scene_changed
	var title := current_scene
	title.call("_start_mission")
	await scene_changed
	await physics_frame
	var run := current_scene as LastLightRun
	if not _check(run != null, "Run did not start."):
		return
	if not _check(run.get_node_or_null("AmbientDust") != null, "Ambient dust node missing."):
		return
	if not _check(run._hud != null, "HUD missing."):
		return

	run.elapsed_seconds = 239.9
	run._process(0.2)
	if not _check(run._warden != null and run._warden.is_boss(), "Warden did not spawn."):
		return

	# Phase 2 triggers below half health
	var half: int = int(run._warden.max_health / 2)
	run._warden.take_damage(run._warden.health - half + 1)
	await process_frame
	if not _check(run._warden._warden_phase2, "Warden did not enter phase 2."):
		return

	run._warden.take_damage(999)
	await process_frame
	if not _check(run.is_over and run.mission_won, "Defeating warden did not win."):
		return
	if not _check(run._hud._overlay.visible, "Result overlay not shown."):
		return

	print("PHASE 5 GAME FEEL TEST PASSED")
	call_deferred("_finish", 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 5 TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)