extends Control

const RUN_SCENE_PATH: String = "res://scenes/gameplay/run.tscn"
const SETTINGS_PATH: String = "user://settings.cfg"
const UI_FONT: FontFile = preload("res://assets/fonts/NotoSansThai.ttf")

var _settings_panel: PanelContainer
var _archive_panel: PanelContainer
var _title_stack: VBoxContainer
var _safe_root: MarginContainer
var _archive_label: Label
var _archive_back_button: Button
var _start_button: Button
var _barricade_button: Button
var _profile_summary: Label
var _volume_slider: HSlider
var _language_option: OptionButton
var _reduce_flash: CheckButton
var _reduce_motion: CheckButton
var _large_text: CheckButton
var _sfx_slider: HSlider
var _music_slider: HSlider
var _settings := ConfigFile.new()


func _ready() -> void:
	_load_settings()
	_build_screen()
	_start_button.grab_focus()


func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#202722")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var dust := CPUParticles2D.new()
	dust.amount = 18
	dust.lifetime = 8.0
	dust.preprocess = 4.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(180.0, 320.0)
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = 30.0
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 12.0
	dust.gravity = Vector2(0.0, -1.0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	dust.color = Color(0.85, 0.78, 0.55, 0.12)
	dust.position = Vector2(180.0, 320.0)
	add_child(dust)

	_safe_root = MarginContainer.new()
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_root)
	SafeAreaLayout.apply(_safe_root, 12)
	_apply_ui_scale()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe_root.add_child(center)
	_title_stack = VBoxContainer.new()
	_title_stack.custom_minimum_size = Vector2(0.0, 0.0)
	_title_stack.add_theme_constant_override("separation", 14)
	center.add_child(_title_stack)

	var title := Label.new()
	title.text = "LAST LIGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#d6a453"))
	title.add_theme_font_size_override("font_size", 36)
	_title_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = tr("TITLE_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#afc2d5"))
	_title_stack.add_child(subtitle)

	_start_button = _make_button("START_MISSION")
	_start_button.pressed.connect(_start_mission)
	_title_stack.add_child(_start_button)

	var settings_button := _make_button("SETTINGS")
	settings_button.pressed.connect(_show_settings)
	_title_stack.add_child(settings_button)

	var controls := Label.new()
	controls.text = "%s\n%s\n%s" % [tr("MOVE_HELP"), tr("POWER_HELP"), tr("AUTOFIRE_HELP")]
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_color_override("font_color", Color("#afc2d5"))
	_title_stack.add_child(controls)

	var profile: Dictionary = get_node("/root/ProgressionService").call("get_profile")
	_profile_summary = Label.new()
	_profile_summary.text = tr("PROFILE_SUMMARY") % [profile["salvage"], profile["victories"]]
	_profile_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_summary.add_theme_color_override("font_color", Color("#ffc857"))
	_title_stack.add_child(_profile_summary)

	_barricade_button = _make_button("BARRICADE_UPGRADE")
	_barricade_button.pressed.connect(_upgrade_barricade)
	_title_stack.add_child(_barricade_button)
	var progression_service: Node = get_node("/root/ProgressionService")
	progression_service.connect("profile_changed", _refresh_barricade_button)
	progression_service.connect("save_failed", _on_profile_save_failed)
	_refresh_barricade_button()

	var archive_button := _make_button("ARCHIVE")
	archive_button.pressed.connect(_show_archive)
	_title_stack.add_child(archive_button)

	var quit_button := _make_button("QUIT")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_title_stack.add_child(quit_button)

	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-150.0, -155.0)
	_settings_panel.size = Vector2(300.0, 310.0)
	_safe_root.add_child(_settings_panel)
	var settings_stack := VBoxContainer.new()
	settings_stack.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(settings_stack)

	var settings_title := Label.new()
	settings_title.text = tr("SETTINGS")
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_stack.add_child(settings_title)

	var volume_label := Label.new()
	volume_label.text = tr("MASTER_VOLUME")
	settings_stack.add_child(volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = -30.0
	_volume_slider.max_value = 0.0
	_volume_slider.step = 1.0
	_volume_slider.value = float(_settings.get_value("audio", "master_db", 0.0))
	_volume_slider.value_changed.connect(_on_volume_changed)
	settings_stack.add_child(_volume_slider)

	var sfx_label := Label.new()
	sfx_label.text = tr("SFX_VOLUME")
	settings_stack.add_child(sfx_label)
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = -30.0
	_sfx_slider.max_value = 0.0
	_sfx_slider.step = 1.0
	_sfx_slider.value = float(_settings.get_value("audio", "sfx_db", 0.0))
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	settings_stack.add_child(_sfx_slider)

	var music_label := Label.new()
	music_label.text = tr("MUSIC_VOLUME")
	settings_stack.add_child(music_label)
	_music_slider = HSlider.new()
	_music_slider.min_value = -30.0
	_music_slider.max_value = 0.0
	_music_slider.step = 1.0
	_music_slider.value = float(_settings.get_value("audio", "music_db", -12.0))
	_music_slider.value_changed.connect(_on_music_volume_changed)
	settings_stack.add_child(_music_slider)

	var language_row := HBoxContainer.new()
	var language_label := Label.new()
	language_label.text = tr("LANGUAGE")
	language_row.add_child(language_label)
	_language_option = OptionButton.new()
	_language_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_language_option.add_item(tr("ENGLISH"), 0)
	_language_option.add_item(tr("THAI"), 1)
	_language_option.select(1 if TranslationServer.get_locale().begins_with("th") else 0)
	_language_option.item_selected.connect(_on_language_selected)
	language_row.add_child(_language_option)
	settings_stack.add_child(language_row)

	_reduce_flash = CheckButton.new()
	_reduce_flash.text = tr("REDUCE_FLASHES")
	_reduce_flash.button_pressed = bool(_settings.get_value("accessibility", "reduce_flashes", false))
	_reduce_flash.toggled.connect(_on_reduce_flashes_changed)
	settings_stack.add_child(_reduce_flash)

	_reduce_motion = CheckButton.new()
	_reduce_motion.text = tr("REDUCE_MOTION")
	_reduce_motion.button_pressed = bool(_settings.get_value("accessibility", "reduce_motion", false))
	_reduce_motion.toggled.connect(_on_reduce_motion_changed)
	settings_stack.add_child(_reduce_motion)

	_large_text = CheckButton.new()
	_large_text.text = tr("LARGE_TEXT")
	_large_text.button_pressed = bool(_settings.get_value("accessibility", "large_text", false))
	_large_text.toggled.connect(_on_large_text_changed)
	settings_stack.add_child(_large_text)

	var back_button := _make_button("BACK")
	back_button.pressed.connect(_hide_settings)
	settings_stack.add_child(back_button)
	_settings_panel.hide()

	_archive_panel = PanelContainer.new()
	_archive_panel.set_anchors_preset(Control.PRESET_CENTER)
	_archive_panel.position = Vector2(-150.0, -180.0)
	_archive_panel.size = Vector2(300.0, 360.0)
	_safe_root.add_child(_archive_panel)
	var archive_stack := VBoxContainer.new()
	archive_stack.add_theme_constant_override("separation", 10)
	_archive_panel.add_child(archive_stack)
	var archive_title := Label.new()
	archive_title.text = tr("ARCHIVE_TITLE")
	archive_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archive_stack.add_child(archive_title)
	_archive_label = Label.new()
	_archive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_archive_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	archive_stack.add_child(_archive_label)
	_archive_back_button = _make_button("BACK")
	_archive_back_button.pressed.connect(_hide_archive)
	archive_stack.add_child(_archive_back_button)
	_archive_panel.hide()


func _start_mission() -> void:
	get_tree().change_scene_to_file(RUN_SCENE_PATH)


func _upgrade_barricade() -> void:
	var progression_service: Node = get_node("/root/ProgressionService")
	if not bool(progression_service.call("upgrade_barricade")):
		_refresh_barricade_button()


func _refresh_barricade_button(_profile: Dictionary = {}) -> void:
	if _barricade_button == null:
		return
	var progression_service: Node = get_node("/root/ProgressionService")
	var profile: Dictionary = progression_service.call("get_profile")
	_profile_summary.text = tr("PROFILE_SUMMARY") % [profile["salvage"], profile["victories"]] + "\n" + tr("BEST_WAVE_LABEL") % int(profile.get("best_wave", 1))
	var level: int = int(profile.get("barricade_level", 0))
	var cost: int = int(progression_service.call("get_barricade_upgrade_cost"))
	if cost == 0:
		_barricade_button.text = tr("BARRICADE_MAX") % level
		_barricade_button.disabled = true
		return
	_barricade_button.text = tr("BARRICADE_UPGRADE") % [level + 1, cost]
	_barricade_button.disabled = int(profile.get("salvage", 0)) < cost


func _on_profile_save_failed(message: String) -> void:
	if _barricade_button != null:
		_barricade_button.text = tr("BASE_SAVE_FAILED")
		_barricade_button.tooltip_text = message


func _show_settings() -> void:
	_title_stack.hide()
	_settings_panel.show()
	_volume_slider.grab_focus()


func _hide_settings() -> void:
	_settings_panel.hide()
	_title_stack.show()
	_start_button.grab_focus()


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	_settings.set_value("audio", "master_db", value)
	_save_settings()


func _on_reduce_flashes_changed(enabled: bool) -> void:
	_settings.set_value("accessibility", "reduce_flashes", enabled)
	_save_settings()


func _on_reduce_motion_changed(enabled: bool) -> void:
	_settings.set_value("accessibility", "reduce_motion", enabled)
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, value)
	_settings.set_value("audio", "sfx_db", value)
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, value)
	_settings.set_value("audio", "music_db", value)
	_save_settings()


