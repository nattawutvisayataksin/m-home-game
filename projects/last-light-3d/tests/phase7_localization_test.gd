extends SceneTree

## Phase 7 test — Thai/English localization:
## 1) the godot CSV import loaded both locales (lookup works per language)
## 2) TDSettingsStore persists/loads the locale on an isolated test file and
##    applies it server-wide; stray values fall back to Thai
## 3) the title menu renders Thai copy, then rerenders live on switch to
##    English (menu button, settings-panel picker, resume button format)
## 4) the HUD rerenders dynamic labels (money/enemies/start button) per locale
## The player's real settings.cfg is never touched (isolated TEST_PATH).

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")
const TEST_PATH: String = "user://phase7_locale_test.cfg"

var _original_locale: String = ""


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var store := root.get_node("TDSettings") as TDSettingsStore
	if not _check(store != null, "TDSettings autoload missing from the scene root."):
		return

	# Isolate writes away from the player's real settings.cfg.
	store.settings_path = TEST_PATH
	_original_locale = TranslationServer.get_locale()

	if not _test_csv_translations():
		return
	if not _test_store_locale(store):
		return

	# Restore the Thai default before checking fresh-scene rendering.
	store.set_locale("th")

	# --- Title menu: render + live rerender on switch ------------------------
	var title := TITLE_SCENE.instantiate()
	root.add_child(title)

	var start_ok: bool = _find_title_button(title, "เริ่มการรบ") != null
	if not _check(start_ok,
			"Title menu did not start in Thai. locale=%s texts=%s" % [
				TranslationServer.get_locale(), _debug_column_texts(title),
			]):
		title.free()
		return

	store.set_locale("en")
	if not _check(_find_title_button(title, "START MISSION") != null,
			"Title menu button did not rerender live after switching to English."):
		title.free()
		return

	# The settings panel language picker must follow the new locale without
	# emitting a spurious item_selected.
	var panel := _find_settings_panel(title)
	if not _check(panel != null, "TDSettingsPanel missing on the title menu."):
		title.free()
		return
	_sync_language_option(panel)
	if not _check(panel._language_option.selected == panel.LOCALE_ENGLISH_INDEX,
			"Language picker did not follow the English locale."):
		title.free()
		return
	panel._on_language_selected(panel.LOCALE_THAI_INDEX)
	if not _check(TranslationServer.get_locale().begins_with("th"),
			"Language picker did not switch the locale back to Thai."):
		title.free()
		return

	# --- HUD: dynamic labels per locale -------------------------------------
	var hud := TDHud.new()
	root.add_child(hud)
	hud.build_ui()
	var locale_before: String = TranslationServer.get_locale()
	hud.update_status(320, 12, 2, 8)
	if not _check(hud._parts_label.text == "เงิน: 320",
			"HUD money label did not render Thai copy (locale=%s)." % locale_before):
		hud.free()
		title.free()
		return
	if not _check(hud._wave_label.text == "คลื่น 2 / 8", "HUD wave label did not render Thai copy."):
		hud.free()
		title.free()
		return

	hud.set_enemies_left(4)
	if not _check(hud._enemies_label.text == "ศัตรูคงเหลือ: 4", "HUD enemies label did not render Thai copy."):
		hud.free()
		title.free()
		return

	store.set_locale("en")
	if not _check(hud._parts_label.text == "Money: 320",
			"HUD money label did not rerender English after the locale switch."):
		hud.free()
		title.free()
		return
	if not _check(hud._enemies_label.text == "Enemies remaining: 4",
			"HUD enemies label did not rerender English after the locale switch."):
		hud.free()
		title.free()
		return
	if not _check(hud._start_button.text == "Start Wave (Space)",
			"Start button did not rerender English after the locale switch."):
		hud.free()
		title.free()
		return
	hud.set_combat_state(true, true)
	if not _check(hud._start_button.text == "Chain Wave (Space)",
			"Chain wave button did not use the English copy."):
		hud.free()
		title.free()
		return

	# --- Restore: Thai locale + real config mapping --------------------------
	title.free()
	hud.free()
	store.set_locale("th")
	store.settings_path = "user://settings.cfg"
	store.load_settings()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("phase7_locale_test.cfg")

	print("PHASE 7 LOCALIZATION TEST PASSED")
	call_deferred("_finish", 0)


# --- 1) CSV import loaded both locales --------------------------------------

func _test_csv_translations() -> bool:
	var original: String = TranslationServer.get_locale()
	TranslationServer.set_locale("th")
	var thai: String = TranslationServer.translate("START_MISSION")
	if not _check(thai == "เริ่มการรบ", "Thai lookup for START_MISSION failed (got %s)." % thai):
		return false
	TranslationServer.set_locale("en")
	var english: String = TranslationServer.translate("START_MISSION")
	if not _check(english == "START MISSION", "English lookup for START_MISSION failed (got %s)." % english):
		return false
	TranslationServer.set_locale(original)
	return true


# --- 2) store persists + restores the locale --------------------------------

func _test_store_locale(store: TDSettingsStore) -> bool:
	store.set_locale("en")
	if not _check(TranslationServer.get_locale() == "en", "set_locale did not apply English server-side."):
		return false
	# A fresh instance reading the same test file must restore English.
	var reloaded := TDSettingsStore.new()
	reloaded.settings_path = TEST_PATH
	root.add_child(reloaded)
	if not _check(reloaded.get_locale() == "en", "Locale did not persist to the isolated settings file."):
		reloaded.free()
		return false
	reloaded.free()

	store.set_locale("es")
	if not _check(TranslationServer.get_locale().begins_with("th"),
			"Stray locale values should fall back to Thai (Thai-first rule)."):
		return false
	store.set_locale("en")
	return true


# --- helpers -----------------------------------------------------------------

## Find a main-menu button by its rendered text in the active locale.
func _debug_column_texts(title: Control) -> String:
	var texts: Array[String] = []
	var column := title.get_node_or_null("MainColumn") as VBoxContainer
	if column != null:
		for child: Node in column.get_children():
			var button := child as Button
			if button != null:
				texts.append(button.text)
	return ",".join(texts)


func _find_title_button(title: Control, expected_text: String) -> Button:
	var column := title.get_node_or_null("MainColumn") as VBoxContainer
	if column == null:
		return null
	for child: Node in column.get_children():
		var button := child as Button
		if button != null and button.text == expected_text:
			return button
	return null


func _find_settings_panel(title: Control) -> TDSettingsPanel:
	var found := title.find_children("*", "TDSettingsPanel", true, false)
	return (found[0] as TDSettingsPanel) if found.size() > 0 else null


func _sync_language_option(panel: TDSettingsPanel) -> void:
	panel._sync_language_option()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 7 TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	await process_frame
	quit(exit_code)
