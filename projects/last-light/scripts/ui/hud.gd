extends CanvasLayer
class_name RunHud

const UI_FONT: FontFile = preload("res://assets/fonts/NotoSansThai.ttf")

signal pulse_pressed
signal overclock_pressed
signal restart_pressed
signal pause_pressed
signal resume_pressed
signal title_pressed
signal move_axis_changed(value: float)

var _integrity_label: Label
var _resonance_label: Label
var _wave_label: Label
var _time_label: Label
var _weapon_label: Label
var _pulse_button: Button
var _overclock_button: Button
var _boss_health_bar: ProgressBar
var _pause_button: Button
var _resume_button: Button
var _restart_button: Button
var _title_button: Button
var _overlay: PanelContainer
var _overlay_title: Label
var _result_detail: Label
var _safe_root: MarginContainer
var _left_held: bool = false
var _right_held: bool = false
var _result_visible: bool = false
var _font_size: int = 14


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var settings := ConfigFile.new()
	var settings_error: Error = settings.load("user://settings.cfg")
	if settings_error != OK and settings_error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load UI accessibility settings: %s" % error_string(settings_error))
	_font_size = 18 if bool(settings.get_value("accessibility", "large_text", false)) else 14
	_safe_root = MarginContainer.new()
	_safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_safe_root)
	SafeAreaLayout.apply(_safe_root, 10)
	var ui_theme := Theme.new()
	ui_theme.default_font = UI_FONT
	_safe_root.theme = ui_theme

	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 12.0
	top_bar.offset_top = 10.0
	top_bar.offset_right = -12.0
	top_bar.offset_bottom = 42.0
	top_bar.add_theme_constant_override("separation", 10)
	_safe_root.add_child(top_bar)

	_integrity_label = _make_label("BEACON 5")
	_resonance_label = _make_label("RESONANCE 0%")
	_wave_label = _make_label("WAVE 1")
	_time_label = _make_label("05:00")
	for label: Label in [_integrity_label, _resonance_label, _wave_label, _time_label]:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_bar.add_child(label)

	var weapon_row := HBoxContainer.new()
	weapon_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	weapon_row.offset_left = 12.0
	weapon_row.offset_top = 44.0
	weapon_row.offset_right = -12.0
	weapon_row.offset_bottom = 70.0
	_safe_root.add_child(weapon_row)

	_weapon_label = _make_label("WEAPON LV 1")
	weapon_row.add_child(_weapon_label)
	_pause_button = _make_button("II")
	_pause_button.custom_minimum_size = Vector2(44.0, 30.0)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	weapon_row.add_child(_pause_button)

	_boss_health_bar = ProgressBar.new()
	_boss_health_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_health_bar.offset_left = 12.0
	_boss_health_bar.offset_top = 74.0
	_boss_health_bar.offset_right = -12.0
	_boss_health_bar.offset_bottom = 88.0
	_boss_health_bar.show_percentage = false
	_safe_root.add_child(_boss_health_bar)
	_boss_health_bar.hide()

	var buttons := HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_left = 12.0
	buttons.offset_top = -76.0
	buttons.offset_right = -12.0
	buttons.offset_bottom = -12.0
	buttons.add_theme_constant_override("separation", 5)
	_safe_root.add_child(buttons)

	var left_button := _make_button("◀")
	var right_button := _make_button("▶")
	_pulse_button = _make_button("PULSE_BUTTON")
	_overclock_button = _make_button("OVERCLOCK_BUTTON")
	for button: Button in [left_button, right_button, _pulse_button, _overclock_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0.0
	buttons.add_child(left_button)
	buttons.add_child(right_button)
	left_button.button_down.connect(_set_left_held.bind(true))
	left_button.button_up.connect(_set_left_held.bind(false))
	right_button.button_down.connect(_set_right_held.bind(true))
	right_button.button_up.connect(_set_right_held.bind(false))
	buttons.add_child(_pulse_button)
	buttons.add_child(_overclock_button)
	_pulse_button.pressed.connect(func() -> void: pulse_pressed.emit())
	_overclock_button.pressed.connect(func() -> void: overclock_pressed.emit())

	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.position = Vector2(-142.0, -104.0)
	_overlay.size = Vector2(300.0, 240.0)
	_safe_root.add_child(_overlay)
	var overlay_stack := VBoxContainer.new()
	overlay_stack.add_theme_constant_override("separation", 10)
	_overlay.add_child(overlay_stack)
	_overlay_title = _make_label("PAUSED")
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_stack.add_child(_overlay_title)
	_result_detail = _make_label("")
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_stack.add_child(_result_detail)
	_resume_button = _make_button("RESUME")
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	overlay_stack.add_child(_resume_button)
	_restart_button = _make_button("RESTART")
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	overlay_stack.add_child(_restart_button)
	_title_button = _make_button("TITLE")
	_title_button.pressed.connect(func() -> void: title_pressed.emit())
	overlay_stack.add_child(_title_button)
	_overlay.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _result_visible:
		return
	if _overlay.visible:
		resume_pressed.emit()
	else:
		pause_pressed.emit()


func update_status(integrity: int, resonance: int, weapon_level: int, wave: int, can_upgrade: bool, time_remaining: int) -> void:
	_integrity_label.text = tr("BEACON_LABEL") % integrity
	_resonance_label.text = tr("RESONANCE_LABEL") % resonance
	_wave_label.text = tr("WAVE_LABEL") % wave
	_time_label.text = "%02d:%02d" % [time_remaining / 60, time_remaining % 60]
	_weapon_label.text = tr("WEAPON_LABEL") % weapon_level
	_pulse_button.disabled = resonance < 100
	_overclock_button.disabled = resonance < 100 or not can_upgrade


func show_game_over() -> void:
	show_result(false)


func show_boss_health(maximum: int) -> void:
	_boss_health_bar.max_value = maximum
	_boss_health_bar.value = maximum
	_boss_health_bar.show()


func update_boss_health(current: int, maximum: int) -> void:
	_boss_health_bar.max_value = maximum
	_boss_health_bar.value = current
	if current <= 0:
		_boss_health_bar.hide()


func show_result(won: bool, salvage_earned: int = 0, profile: Dictionary = {}) -> void:
	_result_visible = true
	_overlay.show()
	_overlay_title.text = tr("MISSION_COMPLETE") if won else tr("BEACON_LOST")
	_result_detail.text = "%s\n%s" % [
		tr("SALVAGE_EARNED") % salvage_earned,
		tr("SALVAGE_TOTAL") % int(profile.get("salvage", 0)),
	]
	_resume_button.hide()
	_pulse_button.disabled = true
	_overclock_button.disabled = true
	_restart_button.grab_focus()


func show_pause() -> void:
	_overlay.show()
	_overlay_title.text = tr("PAUSED")
	_resume_button.show()
	_resume_button.grab_focus()


func show_save_error(message: String) -> void:
	_result_detail.text += "\n%s: %s" % [tr("SAVE_FAILED"), message]


func hide_overlay() -> void:
	_overlay.hide()
	get_viewport().gui_release_focus()


func _set_left_held(held: bool) -> void:
	_left_held = held
	_emit_move_axis()


func _set_right_held(held: bool) -> void:
	_right_held = held
	_emit_move_axis()


func _emit_move_axis() -> void:
	var axis: float = 0.0
	if _right_held:
		axis += 1.0
	if _left_held:
		axis -= 1.0
	move_axis_changed.emit(axis)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = tr(text) if not text.is_empty() else ""
	label.add_theme_color_override("font_color", Color(0.88, 0.95, 0.95))
	label.add_theme_font_size_override("font_size", _font_size)
	return label


func _make_button(translation_key: String) -> Button:
	var button := Button.new()
	button.text = tr(translation_key) if translation_key != "◀" and translation_key != "▶" else translation_key
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", _font_size)
	return button
