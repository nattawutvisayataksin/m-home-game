extends Control
class_name TDTitleMenu

## Title menu: start mission, how-to-play, story and quit. Thai-first copy,
## built in code so the greybox can iterate on wording without scene edits.

const RUN_SCENE_PATH := "res://scenes/gameplay/run.tscn"
const LOGO_TEXTURE := preload("res://assets/brand/logo_emblem.svg")

## Long copy lives in assets/localization/translations.csv (HOW_TO_BODY /
## STORY_BODY) so the language switch rerenders these panels live.
const HOW_TO_KEY := "HOW_TO_BODY"
const STORY_KEY := "STORY_BODY"

var _menu_root: VBoxContainer
var _subtitle: Label
var _how_panel: Control
var _story_panel: Control
var _settings_panel: Control
var _font_texts: Array[Control] = []
## Locale registry: [Object node, StringName property, String key] entries
## replayed when the language changes; dynamic formats live in _refreshers.
var _locale_texts: Array[Array] = []
var _locale_refreshers: Array[Callable] = []
var _profile_label: Label
var _barricade_button: Button
var _barricade_line: Label
var _meta_feedback: Label
var _continue_button: Button
var _snapshot_wave: int = 0
var _repo: ProfileRepository

# Meta progression: mirror the 2D project's barricade economy (30/70, cap 2).
const BARRICADE_COSTS: Array[int] = [30, 70]


func _ready() -> void:
	# Back at the title means a fresh map provenance (a resuming snapshot
	# re-pins its own map in the run's _apply_map_layout).
	TDMapSession.reset()
	_repo = ProfileRepository.new()
	_build_background()
	_build_title_column()
	_how_panel = _build_content_panel(HOW_TO_KEY)
	_story_panel = _build_content_panel(STORY_KEY)
	_settings_panel = _build_settings_overlay()
	var store := _store()
	if store != null:
		store.settings_changed.connect(_on_settings_changed)


## Test seam: swap the repository (e.g. temp path) so tests never touch
## the player's real profile.json.
func set_profile_repository(repo: ProfileRepository) -> void:
	_repo = repo
	_refresh_profile_row()


func _store() -> TDSettingsStore:
	return get_node_or_null("/root/TDSettings") as TDSettingsStore


func _build_background() -> void:
	# Vertical brand gradient (#141826 -> #0d1118) per MARKETING.md palette.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#151a29"), Color("#0d1118"), Color("#0a0d13")])
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(0.0, 1.0)
	var background := TextureRect.new()
	background.name = "Background"
	background.texture = gradient_texture
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Faint amber lamp glow rising from the bottom ("แสงสุดท้าย" motif).
	var glow_gradient := Gradient.new()
	glow_gradient.colors = PackedColorArray([Color(1.0, 0.85, 0.54, 0.12), Color(1.0, 0.85, 0.54, 0.0)])
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = glow_gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(0.5, 0.0)
	glow_texture.width = 512
	glow_texture.height = 256
	var glow := TextureRect.new()
	glow.name = "FloorGlow"
	glow.texture = glow_texture
	glow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	glow.offset_left = -420.0
	glow.offset_right = 420.0
	glow.offset_top = -300.0
	glow.offset_bottom = 28.0
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(glow)


