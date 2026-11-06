extends Control
class_name TDTitleMenu

## Title menu: start mission, how-to-play, story and quit. Thai-first copy,
## built in code so the greybox can iterate on wording without scene edits.

const RUN_SCENE_PATH := "res://scenes/gameplay/run.tscn"
const LOGO_TEXTURE := preload("res://assets/brand/logo_emblem.svg")

const HOW_TO_PLAY := """[color=#e8c27d]วิธีการเล่น[/color]

1. เตรียมตัวก่อนเปิดคลื่น — คลิกซ้ายที่จุดวาง (จุดสีเหลือง) เพื่อวางป้อม ใช้ปุ่ม 1/2/3/4 เลือกชนิด:
   [b]1[/b] Field Turret ยิงเดี่ยวรวดเร็ว (80 เงิน)
   [b]2[/b] Sonic Resonator ระเบิดวงกว้าง (120 เงิน)
   [b]3[/b] Tangle Emitter ช้าศัตรูในรัศมี (60 เงิน)
   [b]4[/b] Arc Cannon ลูกใหญ่ระเบิดแรง ระยะไกล (140 เงิน)
2. คลิกซ้ายที่ป้อมที่วางไว้แล้ว = อัปเกรด (สูงสุด Lv2 — เอาเมาส์ชี้ป้อมเพื่อดูพลังแต่ละระดับและราคา) — คลิกขวาที่ป้อม = ขายคืน 70%
3. กด Space หรือปุ่ม Start Wave เพื่อเปิดคลื่น — จะกดเรียกคลื่นต่อไปเลยระหว่างคลื่นก็ได้ ไม่ต้องรอคลื่นเดิมจบ (อันตรายแต่รางวัลไหลเร็ว)
4. กด Esc เพื่อหยุดชั่วคราว — ปิดเกมกลางรอบที่มีความคืบหน้า เมื่อเปิดใหม่จะมีปุ่ม "เล่นต่อจากภารกิจค้าง" รออยู่
5. ศัตรูที่ลอดผ่านป้อมจะลด Shelter Integrity ถ้าหมด แปลว่าแพ้
6. กำจัดศัตรูได้เงิน จบคลื่นได้โบนัสตาม Integrity ที่เหลือ
7. เอาตัวรอดครบ 8 คลื่นจนจัดการ Rift Warden ได้ = ชนะ
8. นอกรอบ: Salvage ที่ได้จากการรบใช้อัปเกรด Barricade บนหน้าเมนูได้ — +2 Integrity ต่อระดับ สูงสุด Lv2 (ใช้กับคืนถัด ๆ ไป)"""

const STORY := """[color=#e8c27d]เรื่องราว[/color]

หลังคืนไร้ดาว โลกชายฝั่งล่มสลายเป็นเขตมืด ฝูง [b]Hollows[/b] ถูกดึงดูดด้วยความร้อนและเสียงของผู้รอดชีวิต และยกมาทุกคืนตามถนนที่ยังใช้ได้

[b]Shelter 09[/b] คือจุดยืนสุดท้ายที่ [color=#d6a453]ริน[/color] ช่างซ่อมระบบตั้งแนวรบเอาไว้ เสาส่งสัญญาณอพยพของ Shelter ยังติด และ [color=#d6a453]มีรา[/color] ผู้คุมวิทยุจากศูนย์อพยพบอกว่า ถ้ายืนรับคืนนี้ได้ ทีมกู้จะเลื่อนชั้นเส้นทางอพยพอีกหนึ่งเขต

รินหยุดยิงปิดถนนไม่ไหวอีกต่อไป จึงสะสมเศษ Salvage ไว้แปลงเป็นป้อม: ไรเฟิลดัดแปลง เครื่องส่งคลื่นจากเสาสัญญาณ และสายสลักพันเท้า แผนการรบของคุณสำคัญกว่าแต้มยิง

ฝูงกลุ่มใหญ่ที่สุดนำโดย [b]Rift Warden[/b] รออยู่ท้ายคืน"""

var _menu_root: VBoxContainer
var _subtitle: Label
var _how_panel: Control
var _story_panel: Control
var _settings_panel: Control
var _font_texts: Array[Control] = []
var _profile_label: Label
var _barricade_button: Button
var _repo: ProfileRepository

# Meta progression: mirror the 2D project's barricade economy (30/70, cap 2).
const BARRICADE_COSTS: Array[int] = [30, 70]


