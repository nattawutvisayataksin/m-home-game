class_name TDHud
extends CanvasLayer

## Minimal event-driven greybox HUD: economy status, wave preview, tower select,
## start-wave control and a result overlay. Built entirely in code.

signal tower_selected(kind: int)
signal start_wave_pressed
signal restart_pressed
signal resume_pressed
signal title_pressed
signal next_map_pressed

## Tower card texts start as localization keys; `td_run` replaces them with
## data-driven labels once definitions load (see set_tower_cards).
const KIND_LABEL_KEYS: Array[String] = ["TOWER_CARD_1", "TOWER_CARD_2", "TOWER_CARD_3", "TOWER_CARD_4"]
const KIND_TIP_KEYS: Array[String] = ["TOWER_TIP_1", "TOWER_TIP_2", "TOWER_TIP_3", "TOWER_TIP_4"]

var _parts_label: Label
var _integrity_label: Label
var _wave_label: Label
var _enemies_label: Label
var _preview_label: Label
var _boss_banner: Label
var _start_button: Button
var _overlay: CenterContainer
var _overlay_message: Label
var _overlay_restart: Button
var _overlay_next_map: Button
var _tower_buttons: Array[Button] = []
var _hero_panel: VBoxContainer
var _hero_hint: Label
var _toast_label: Label

