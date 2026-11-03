extends SceneTree

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var progression_service: Node = root.get_node("ProgressionService")
	progression_service.call("set_test_mode", true)
	var scene_error: Error = change_scene_to_packed(TITLE_SCENE)
	if not _check(scene_error == OK, "Could not load the title screen."):
		return
	await scene_changed
	var title := current_scene
	if not _check(title != null and title.get_script() != null, "Title screen did not initialize."):
		return
	title.call("_start_mission")
	await scene_changed
	await physics_frame

	var run := current_scene as LastLightRun
	if not _check(run != null, "Run did not start."):
		return
	if not _check(run._metrics != null and not run._metrics.run_id.is_empty(), "Metrics recorder did not begin a run."):
		return

	run.resonance = 100
	if not _check(run.upgrade_weapon(), "Weapon Upgrade failed during the metrics test."):
		return
	run.resonance = 100
	if not _check(run.activate_pulse(), "Emergency Blast failed during the metrics test."):
		return
	run._on_enemy_breached(2)
	await process_frame

	run._on_enemy_breached(run.integrity)
	await process_frame
	if not _check(run.is_over and not run.mission_won, "Shelter defeat did not end the run."):
		return

	var result: Dictionary = run._metrics.result
	if not _check(int(result.get("schema_version", 0)) == RunMetrics.METRICS_SCHEMA_VERSION, "Metrics result missed the schema version."):
		return
	if not _check(bool(result.get("won", true)) == false, "Metrics result reported the wrong outcome."):
		return
	if not _check(int(result.get("breaches", 0)) >= 2, "Metrics result missed breach counts."):
		return
	if not _check(result.has("salvage_earned"), "Metrics result missed the salvage payload key."):
		return

	var event_types: Array[String] = []
	for event: Dictionary in run._metrics.events:
		event_types.append(String(event.get("type", "")))
	var required_types: Array[String] = ["run_started", "upgrade_used", "blast_used", "breach", "run_ended"]
	for required: String in required_types:
		if not _check(event_types.has(required), "Metrics events missed a recorded type (%s)." % required):
			return

	var metrics_dir := DirAccess.open("user://")
	if not _check(metrics_dir != null and metrics_dir.dir_exists("metrics"), "Metrics folder was not created under user://."):
		return
	var file_name: String = "metrics/%s.json" % run._metrics.run_id
	if not _check(FileAccess.file_exists("user://" + file_name), "Metrics JSON file was not written for run %s." % run._metrics.run_id):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://" + file_name))
	if not _check(parsed is Dictionary and int((parsed as Dictionary).get("schema_version", 0)) == RunMetrics.METRICS_SCHEMA_VERSION, "Metrics JSON file did not round-trip with the schema version."):
		return

	print("PHASE 6 METRICS TEST PASSED")
	call_deferred("_finish", 0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 6 TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