func _on_large_text_changed(enabled: bool) -> void:
	_settings.set_value("accessibility", "large_text", enabled)
	_save_settings()
	_apply_ui_scale()


func _on_language_selected(index: int) -> void:
	var locale: String = "th" if index == 1 else "en"
	TranslationServer.set_locale(locale)
	_settings.set_value("localization", "locale", locale)
	_save_settings()
	get_tree().reload_current_scene()


func _show_archive() -> void:
	_title_stack.hide()
	_archive_panel.show()
	_archive_label.text = _build_archive_text()
	_archive_back_button.grab_focus()


func _hide_archive() -> void:
	_archive_panel.hide()
	_title_stack.show()
	_start_button.grab_focus()


func _build_archive_text() -> String:
	var profile: Dictionary = get_node("/root/ProgressionService").call("get_profile")
	var unlocked: Array = profile.get("codex_unlocked", [])
	var entries: Array[Dictionary] = [
		{"id": "lore_signal", "title": "LORE_SIGNAL_TITLE", "body": "LORE_SIGNAL_BODY", "threshold": 20},
		{"id": "lore_warden", "title": "LORE_WARDEN_TITLE", "body": "LORE_WARDEN_BODY", "threshold": 75},
		{"id": "lore_last_light", "title": "LORE_LAST_LIGHT_TITLE", "body": "LORE_LAST_LIGHT_BODY", "threshold": 150},
	]
	var lines: PackedStringArray = []
	for entry: Dictionary in entries:
		if unlocked.has(entry["id"]):
			lines.append("%s\n%s" % [tr(entry["title"]), tr(entry["body"])])
		else:
			lines.append(tr("ARCHIVE_LOCKED") % entry["threshold"])
	var run_summary: String = tr("RECORDS") % [profile["total_runs"], profile["victories"], profile["best_wave"]]
	return "%s\n\n%s" % [run_summary, "\n\n".join(lines)]


