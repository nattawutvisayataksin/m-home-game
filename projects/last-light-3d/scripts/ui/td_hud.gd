class_name TDHud
extends CanvasLayer

## Minimal event-driven greybox HUD: economy status, wave preview, tower select,
## start-wave control and a result overlay. Built entirely in code.

signal tower_selected(kind: int)
signal start_wave_pressed
signal restart_pressed
signal resume_pressed
signal title_pressed

const KIND_LABELS: Array[String] = ["1 Field Turret (80)", "2 Sonic Resonator (120)", "3 Tangle Emitter (60)"]

var _parts_label: Label
var _integrity_label: Label
var _wave_label: Label
var _preview_label: Label
var _start_button: Button
var _overlay: CenterContainer
var _overlay_message: Label
var _overlay_restart: Button
var _tower_buttons: Array[Button] = []

var _pause_overlay: Control
var _settings_overlay: Control
var _settings_panel_node: TDSettingsPanel
var _pause_was_open: bool = false
var _flash_rect: ColorRect
var _font_texts: Array[Control] = []


func _ready() -> void:
	# The HUD owns pause/settings input, so it must answer Esc even while the
	# tree is paused; gameplay nodes stay pausable beneath this layer.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var store := get_node_or_null("/root/TDSettings") as TDSettingsStore
	if store != null:
		store.settings_changed.connect(_on_settings_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode != KEY_ESCAPE:
			return
		# Result overlay up: nothing to go back from.
		if _overlay != null and _overlay.visible:
			return
		if is_settings_open():
			close_settings()
		else:
			# Toggle pause through the run (resume_pressed is wired to toggle_pause).
			resume_pressed.emit()


func build_ui() -> void:
	var root := MarginContainer.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)

	_parts_label = Label.new()
	_integrity_label = Label.new()
	_wave_label = Label.new()
	_preview_label = Label.new()
	_style_text(_preview_label, "font_size", 15)
	top.add_child(_parts_label)
	top.add_child(_integrity_label)
	top.add_child(_wave_label)
	top.add_child(_preview_label)

	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom.add_child(buttons)

	for index: int in range(3):
		var button := Button.new()
		button.text = KIND_LABELS[index]
		button.focus_mode = Control.FOCUS_NONE
		_style_text(button, "font_size", 16)
		var kind: int = index
		button.pressed.connect(func () -> void: tower_selected.emit(kind))
		buttons.add_child(button)
		_tower_buttons.append(button)

	var start_row := HBoxContainer.new()
	start_row.alignment = BoxContainer.ALIGNMENT_END
	_start_button = Button.new()
	_start_button.text = "Start Wave (Space)"
	_start_button.focus_mode = Control.FOCUS_NONE
	_style_text(_start_button, "font_size", 16)
	_start_button.pressed.connect(func () -> void: start_wave_pressed.emit())
	start_row.add_child(_start_button)
	bottom.add_child(start_row)

	_overlay = CenterContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var overlay_box := PanelContainer.new()
	_overlay.add_child(overlay_box)
	var overlay_stack := VBoxContainer.new()
	overlay_stack.add_theme_constant_override("separation", 12)
	overlay_box.add_child(overlay_stack)
	_overlay_message = Label.new()
	overlay_stack.add_child(_overlay_message)
	_overlay_restart = Button.new()
	_overlay_restart.text = "Restart"
	_overlay_restart.focus_mode = Control.FOCUS_NONE
	_style_text(_overlay_restart, "font_size", 16)
	_overlay_restart.pressed.connect(func () -> void: restart_pressed.emit())
	overlay_stack.add_child(_overlay_restart)

	var overlay_title := Button.new()
	overlay_title.text = "Main Menu"
	overlay_title.focus_mode = Control.FOCUS_NONE
	_style_text(overlay_title, "font_size", 16)
	overlay_title.pressed.connect(func () -> void: title_pressed.emit())
	overlay_stack.add_child(overlay_title)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "LeakFlash"
	_flash_rect.color = Color(1.0, 0.2, 0.2, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Decorative overlay: never eat clicks or emit them into the 3D scene.
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)

	# --- Pause Menu Overlay (Esc) ---
	# Full-rect host + separate dim background: a dim ColorRect inside a
	# CenterContainer gets squished to its minimum size by the container.
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)

	var pause_bg := ColorRect.new()
	pause_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_bg.color = Color(0.04, 0.05, 0.06, 0.75)
	_pause_overlay.add_child(pause_bg)

	var pause_center := CenterContainer.new()
	pause_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(pause_center)

	var pause_box := PanelContainer.new()
	pause_center.add_child(pause_box)

	var pause_stack := VBoxContainer.new()
	pause_stack.add_theme_constant_override("separation", 14)
	pause_box.add_child(pause_stack)

	var pause_title := Label.new()
	pause_title.text = "PAUSED / พักเกม"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(pause_title, "font_size", 20)
	pause_stack.add_child(pause_title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume (เล่นต่อ / Esc)"
	resume_btn.focus_mode = Control.FOCUS_NONE
	_style_text(resume_btn, "font_size", 16)
	resume_btn.pressed.connect(func () -> void: resume_pressed.emit())
	pause_stack.add_child(resume_btn)

	var restart_pause_btn := Button.new()
	restart_pause_btn.text = "Restart Mission (เริ่มใหม่)"
	restart_pause_btn.focus_mode = Control.FOCUS_NONE
	_style_text(restart_pause_btn, "font_size", 16)
	restart_pause_btn.pressed.connect(func () -> void: restart_pressed.emit())
	pause_stack.add_child(restart_pause_btn)

	var settings_btn := Button.new()
	settings_btn.text = "ตั้งค่า (Settings)"
	settings_btn.focus_mode = Control.FOCUS_NONE
	_style_text(settings_btn, "font_size", 16)
	settings_btn.pressed.connect(_open_settings)
	pause_stack.add_child(settings_btn)

	var title_btn := Button.new()
	title_btn.text = "Title Menu (กลับหน้าหลัก)"
	title_btn.focus_mode = Control.FOCUS_NONE
	_style_text(title_btn, "font_size", 16)
	title_btn.pressed.connect(func () -> void: title_pressed.emit())
	pause_stack.add_child(title_btn)

	_build_settings_overlay()


# --- Settings overlay (shared TDSettingsPanel, shown from pause) ----------

func _build_settings_overlay() -> void:
	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	_settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings_overlay)

	var bg := ColorRect.new()
	bg.name = "DimBackground"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.06, 0.96)
	_settings_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)

	var box := PanelContainer.new()
	center.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	box.add_child(margin)

	_settings_panel_node = TDSettingsPanel.new()
	_settings_panel_node.closed.connect(close_settings)
	margin.add_child(_settings_panel_node)