var _pause_overlay: Control
var _settings_overlay: Control
var _settings_panel_node: TDSettingsPanel
var _pause_was_open: bool = false
var _flash_rect: ColorRect
var _font_texts: Array[Control] = []
## Locale registry: [Object node, StringName property, String key] entries
## replayed when the language changes, then dynamic labels rerender below.
var _locale_texts: Array[Array] = []
## Last-seen dynamic state so a mid-run language switch rerenders the HUD.
var _status_parts: int = 0
var _status_integrity: int = 0
var _status_wave: int = 1
var _status_max_waves: int = 1
var _enemies_count: int = 0
var _preview_text: String = ""
var _combat_active: bool = false
var _can_chain: bool = false
var _result_shown: bool = false
var _result_won: bool = false
var _result_parts: int = 0


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
	_enemies_label = Label.new()
	_preview_label = Label.new()
	_style_text(_preview_label, "font_size", 15)
	top.add_child(_parts_label)
	top.add_child(_integrity_label)
	top.add_child(_wave_label)
	top.add_child(_enemies_label)
	top.add_child(_preview_label)

	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)

	# Hero control card (approved feature, 2026-11-09): sits bottom-left above
	# the tower cards and shows only while the hero is deployed; the hint row
	# doubles as the onboarding for new players.
	var hero_row := HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hero_row)
	_hero_panel = VBoxContainer.new()
	_hero_panel.add_theme_constant_override("separation", 2)
	_hero_panel.visible = false
	hero_row.add_child(_hero_panel)
	var hero_status := Label.new()
	_style_text(hero_status, "font_size", 14)
	hero_status.add_theme_color_override("font_color", Color("#7fe3d8"))
	_hero_panel.add_child(hero_status)
	_register_locale_text(hero_status, &"text", "HERO_PANEL")
	_hero_hint = Label.new()
	_style_text(_hero_hint, "font_size", 12)
	_hero_hint.add_theme_color_override("font_color", Color("#5d6a74"))
	_hero_panel.add_child(_hero_hint)
	_register_locale_text(_hero_hint, &"text", "HERO_HINT")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom.add_child(buttons)

	for index: int in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(158.0, 58.0)
		button.focus_mode = Control.FOCUS_NONE
		_style_text(button, "font_size", 13)
		var kind: int = index
		button.pressed.connect(func () -> void: tower_selected.emit(kind))
		buttons.add_child(button)
		_tower_buttons.append(button)
		_register_locale_text(button, &"text", KIND_LABEL_KEYS[index])
		_register_locale_text(button, &"tooltip_text", KIND_TIP_KEYS[index])

	var start_row := HBoxContainer.new()
	start_row.alignment = BoxContainer.ALIGNMENT_END
	_start_button = Button.new()
	_start_button.focus_mode = Control.FOCUS_NONE
	_style_text(_start_button, "font_size", 16)
	_start_button.pressed.connect(func () -> void: start_wave_pressed.emit())
	start_row.add_child(_start_button)
	bottom.add_child(start_row)
	_refresh_start_button()

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
	_overlay_restart.focus_mode = Control.FOCUS_NONE
	_style_text(_overlay_restart, "font_size", 16)
	_overlay_restart.pressed.connect(func () -> void: restart_pressed.emit())
	overlay_stack.add_child(_overlay_restart)
	_register_locale_text(_overlay_restart, &"text", "RESTART_BTN")

	# Next-map entry: only a map-1 victory swaps this button on.
	_overlay_next_map = Button.new()
	_overlay_next_map.focus_mode = Control.FOCUS_NONE
	_style_text(_overlay_next_map, "font_size", 16)
	_overlay_next_map.pressed.connect(func () -> void: next_map_pressed.emit())
	_overlay_next_map.visible = false
	overlay_stack.add_child(_overlay_next_map)
	_register_locale_text(_overlay_next_map, &"text", "NEXT_MAP_BTN")

	var overlay_title := Button.new()
	overlay_title.focus_mode = Control.FOCUS_NONE
	_style_text(overlay_title, "font_size", 16)
	overlay_title.pressed.connect(func () -> void: title_pressed.emit())
	overlay_stack.add_child(overlay_title)
	_register_locale_text(overlay_title, &"text", "MAIN_MENU_BTN")

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
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(pause_title, "font_size", 20)
	pause_stack.add_child(pause_title)
	_register_locale_text(pause_title, &"text", "PAUSED")

	var resume_btn := Button.new()
	resume_btn.focus_mode = Control.FOCUS_NONE
	_style_text(resume_btn, "font_size", 16)
	resume_btn.pressed.connect(func () -> void: resume_pressed.emit())
	pause_stack.add_child(resume_btn)
	_register_locale_text(resume_btn, &"text", "RESUME_BTN")

	var restart_pause_btn := Button.new()
	restart_pause_btn.focus_mode = Control.FOCUS_NONE
	_style_text(restart_pause_btn, "font_size", 16)
	restart_pause_btn.pressed.connect(func () -> void: restart_pressed.emit())
	pause_stack.add_child(restart_pause_btn)
	_register_locale_text(restart_pause_btn, &"text", "RESTART_MISSION_BTN")

	var settings_btn := Button.new()
	settings_btn.focus_mode = Control.FOCUS_NONE
	_style_text(settings_btn, "font_size", 16)
	settings_btn.pressed.connect(_open_settings)
	pause_stack.add_child(settings_btn)
	_register_locale_text(settings_btn, &"text", "SETTINGS")

	var title_btn := Button.new()
	title_btn.focus_mode = Control.FOCUS_NONE
	_style_text(title_btn, "font_size", 16)
	title_btn.pressed.connect(func () -> void: title_pressed.emit())
	pause_stack.add_child(title_btn)
	_register_locale_text(title_btn, &"text", "TITLE_MENU_BTN")

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
	_status_parts = parts
	_status_integrity = integrity
	_status_wave = wave
	_status_max_waves = max_waves
	_parts_label.text = tr("HUD_MONEY") % parts
	_integrity_label.text = tr("HUD_INTEGRITY") % integrity
	_wave_label.text = tr("HUD_WAVE") % [wave, max_waves]


## Hero card visibility follows the hero's deployed state (td_run calls this
## right from spawn/recall on the approved hero feature).
func set_hero_active(active: bool) -> void:
	if _hero_panel != null:
		_hero_panel.visible = active


## Transient bottom-center line for per-tower feedback (targeting mode
## changes): event-driven only, fades out on its own.
func show_targeting_toast(text: String) -> void:
	if _toast_label == null:
		_toast_label = Label.new()
		_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_toast_label.anchor_top = 0.78
		_toast_label.anchor_bottom = 0.78
		_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_text(_toast_label, "font_size", 15)
		_toast_label.add_theme_color_override("font_color", Color("#dfe9e2"))
		add_child(_toast_label)
	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func () -> void:
		if _toast_label != null and is_instance_valid(_toast_label):
			_toast_label.visible = false)


