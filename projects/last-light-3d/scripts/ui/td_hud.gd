class_name TDHud
extends CanvasLayer

## Minimal event-driven greybox HUD: economy status, wave preview, tower select,
## start-wave control and a result overlay. Built entirely in code.

signal tower_selected(kind: int)
signal start_wave_pressed
signal restart_pressed

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