func _load_settings() -> void:
	var error: Error = _settings.load(SETTINGS_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load settings: %s" % error_string(error))
	var master_db: float = float(_settings.get_value("audio", "master_db", 0.0))
	AudioServer.set_bus_volume_db(0, clampf(master_db, -30.0, 0.0))
	var sfx_db: float = float(_settings.get_value("audio", "sfx_db", 0.0))
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, clampf(sfx_db, -30.0, 0.0))
	var music_db: float = float(_settings.get_value("audio", "music_db", -12.0))
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, clampf(music_db, -30.0, 0.0))
	TranslationServer.set_locale(str(_settings.get_value("localization", "locale", "en")))


func _apply_ui_scale() -> void:
	if _safe_root == null:
		return
	var ui_theme := Theme.new()
	ui_theme.default_font = UI_FONT
	ui_theme.default_font_size = 20 if bool(_settings.get_value("accessibility", "large_text", false)) else 16
	_safe_root.theme = ui_theme


func _save_settings() -> void:
	var error: Error = _settings.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))
		if has_node("/root/DiagnosticService"):
			get_node("/root/DiagnosticService").log_error("Could not save settings: %s" % error_string(error))


func _make_button(translation_key: String) -> Button:
	var button := Button.new()
	button.text = tr(translation_key)
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.focus_mode = Control.FOCUS_ALL
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel.visible:
		_hide_settings()
	elif _archive_panel.visible:
		_hide_archive()