## GDD: HUD แสดงปริมาณ enemy ทยอย spawn. Hidden outside combat.
func set_enemies_left(count: int) -> void:
	_enemies_count = count
	if count <= 0:
		_enemies_label.text = ""
	else:
		_enemies_label.text = tr("HUD_ENEMIES_LEFT") % count


## Boss telegraph: a readable on-screen warning with a brief highlight pulse.
func announce_boss(text: String) -> void:
	var store := get_node_or_null("/root/TDSettings") as TDSettingsStore
	var reduce_flashes: bool = store != null and store.get_reduce_flashes()
	var reduce_motion: bool = store != null and store.get_reduce_motion()
	if _boss_banner == null:
		_boss_banner = Label.new()
		_boss_banner.name = "BossBanner"
		_boss_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_boss_banner.anchor_top = 0.24
		_boss_banner.anchor_bottom = 0.24
		_boss_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_boss_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_text(_boss_banner, "font_size", 26)
		add_child(_boss_banner)
	_boss_banner.text = text
	_boss_banner.visible = true
	_boss_banner.modulate = Color.WHITE
	var tween := create_tween()
	var peak: float = 0.55 if reduce_flashes else 1.0
	var pulse_count: int = 1 if reduce_motion else 3
	for _pulse: int in range(pulse_count):
		tween.tween_property(_boss_banner, "modulate", Color(1.0, 0.4, 0.25, peak), 0.35)
		tween.tween_property(_boss_banner, "modulate", Color.WHITE, 0.35)
	tween.tween_property(_boss_banner, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.6)
	tween.tween_callback(func () -> void:
		_boss_banner.visible = false)


func show_wave_preview(composition_text: String) -> void:
	_preview_text = composition_text
	_preview_label.text = tr("HUD_NEXT") % composition_text


## is_combat_active gates the prep button; can_chain enables summoning the
## next wave while the current one is still running (GDD wave chaining).
func set_combat_state(is_combat_active: bool, can_chain: bool = false) -> void:
	_combat_active = is_combat_active
	_can_chain = can_chain
	_refresh_start_button()


func _refresh_start_button() -> void:
	if _start_button == null:
		return
	_start_button.disabled = _combat_active and not _can_chain
	if _combat_active:
		_start_button.text = tr("CHAIN_WAVE_BTN") if _can_chain else tr("WAVE_RUNNING_BTN")
	else:
		_start_button.text = tr("START_WAVE_BTN")


## Override the four tower cards (label + tooltip) with data-driven text:
## stats per level from the tower .tres, so power/pricing show in-game.
func set_tower_cards(labels: Array[String], tooltips: Array[String]) -> void:
	for index: int in range(mini(labels.size(), _tower_buttons.size())):
		_tower_buttons[index].text = labels[index]
		_tower_buttons[index].tooltip_text = tooltips[index]


func show_result(won: bool, parts_at_end: int, can_advance: bool = false) -> void:
	_result_shown = true
	_result_won = won
	_result_parts = parts_at_end
	_overlay.visible = true
	_overlay_message.text = tr("RESULT_WON") if won else tr("RESULT_LOST") % parts_at_end
	if _overlay_next_map != null:
		_overlay_next_map.visible = can_advance


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

## Set a property to its translated value now and register it so language
## switches rerender static texts. Dynamic labels rerender from stored state.
func _register_locale_text(node: Object, prop: StringName, key: String) -> void:
	node.set(prop, tr(key))
	_locale_texts.append([node, prop, key])


func _apply_locale_texts() -> void:
	for entry: Array in _locale_texts:
		var node: Object = entry[0]
		if is_instance_valid(node):
			node.set(entry[1], tr(entry[2]))
	_refresh_start_button()
	if _status_parts != 0 or _status_integrity != 0:
		update_status(_status_parts, _status_integrity, _status_wave, _status_max_waves)
	set_enemies_left(_enemies_count)
	if _preview_text != "":
		show_wave_preview(_preview_text)
	if _result_shown:
		show_result(_result_won, _result_parts)


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
	elif section == &"localization" and key == &"locale":
		_apply_locale_texts()