func _build_title_column() -> void:
	var column := VBoxContainer.new()
	column.name = "MainColumn"
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.offset_left = -300.0
	column.offset_right = 300.0
	column.offset_top = -400.0
	column.offset_bottom = 316.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = LOGO_TEXTURE
	logo.custom_minimum_size = Vector2(0.0, 148.0)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(logo)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(_subtitle, "font_size", 26)
	_subtitle.add_theme_color_override("font_color", Color("#dfe9e2"))
	column.add_child(_subtitle)
	_register_locale_text(_subtitle, &"text", "TITLE_SUBTITLE")

	var tagline := Label.new()
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(tagline, "font_size", 16)
	tagline.add_theme_color_override("font_color", Color("#9fb2a8"))
	column.add_child(tagline)
	_register_locale_text(tagline, &"text", "TAGLINE")

	# Brand rule + feature strip: sell the pillars at a glance.
	var rule := ColorRect.new()
	rule.color = Color(0.91, 0.66, 0.36, 0.45)
	rule.custom_minimum_size = Vector2(240.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rule)

	var feature_strip := Label.new()
	feature_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(feature_strip, "font_size", 14)
	feature_strip.add_theme_color_override("font_color", Color("#e8c27d"))
	column.add_child(feature_strip)
	_register_locale_text(feature_strip, &"text", "FEATURE_STRIP")

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	column.add_child(spacer)

	_add_menu_button(column, "START_MISSION", _start_mission)
	_add_menu_button(column, "HOW_TO", func () -> void: _show_panel(_how_panel))
	_add_menu_button(column, "STORY", func () -> void: _show_panel(_story_panel))
	_add_menu_button(column, "SETTINGS", func () -> void: _show_panel(_settings_panel))
	_add_menu_button(column, "QUIT", func () -> void: get_tree().quit())

	# Flash-save resume: shown only when a valid snapshot is on disk.
	_snapshot_wave = TDSessionSnapshot.get_resume_wave()
	if _snapshot_wave > 0:
		var continue_button := _add_menu_button(
			column,
			"",
			_continue_mission
		)
		# The resume entry sits right above the fresh-start button so a
		# returning player finds it first.
		column.move_child(continue_button, 6)
		_continue_button = continue_button
		_locale_refreshers.append(_refresh_continue_button)
		_refresh_continue_button()

	_build_footer()


