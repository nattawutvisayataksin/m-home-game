class_name TDSettingsPanel
extends VBoxContainer

## Shared settings UI (audio volume + accessibility toggles + language)
## driven by the TDSettings autoload store. Instantiated by the title menu and
## the pause menu; every change takes effect immediately and persists to
## settings.cfg. All user-facing text goes through tr(KEY) so the Thai/English
## switch rerenders this panel live through the locale registry below.

signal closed

const LOCALE_ENGLISH_INDEX: int = 0
const LOCALE_THAI_INDEX: int = 1

var back_button: Button

var _store: TDSettingsStore
var _font_texts: Array[Control] = []
## Locale registry: [Object node, StringName property, String key] entries
## replayed whenever the language changes so open panels rerender at once.
var _locale_texts: Array[Array] = []
var _language_option: OptionButton


func _ready() -> void:
	_store = get_node_or_null("/root/TDSettings") as TDSettingsStore
	if _store == null:
		# Store autoload missing (check-only scripts, stray scene loads): stay empty.
		push_warning("TDSettings autoload missing; settings panel disabled.")
		return
	add_theme_constant_override("separation", 10)
	_build_title()
	_build_volume_row(
		"MASTER_VOLUME",
		_store.get_master_volume_db(),
		func (value_db: float) -> void: _store.set_master_volume_db(value_db)
	)
	_build_volume_row(
		"SFX_VOLUME",
		_store.get_sfx_volume_db(),
		func (value_db: float) -> void: _store.set_sfx_volume_db(value_db)
	)
	_build_volume_row(
		"MUSIC_VOLUME",
		_store.get_music_volume_db(),
		func (value_db: float) -> void: _store.set_music_volume_db(value_db)
	)
	_build_toggle("REDUCE_FLASHES", _store.get_reduce_flashes(), _store.set_reduce_flashes)
	_build_toggle("REDUCE_MOTION", _store.get_reduce_motion(), _store.set_reduce_motion)
	_build_toggle("LARGE_TEXT", _store.get_large_text(), _store.set_large_text)
	_build_language_row()
	_build_back_row()

	_store.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if _store != null:
		_store.settings_changed.disconnect(_on_settings_changed)


func _build_title() -> void:
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(title_label, "font_size", 24)
	add_child(title_label)
	_register_locale_text(title_label, &"text", "SETTINGS_TITLE")


func _build_volume_row(key: String, initial_db: float, on_changed: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
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
	_register_locale_text(name_label, &"text", key)


func _build_toggle(key: String, initial: bool, on_toggled: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.button_pressed = initial
	toggle.toggled.connect(on_toggled)
	_style_text(toggle, "font_size", 16)
	add_child(toggle)
	_register_locale_text(toggle, &"text", key)


## Language picker — pattern mirrors the 2D title screen: an OptionButton
## writing "th"/"en" through the store, selection synced on locale changes.
func _build_language_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(210.0, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_text(name_label, "font_size", 16)
	row.add_child(name_label)
	_register_locale_text(name_label, &"text", "LANGUAGE")

	_language_option = OptionButton.new()
	_language_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Each option shows its own language name (explanatory in both locales);
	# pattern matches the 2D title screen.
	_language_option.add_item(tr("ENGLISH"), LOCALE_ENGLISH_INDEX)
	_language_option.add_item(tr("THAI"), LOCALE_THAI_INDEX)
	_language_option.item_selected.connect(_on_language_selected)
	# The two option labels never change with the locale (each shows its own
	# language name, self-explanatory in both UI languages).
	_style_text(_language_option, "font_size", 16)
	row.add_child(_language_option)
	add_child(row)
	_sync_language_option()


func _build_back_row() -> void:
	var back := Button.new()
	back.custom_minimum_size = Vector2(220.0, 46.0)
	back.focus_mode = Control.FOCUS_ALL
	_style_text(back, "font_size", 18)
	back.pressed.connect(func () -> void: closed.emit())
	add_child(back)
	back_button = back
	_register_locale_text(back, &"text", "BACK_BTN")


func _on_language_selected(index: int) -> void:
	_store.set_locale("th" if index == LOCALE_THAI_INDEX else "en")


## Update the picker selection without emitting item_selected back.
func _sync_language_option() -> void:
	if _language_option == null:
		return
	_language_option.select(LOCALE_THAI_INDEX if _store.get_locale().begins_with("th") else LOCALE_ENGLISH_INDEX)


# --- Locale refresh --------------------------------------------------------

## Set a property to its translated value now and register it for later
## locale switches (open panels rerender live, matching the large-text rule).
func _register_locale_text(node: Object, prop: StringName, key: String) -> void:
	node.set(prop, tr(key))
	_locale_texts.append([node, prop, key])


func _apply_locale_texts() -> void:
	if _language_option != null:
		_sync_language_option()
	for entry: Array in _locale_texts:
		var node: Object = entry[0]
		if is_instance_valid(node):
			node.set(entry[1], tr(entry[2]))


# --- Text scaling (large text option) -------------------------------------

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
	if section == &"accessibility" and key == &"large_text":
		for node: Control in _font_texts:
			if is_instance_valid(node):
				var item := str(node.get_meta(&"font_item"))
				var base_size := int(node.get_meta(&"font_base"))
				node.add_theme_font_size_override(item, _text_size(base_size))
	elif section == &"localization" and key == &"locale":
		_apply_locale_texts()
