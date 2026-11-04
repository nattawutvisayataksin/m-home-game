extends SceneTree

## Phase 3 test — settings store + settings UI:
## 1) TDSettings autoload exists, applies audio values, and round-trips to disk
##    on an isolated test file (test file removed afterwards, real config kept)
## 2) ui_font_size honors the large-text accessibility option
## 3) title menu hosts the settings panel; large-text toggle rescales fonts
## 4) pause menu hosts the shared panel; Esc closes settings first, then resumes

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")
const TEST_PATH: String = "user://phase3_settings_test.cfg"

var _last_section: StringName = &""
var _last_key: StringName = &""


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var store := root.get_node_or_null("TDSettings") as TDSettingsStore
	if not _check(store != null, "TDSettings autoload missing from the scene root."):
		return

	# Isolate writes away from the player's real settings.cfg.
	store.settings_path = TEST_PATH

	if not await _test_settings_store(store):
		return
	if not await _test_title_settings(store):
		return
	if not await _test_pause_settings(store):
		return

	# Restore the real config file mapping so the build keeps behaving normally.
	store.settings_path = "user://settings.cfg"
	store.load_settings()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("phase3_settings_test.cfg")

	print("PHASE 3 SETTINGS TEST PASSED")
	call_deferred("_finish", 0)


func _test_settings_store(store: TDSettingsStore) -> bool:
	store.set_master_volume_db(-9.0)
	store.set_sfx_volume_db(-3.0)
	store.set_music_volume_db(-20.0)
	store.set_reduce_flashes(true)
	store.set_reduce_motion(true)
	store.set_large_text(false)

	if not _check(AudioServer.get_bus_volume_db(0) == store.get_master_volume_db(), "Master bus volume was not applied by the store."):
		return false

	# Fresh instance reads the same file: the values must have persisted.
	var reloaded := TDSettingsStore.new()
	reloaded.settings_path = TEST_PATH
	reloaded.load_settings()
	if not _check(is_equal_approx(reloaded.get_master_volume_db(), -9.0), "Master volume did not persist to the settings file."):
		return false
	if not _check(is_equal_approx(reloaded.get_sfx_volume_db(), -3.0), "SFX volume did not persist to the settings file."):
		return false
	if not _check(is_equal_approx(reloaded.get_music_volume_db(), -20.0), "Music volume did not persist to the settings file."):
		return false
	if not _check(reloaded.get_reduce_flashes() and reloaded.get_reduce_motion(), "Accessibility toggles did not persist to the settings file."):
		return false

	reloaded.queue_free()

	if not _check(store.get_reduce_flashes() and store.get_reduce_motion(), "Live store toggles did not stick after save()."):
		return false

	# Large-text scaling contract (+4 per the store).
	store.set_large_text(false)
	if not _check(store.ui_font_size(22) == 22, "ui_font_size changed size without large text enabled."):
		return false
	store.set_large_text(true)
	if not _check(store.ui_font_size(22) == 26, "ui_font_size did not scale with large text enabled."):
		return false
	store.set_large_text(false)

	# Change signal fires with section/key tags.
	_last_section = &""
	_last_key = &""
	store.settings_changed.connect(_catch_change)
	store.set_reduce_flashes(false)
	store.settings_changed.disconnect(_catch_change)
	if not _check(_last_section == &"accessibility" and _last_key == &"reduce_flashes", "settings_changed did not report the accessibility/right toggle tags."):
		return false

	return true


func _catch_change(section: StringName, key: StringName) -> void:
	_last_section = section
	_last_key = key


func _test_title_settings(store: TDSettingsStore) -> bool:
	if not _check(change_scene_to_packed(TITLE_SCENE) == OK, "Could not change to the title scene."):
		return false
	await scene_changed
	await physics_frame

	var title := current_scene as TDTitleMenu
	if not _check(title != null, "Title scene did not instantiate TDTitleMenu."):
		return false
	if not _check(title._settings_panel != null, "Title is missing the settings panel."):
		return false

	# Open like the ตั้งค่า button does; other panels must close.
	title._show_panel(title._how_panel)
	title._show_panel(title._settings_panel)
	if not _check(title._settings_panel.visible and not title._how_panel.visible, "Opening settings did not close the how-to panel."):
		return false
	if not _check(title.panels_open(), "panels_open() missed the settings panel."):
		return false
	title._close_panels()
	if not _check(not title.panels_open(), "Settings panel did not close via _close_panels()."):
		return false

	# Large text rescale reaches existing built UI live.
	var base_size: int = title._subtitle.get_theme_font_size("font_size")
	store.set_large_text(true)
	var larger: int = title._subtitle.get_theme_font_size("font_size")
	if not _check(larger > base_size, "Large-text toggle did not rescale built title text."):
		return false
	store.set_large_text(false)
	if not _check(title._subtitle.get_theme_font_size("font_size") == base_size, "Disabling large text did not restore title text size."):
		return false
	return true


func _test_pause_settings(store: TDSettingsStore) -> bool:
	if not _check(change_scene_to_packed(RUN_SCENE) == OK, "Could not load the run scene."):
		return false
	await scene_changed
	await physics_frame

	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return false

	if not _check(not run._hud.is_settings_open(), "Settings overlay must start closed in pause."):
		return false

	run.toggle_pause()
	if not _check(paused and run._hud.is_pause_menu_open(), "Pause did not open before settings test."):
		return false

	run._hud._open_settings()
	if not _check(run._hud.is_settings_open(), "Pause settings button did not open the settings overlay."):
		return false
	if not _check(run._hud._settings_panel_node != null and run._hud._settings_panel_node.get_child_count() > 0, "Pause settings overlay did not host the shared panel."):
		return false

	# Esc closes settings first and must stay paused (HUD input path).
	run._hud._unhandled_input(_make_escape_event())
	if not _check(not run._hud.is_settings_open(), "Esc did not close the settings overlay."):
		return false
	if not _check(paused and run._hud.is_pause_menu_open(), "Esc closed settings but dropped out of pause."):
		return false

	# Second Esc resumes the game.
	run._hud._unhandled_input(_make_escape_event())
	if not _check(not paused and not run._hud.is_pause_menu_open(), "Esc did not resume from the pause menu."):
		return false
	return true


func _make_escape_event() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	return key


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 3 TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