func _build_footer() -> void:
	var footer := MarginContainer.new()
	footer.name = "Footer"
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -108.0
	footer.offset_bottom = -16.0
	footer.add_theme_constant_override("margin_left", 56.0)
	footer.add_theme_constant_override("margin_right", 56.0)
	add_child(footer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	footer.add_child(row)

	# Left: base panel — a titled block so the player can tell at a glance
	# what the row is for (profile readout + the permanent Barricade upgrade).
	var profile_box := VBoxContainer.new()
	profile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	profile_box.add_theme_constant_override("separation", 5)
	row.add_child(profile_box)

	var meta_title := Label.new()
	_style_text(meta_title, "font_size", 13)
	meta_title.add_theme_color_override("font_color", Color("#c9a25c"))
	profile_box.add_child(meta_title)
	_register_locale_text(meta_title, &"text", "META_TITLE")

	_profile_label = Label.new()
	_profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_text(_profile_label, "font_size", 14)
	_profile_label.add_theme_color_override("font_color", Color("#9fb2a8"))
	profile_box.add_child(_profile_label)

	# One concrete sentence: what the Barricade level changes, in numbers.
	_barricade_line = Label.new()
	_barricade_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_text(_barricade_line, "font_size", 13)
	_barricade_line.add_theme_color_override("font_color", Color("#8a9bb0"))
	profile_box.add_child(_barricade_line)

	_barricade_button = Button.new()
	_barricade_button.custom_minimum_size = Vector2(330.0, 42.0)
	_barricade_button.focus_mode = Control.FOCUS_ALL
	_style_text(_barricade_button, "font_size", 15)
	_barricade_button.add_theme_color_override("font_color", Color("#dfe9e2"))
	_barricade_button.add_theme_color_override("font_hover_color", Color("#ffd98a"))
	_barricade_button.add_theme_color_override("font_pressed_color", Color("#ffd98a"))
	_barricade_button.add_theme_color_override("font_focus_color", Color("#ffd98a"))
	_barricade_button.add_theme_stylebox_override("normal", _menu_style(Color("#1a2130"), Color("#3a4252")))
	_barricade_button.add_theme_stylebox_override("hover", _menu_style(Color("#33291a"), Color("#e8a95c")))
	_barricade_button.add_theme_stylebox_override("pressed", _menu_style(Color("#241d12"), Color("#b9863f")))
	_barricade_button.add_theme_stylebox_override("focus", _menu_style(Color("#2b2417"), Color("#ffd98a")))
	_barricade_button.pressed.connect(_upgrade_barricade)
	profile_box.add_child(_barricade_button)
	_register_locale_text(_barricade_button, &"tooltip_text", "BARRICADE_TOOLTIP")

	# Missing-funds feedback: a short message instead of a silently dead
	# button, so "nothing happened" never becomes the player's conclusion.
	_meta_feedback = Label.new()
	_meta_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_meta_feedback.visible = false
	_style_text(_meta_feedback, "font_size", 13)
	_meta_feedback.add_theme_color_override("font_color", Color("#e07a66"))
	profile_box.add_child(_meta_feedback)
	_refresh_profile_row()

	# Center: brand slogan + build tag.
	var center_box := VBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.alignment = BoxContainer.ALIGNMENT_END
	center_box.add_theme_constant_override("separation", 3)
	row.add_child(center_box)

	var slogan := Label.new()
	slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(slogan, "font_size", 14)
	slogan.add_theme_color_override("font_color", Color("#8a7a5c"))
	center_box.add_child(slogan)
	_register_locale_text(slogan, &"text", "SLOGAN")

	var version := Label.new()
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(version, "font_size", 12)
	version.add_theme_color_override("font_color", Color("#5d6a74"))
	center_box.add_child(version)
	_register_locale_text(version, &"text", "BUILD_TAG")


# --- Meta progression: profile row + Barricade purchase --------------------

## Sample the real profile for the footer readout; repo may be swapped by
## tests through set_profile_repository().
func _refresh_profile_row() -> void:
	if _profile_label == null or _barricade_button == null or _barricade_line == null:
		return
	var profile: Dictionary = _repo.load_profile()
	var salvage: int = int(profile.get("salvage", 0))
	var level: int = clampi(int(profile.get("barricade_level", 0)), 0, ProfileRepository.MAX_BARRICADE_LEVEL)
	_profile_label.text = tr("PROFILE_ROW") % [
		salvage, int(profile.get("victories", 0)), int(profile.get("best_wave", 1)),
	]
	# Plain-numbers effect line: level X of Y, and the Integrity the Shelter
	# actually opens each night with (single source: TDRun.START_INTEGRITY).
	var max_level: int = ProfileRepository.MAX_BARRICADE_LEVEL
	_barricade_line.text = tr("BARRICADE_EFFECT") % [level, max_level, TDRun.START_INTEGRITY + level * 2]
	if _meta_feedback != null:
		_meta_feedback.visible = false
	if level >= max_level:
		_barricade_button.text = tr("BARRICADE_MAX") % level
		_barricade_button.disabled = true
		return
	var cost: int = BARRICADE_COSTS[level]
	_barricade_button.text = tr("BARRICADE_BUY") % [level + 1, cost]
	# The button stays clickable even on short funds: the click itself then
	# reports what is missing on screen (dead disabled state taught nothing).
	_barricade_button.disabled = false


func _upgrade_barricade() -> void:
	if not _upgrade_barricade_profile():
		_report_purchase_blocker()


## Pure meta-progression math over the profile dict; returns true on success.
func _upgrade_barricade_profile() -> bool:
	var profile: Dictionary = _repo.load_profile()
	var level: int = clampi(int(profile.get("barricade_level", 0)), 0, ProfileRepository.MAX_BARRICADE_LEVEL)
	if level >= ProfileRepository.MAX_BARRICADE_LEVEL:
		return false
	var cost: int = BARRICADE_COSTS[level]
	if int(profile.get("salvage", 0)) < cost:
		return false
	profile["salvage"] = int(profile["salvage"]) - cost
	profile["barricade_level"] = level + 1
	var save_error: Error = _repo.save_profile(profile)
	if save_error != OK:
		push_warning("Title menu: barricade purchase save failed (%s)." % error_string(save_error))
		_refresh_profile_row()
		return false
	_refresh_profile_row()
	return true


## Explains a failed purchase on screen, briefly: how much Salvage is missing.
func _report_purchase_blocker() -> void:
	if _meta_feedback == null:
		return
	var profile: Dictionary = _repo.load_profile()
	var level: int = clampi(int(profile.get("barricade_level", 0)), 0, ProfileRepository.MAX_BARRICADE_LEVEL)
	if level >= ProfileRepository.MAX_BARRICADE_LEVEL:
		return
	var missing: int = maxi(BARRICADE_COSTS[level] - int(profile.get("salvage", 0)), 0)
	if missing <= 0:
		return  # save failure path: the warning push already covers it
	_meta_feedback.text = tr("BARRICADE_SHORT") % missing
	_meta_feedback.visible = true
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func () -> void:
		if _meta_feedback != null and is_instance_valid(_meta_feedback):
			_meta_feedback.visible = false)


