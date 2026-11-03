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

var _pause_overlay: CenterContainer


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
	_preview_label.add_theme_font_size_override("font_size", 15)
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
		var kind: int = index
		button.pressed.connect(func () -> void: tower_selected.emit(kind))
		buttons.add_child(button)
		_tower_buttons.append(button)

	var start_row := HBoxContainer.new()
	start_row.alignment = BoxContainer.ALIGNMENT_END
	_start_button = Button.new()
	_start_button.text = "Start Wave (Space)"
	_start_button.focus_mode = Control.FOCUS_NONE
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
	_overlay_restart.pressed.connect(func () -> void: restart_pressed.emit())
	overlay_stack.add_child(_overlay_restart)

	var overlay_title := Button.new()
	overlay_title.text = "Main Menu"
	overlay_title.focus_mode = Control.FOCUS_NONE
	overlay_title.pressed.connect(func () -> void: title_pressed.emit())
	overlay_stack.add_child(overlay_title)

	# --- Pause Menu Overlay (Esc) ---
	_pause_overlay = CenterContainer.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)

	var pause_bg := ColorRect.new()
	pause_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_bg.color = Color(0.04, 0.05, 0.06, 0.75)
	_pause_overlay.add_child(pause_bg)

	var pause_box := PanelContainer.new()
	_pause_overlay.add_child(pause_box)

	var pause_stack := VBoxContainer.new()
	pause_stack.add_theme_constant_override("separation", 14)
	pause_box.add_child(pause_stack)

	var pause_title := Label.new()
	pause_title.text = "PAUSED / พักเกม"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 20)
	pause_stack.add_child(pause_title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume (เล่นต่อ / Esc)"
	resume_btn.focus_mode = Control.FOCUS_NONE
	resume_btn.pressed.connect(func () -> void: resume_pressed.emit())
	pause_stack.add_child(resume_btn)

	var restart_pause_btn := Button.new()
	restart_pause_btn.text = "Restart Mission (เริ่มใหม่)"
	restart_pause_btn.focus_mode = Control.FOCUS_NONE
	restart_pause_btn.pressed.connect(func () -> void: restart_pressed.emit())
	pause_stack.add_child(restart_pause_btn)

	var title_btn := Button.new()
	title_btn.text = "Title Menu (กลับหน้าหลัก)"
	title_btn.focus_mode = Control.FOCUS_NONE
	title_btn.pressed.connect(func () -> void: title_pressed.emit())
	pause_stack.add_child(title_btn)


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