func _open_settings() -> void:
	if _settings_overlay == null:
		return
	# Tuck the pause menu below us: semi-transparent style boxes would let the
	# menu text bleed through the settings panel regardless of overlay alpha.
	_pause_was_open = is_pause_menu_open()
	if _pause_was_open and _pause_overlay != null:
		_pause_overlay.visible = false
	_settings_overlay.visible = true


func close_settings() -> void:
	if _settings_overlay == null:
		return
	_settings_overlay.visible = false
	if _pause_was_open and _pause_overlay != null:
		_pause_overlay.visible = true
	_pause_was_open = false


func is_settings_open() -> bool:
	return _settings_overlay != null and _settings_overlay.visible


func update_status(parts: int, integrity: int, wave: int, max_waves: int) -> void:
	_parts_label.text = "Parts: %d" % parts
	_integrity_label.text = "Shelter Integrity: %d" % integrity
	_wave_label.text = "Wave %d / %d" % [wave, max_waves]


func show_wave_preview(composition_text: String) -> void:
	_preview_label.text = "Next: %s" % composition_text


func set_combat_state(is_combat_active: bool) -> void:
	_start_button.disabled = is_combat_active
	_start_button.text = "Wave running..." if is_combat_active else "Start Wave (Space)"


func show_result(won: bool, parts_at_end: int) -> void:
	_overlay.visible = true
	_overlay_message.text = "SHELTER HELD — Salvage earned" if won else "SHELTER FELL\nParts at end: %d" % parts_at_end


func set_pause_menu(open: bool) -> void:
	_pause_overlay.visible = open


func is_pause_menu_open() -> bool:
	return _pause_overlay != null and _pause_overlay.visible


## Red screen pulse when the Shelter takes leak damage. reduce_flashes keeps
## the pulse small instead of removing it (it is a "state change" signal).
func flash_leak() -> void:
	if _flash_rect == null:
		return
	var store := get_node_or_null("/root/TDSettings") as TDSettingsStore
	var peak: float = 0.12 if (store != null and store.get_reduce_flashes()) else 0.3
	_flash_rect.color = Color(1.0, 0.2, 0.2, peak)
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, 0.3)


# --- Text scaling (large text option) -------------------------------------

func _style_text(node: Control, theme_item: String, base_size: int) -> void:
	node.add_theme_font_size_override(theme_item, _text_size(base_size))
	node.set_meta(&"font_item", theme_item)
	node.set_meta(&"font_base", base_size)
	_font_texts.append(node)


func _text_size(base_size: int) -> int:
	var store := get_node_or_null("/root/TDSettings") as TDSettingsStore
	return base_size if store == null else store.ui_font_size(base_size)


func _apply_text_scale() -> void:
	for node: Control in _font_texts:
		if not is_instance_valid(node):
			continue
		var item := str(node.get_meta(&"font_item"))
		var base_size := int(node.get_meta(&"font_base"))
		node.add_theme_font_size_override(item, _text_size(base_size))


func _on_settings_changed(section: StringName, key: StringName) -> void:
	if section == &"accessibility" and key == &"large_text":
		_apply_text_scale()