func _add_menu_button(vbox: VBoxContainer, key: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(340.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	_style_text(button, "font_size", 22)
	button.add_theme_color_override("font_color", Color("#dfe9e2"))
	button.add_theme_color_override("font_hover_color", Color("#ffd98a"))
	button.add_theme_color_override("font_pressed_color", Color("#ffd98a"))
	button.add_theme_color_override("font_focus_color", Color("#ffd98a"))
	button.add_theme_stylebox_override("normal", _menu_style(Color("#1a2130"), Color("#3a4252")))
	button.add_theme_stylebox_override("hover", _menu_style(Color("#33291a"), Color("#e8a95c")))
	button.add_theme_stylebox_override("pressed", _menu_style(Color("#241d12"), Color("#b9863f")))
	button.add_theme_stylebox_override("focus", _menu_style(Color("#2b2417"), Color("#ffd98a")))
	button.pressed.connect(on_pressed)
	vbox.add_child(button)
	# Menu buttons hold a plain key; formatted texts use a refresher instead.
	if key != "":
		_register_locale_text(button, &"text", key)
	return button


## Formatted resume label; rerendered through _locale_refreshers on switch.
func _refresh_continue_button() -> void:
	if _continue_button != null and is_instance_valid(_continue_button):
		_continue_button.text = tr("CONTINUE_MISSION") % (_snapshot_wave + 1)


func _menu_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _build_content_panel(bb_key: String) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "ContentPanel"
	overlay.color = Color(0.05, 0.06, 0.09, 0.96)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 30)
	overlay.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = true
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", _text_size(21))
	column.add_child(label)
	# Long copy rerenders on locale switch so the panel body follows too.
	_register_locale_text(label, &"text", bb_key)

	var bottom_row := HBoxContainer.new()
	column.add_child(bottom_row)
	var back := Button.new()
	back.custom_minimum_size = Vector2(220.0, 46.0)
	_style_text(back, "font_size", 19)
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(_close_panels)
	bottom_row.add_child(back)
	_register_locale_text(back, &"text", "BACK_BTN")

	overlay.visible = false
	overlay.set_meta("back_button", back)
	return overlay


func _show_panel(panel: Control) -> void:
	if panel == null:
		return
	_close_panels()
	panel.visible = true
	var back: Button = panel.get_meta("back_button")
	if back != null:
		back.grab_focus()


func _close_panels() -> void:
	if _how_panel != null:
		_how_panel.visible = false
	if _story_panel != null:
		_story_panel.visible = false
	if _settings_panel != null:
		_settings_panel.visible = false


func panels_open() -> bool:
	var any_open: bool = (_how_panel != null and _how_panel.visible) \
		or (_story_panel != null and _story_panel.visible) \
		or (_settings_panel != null and _settings_panel.visible)
	return any_open


# --- Settings overlay -----------------------------------------------------

func _build_settings_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "SettingsPanel"
	overlay.color = Color(0.05, 0.06, 0.09, 0.96)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := PanelContainer.new()
	center.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	box.add_child(margin)

	var panel := TDSettingsPanel.new()
	panel.closed.connect(_close_panels)
	margin.add_child(panel)

	overlay.visible = false
	overlay.set_meta("back_button", panel.back_button)
	return overlay


# --- Text scaling (large text option) + locale refresh ---------------------

## Set a property to its translated value now and register it for locale
## switches — open panels rerender live (same rule as the large-text option).
func _register_locale_text(node: Object, prop: StringName, key: String) -> void:
	node.set(prop, tr(key))
	_locale_texts.append([node, prop, key])


func _apply_locale_texts() -> void:
	for entry: Array in _locale_texts:
		var node: Object = entry[0]
		if is_instance_valid(node):
			node.set(entry[1], tr(entry[2]))
	for refresher: Callable in _locale_refreshers:
		refresher.call()
	_refresh_profile_row()


func _style_text(node: Control, theme_item: String, base_size: int) -> void:
	node.add_theme_font_size_override(theme_item, _text_size(base_size))
	node.set_meta(&"font_item", theme_item)
	node.set_meta(&"font_base", base_size)
	_font_texts.append(node)


func _text_size(base_size: int) -> int:
	var store := _store()
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE:
			_close_panels()


func _start_mission() -> void:
	get_tree().change_scene_to_file(RUN_SCENE_PATH)


func _continue_mission() -> void:
	TDSessionSnapshot.resume_requested = true
	get_tree().change_scene_to_file(RUN_SCENE_PATH)
