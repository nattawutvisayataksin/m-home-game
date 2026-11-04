class_name TDSettingsPanel
extends VBoxContainer

## Shared settings UI (audio volume + accessibility toggles) driven by the
## TDSettings autoload store. Instantiated by the title menu and the pause
## menu; every change takes effect immediately and persists to settings.cfg.

signal closed

var back_button: Button

var _store: TDSettingsStore
var _font_texts: Array[Control] = []


func _ready() -> void:
	_store = get_node_or_null("/root/TDSettings") as TDSettingsStore
	if _store == null:
		# Store autoload missing (check-only scripts, stray scene loads): stay empty.
		push_warning("TDSettings autoload missing; settings panel disabled.")
		return
	add_theme_constant_override("separation", 10)
	_build_title()
	_build_volume_row(
		"เสียงหลัก (Master)",
		_store.get_master_volume_db(),
		func (value_db: float) -> void: _store.set_master_volume_db(value_db)
	)
	_build_volume_row(
		"เสียงเอฟเฟกต์ (SFX)",
		_store.get_sfx_volume_db(),
		func (value_db: float) -> void: _store.set_sfx_volume_db(value_db)
	)
	_build_volume_row(
		"เสียงเพลง (Music)",
		_store.get_music_volume_db(),
		func (value_db: float) -> void: _store.set_music_volume_db(value_db)
	)
	_build_toggle("ลดแสงวาบหน้าจอ (Reduce flashes)", _store.get_reduce_flashes(), _store.set_reduce_flashes)
	_build_toggle("ลดการเคลื่อนไหว (Reduce motion)", _store.get_reduce_motion(), _store.set_reduce_motion)
	_build_toggle("ข้อความขนาดใหญ่ (Large text)", _store.get_large_text(), _store.set_large_text)

	var back := Button.new()
	back.text = "ย้อนกลับ (Esc)"
	back.custom_minimum_size = Vector2(220.0, 46.0)
	back.focus_mode = Control.FOCUS_ALL
	_style_text(back, "font_size", 18)
	back.pressed.connect(func () -> void: closed.emit())
	add_child(back)
	back_button = back

	_store.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if _store != null:
		_store.settings_changed.disconnect(_on_settings_changed)


func _build_title() -> void:
	var title_label := Label.new()
	title_label.text = "ตั้งค่า / Settings"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(title_label, "font_size", 24)
	add_child(title_label)


func _build_volume_row(label_text: String, initial_db: float, on_changed: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(210.0, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_text(name_label, "font_size", 16)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 6.0
	slider.step = 1.0
	slider.value = initial_db
	slider.custom_minimum_size = Vector2(240.0, 24.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_changed)
	row.add_child(slider)

	add_child(row)


func _build_toggle(label_text: String, initial: bool, on_toggled: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = initial
	toggle.toggled.connect(on_toggled)
	_style_text(toggle, "font_size", 16)
	add_child(toggle)


func _style_text(node: Control, theme_item: String, base_size: int) -> void:
	node.add_theme_font_size_override(theme_item, _text_size(base_size))
	node.set_meta(&"font_item", theme_item)
	node.set_meta(&"font_base", base_size)
	_font_texts.append(node)


func _text_size(base_size: int) -> int:
	if _store == null:
		return base_size
	return _store.ui_font_size(base_size)


func _on_settings_changed(section: StringName, key: StringName) -> void:
	if section != &"accessibility" or key != &"large_text":
		return
	for node: Control in _font_texts:
		if is_instance_valid(node):
			var item := str(node.get_meta(&"font_item"))
			var base_size := int(node.get_meta(&"font_base"))
			node.add_theme_font_size_override(item, _text_size(base_size))