func _ready() -> void:
	_repo = ProfileRepository.new()
	_build_background()
	_build_title_column()
	_how_panel = _build_content_panel(HOW_TO_PLAY)
	_story_panel = _build_content_panel(STORY)
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
	_subtitle.text = "LAST LIGHT — แนวรบสุดท้าย"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(_subtitle, "font_size", 26)
	_subtitle.add_theme_color_override("font_color", Color("#dfe9e2"))
	column.add_child(_subtitle)

	var tagline := Label.new()
	tagline.text = "3D Tower Defense — ตั้งป้อม รับฝูง คุมคืนสุดท้าย"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(tagline, "font_size", 16)
	tagline.add_theme_color_override("font_color", Color("#9fb2a8"))
	column.add_child(tagline)

	# Brand rule + feature strip: sell the pillars at a glance.
	var rule := ColorRect.new()
	rule.color = Color(0.91, 0.66, 0.36, 0.45)
	rule.custom_minimum_size = Vector2(240.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rule)

	var feature_strip := Label.new()
	feature_strip.text = "คืนเดียว 8 คลื่น · ป้อม 4 แบบ · อัปเกรด Lv2 · ขายคืน 70%"
	feature_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(feature_strip, "font_size", 14)
	feature_strip.add_theme_color_override("font_color", Color("#e8c27d"))
	column.add_child(feature_strip)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	column.add_child(spacer)

	_add_menu_button(column, "เริ่มการรบ", _start_mission)
	_add_menu_button(column, "วิธีการเล่น", func () -> void: _show_panel(_how_panel))
	_add_menu_button(column, "เรื่องราว", func () -> void: _show_panel(_story_panel))
	_add_menu_button(column, "ตั้งค่า", func () -> void: _show_panel(_settings_panel))
	_add_menu_button(column, "ออกจากเกม", func () -> void: get_tree().quit())

	# Flash-save resume: shown only when a valid snapshot is on disk.
	var snapshot_wave: int = TDSessionSnapshot.get_resume_wave()
	if snapshot_wave > 0:
		var continue_button := _add_menu_button(
			column,
			"เล่นต่อจากภารกิจค้าง (คลื่น %d)" % (snapshot_wave + 1),
			_continue_mission
		)
		# The resume entry sits right above the fresh-start button so a
		# returning player finds it first.
		column.move_child(continue_button, 6)

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

	# Left: meta progression — salvage balance + Barricade upgrade purchase.
	var profile_box := VBoxContainer.new()
	profile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	profile_box.add_theme_constant_override("separation", 5)
	row.add_child(profile_box)

	_profile_label = Label.new()
	_profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_text(_profile_label, "font_size", 14)
	_profile_label.add_theme_color_override("font_color", Color("#9fb2a8"))
	profile_box.add_child(_profile_label)

	_barricade_button = Button.new()
	_barricade_button.custom_minimum_size = Vector2(330.0, 42.0)
	_barricade_button.focus_mode = Control.FOCUS_ALL
	_style_text(_barricade_button, "font_size", 15)
	_barricade_button.tooltip_text = "อัปเกรด Barricade — ยืนรักษาการสังเกตของ Shelter 09\n+2 Shelter Integrity ต่อระดับ (สูงสุด Lv2) ใช้กับคืนถัด ๆ ไป"
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
	_refresh_profile_row()

	# Center: brand slogan + build tag.
	var center_box := VBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.alignment = BoxContainer.ALIGNMENT_END
	center_box.add_theme_constant_override("separation", 3)
	row.add_child(center_box)

	var slogan := Label.new()
	slogan.text = "“แสงสุดท้าย คือแนวรบของเรา”"
	slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(slogan, "font_size", 14)
	slogan.add_theme_color_override("font_color", Color("#8a7a5c"))
	center_box.add_child(slogan)

	var version := Label.new()
	version.text = "เดโม่เทคนิค · Shelter 09 · build 2026-11-06"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(version, "font_size", 12)
	version.add_theme_color_override("font_color", Color("#5d6a74"))
	center_box.add_child(version)


# --- Meta progression: profile row + Barricade purchase --------------------

## Sample the real profile for the footer readout; repo may be swapped by
## tests through set_profile_repository().
func _refresh_profile_row() -> void:
	if _profile_label == null or _barricade_button == null:
		return
	var profile: Dictionary = _repo.load_profile()
	var salvage: int = int(profile.get("salvage", 0))
	var level: int = clampi(int(profile.get("barricade_level", 0)), 0, ProfileRepository.MAX_BARRICADE_LEVEL)
	_profile_label.text = "Salvage %d · ชนะ %d ครั้ง · คลื่นไกลสุด %d" % [
		salvage, int(profile.get("victories", 0)), int(profile.get("best_wave", 1)),
	]
	if level >= ProfileRepository.MAX_BARRICADE_LEVEL:
		_barricade_button.text = "Barricade Lv%d — สูงสุดแล้ว" % level
		_barricade_button.disabled = true
		return
	var cost: int = BARRICADE_COSTS[level]
	_barricade_button.text = "อัปเกรด Barricade → Lv%d (Salvage %d)" % [level + 1, cost]
	_barricade_button.disabled = salvage < cost


func _upgrade_barricade() -> void:
	if not _upgrade_barricade_profile():
		_refresh_profile_row()  # keep readout honest on max/refund paths


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


func _add_menu_button(vbox: VBoxContainer, label_text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
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
	return button


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


func _build_content_panel(bb_text: String) -> Control:
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
	label.text = bb_text
	label.fit_content = false
	label.scroll_active = true
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", _text_size(21))
	column.add_child(label)

	var bottom_row := HBoxContainer.new()
	column.add_child(bottom_row)
	var back := Button.new()
	back.text = "ย้อนกลับ (Esc)"
	back.custom_minimum_size = Vector2(220.0, 46.0)
	_style_text(back, "font_size", 19)
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(_close_panels)
	bottom_row.add_child(back)

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


# --- Text scaling (large text option) -------------------------------------

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
