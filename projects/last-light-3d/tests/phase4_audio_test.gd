extends SceneTree

## Phase 4 test — audio buses + director wiring:
## 1) SFX/Music buses exist (default_bus_layout) and are children of Master
## 2) TDSettings applies bus volumes when audio values change
## 3) the run hosts a TDAudioDirector (inert in headless but present)
## 4) towers report fired(kind) so the run can route the right SFX

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if not await _test_buses_and_settings():
		return
	if not await _test_director_wiring():
		return
	print("PHASE 4 AUDIO TEST PASSED")
	call_deferred("_finish", 0)


func _test_buses_and_settings() -> bool:
	var sfx_index: int = AudioServer.get_bus_index("SFX")
	var music_index: int = AudioServer.get_bus_index("Music")
	if not _check(sfx_index >= 0, "SFX bus missing from the bus layout."):
		return false
	if not _check(music_index >= 0, "Music bus missing from the bus layout."):
		return false
	if not _check(AudioServer.get_bus_send(sfx_index) == &"Master", "SFX bus is not a child of Master."):
		return false
	if not _check(AudioServer.get_bus_send(music_index) == &"Master", "Music bus is not a child of Master."):
		return false

	var store := root.get_node_or_null("TDSettings") as TDSettingsStore
	if not _check(store != null, "TDSettings autoload missing."):
		return false
	store.settings_path = "user://phase4_audio_test.cfg"
	store.set_sfx_volume_db(-7.0)
	if not _check(AudioServer.get_bus_volume_db(sfx_index) == -7.0, "SFX bus volume did not follow the settings store."):
		return false
	store.set_music_volume_db(-15.0)
	if not _check(AudioServer.get_bus_volume_db(music_index) == -15.0, "Music bus volume did not follow the settings store."):
		return false
	store.set_sfx_volume_db(0.0)
	store.set_music_volume_db(TDSettingsStore.DEFAULT_MUSIC_DB)
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("phase4_audio_test.cfg")
	store.settings_path = "user://settings.cfg"
	store.load_settings()
	return true


func _test_director_wiring() -> bool:
	if not _check(change_scene_to_packed(RUN_SCENE) == OK, "Could not load the run scene."):
		return false
	await scene_changed
	await physics_frame

	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return false
	var director := run.get_node_or_null("AudioDirector") as TDAudioDirector
	if not _check(director != null, "Run is missing the AudioDirector child."):
		return false
	# In headless CI the director loads no players by design.
	if not _check(director.is_enabled() == (DisplayServer.get_name() != "headless"), "Director enabled state does not match the display server."):
		return false
	# Playing a sound must never crash even when disabled.
	director.play_sfx("turret_shot", 0.08)
	director.play_sfx("not_a_sound")

	# Towers expose fired(kind) so the run routes the right SFX voice.
	var probe := TDTower.new()
	if not _check(probe.has_signal("fired"), "TDTower missing the fired(kind) signal."):
		return false
	probe.free()

	# Economy paths stay clean while the director is disabled (sell empty slot).
	if not _check(run.sell_tower(0) == false, "Selling an empty slot must fail cleanly."):
		return false
	return true


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 4 TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
