class_name TDSettingsStore
extends Node

## Central settings store for the 3D build: owns user://settings.cfg and
## applies audio values to the AudioServer. Autoloaded as "TDSettings" so the
## title menu and pause menu write through one owner. Pattern mirrors the 2D
## build's settings.cfg (ConfigFile, sections audio/accessibility/localization)
## but is kept separate from ProfileRepository progression saves.

signal settings_changed(section: StringName, key: StringName)

const DEFAULT_MASTER_DB: float = 0.0
const DEFAULT_SFX_DB: float = 0.0
const DEFAULT_MUSIC_DB: float = -12.0
const LARGE_TEXT_DELTA: int = 4

## Overridable for tests; production path is user://settings.cfg.
var settings_path: String = "user://settings.cfg"

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var error: Error = _config.load(settings_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load settings: %s" % error_string(error))
	apply_audio_settings()
	settings_changed.emit(&"file", &"loaded")


func save_settings() -> void:
	var error: Error = _config.save(settings_path)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))


# --- Audio ----------------------------------------------------------------

func get_master_volume_db() -> float:
	return float(_config.get_value("audio", "master_db", DEFAULT_MASTER_DB))


func set_master_volume_db(value_db: float) -> void:
	_config.set_value("audio", "master_db", value_db)
	save_settings()
	apply_audio_settings()
	settings_changed.emit(&"audio", &"master_db")


func get_sfx_volume_db() -> float:
	return float(_config.get_value("audio", "sfx_db", DEFAULT_SFX_DB))


func set_sfx_volume_db(value_db: float) -> void:
	_config.set_value("audio", "sfx_db", value_db)
	save_settings()
	apply_audio_settings()
	settings_changed.emit(&"audio", &"sfx_db")


func get_music_volume_db() -> float:
	return float(_config.get_value("audio", "music_db", DEFAULT_MUSIC_DB))


func set_music_volume_db(value_db: float) -> void:
	_config.set_value("audio", "music_db", value_db)
	save_settings()
	apply_audio_settings()
	settings_changed.emit(&"audio", &"music_db")


## Applies stored values to buses that exist. Master is always index 0;
## SFX/Music buses arrive with the audio phase and are picked up automatically.
func apply_audio_settings() -> void:
	_set_bus_volume(0, get_master_volume_db())
	_set_bus_volume(AudioServer.get_bus_index("SFX"), get_sfx_volume_db())
	_set_bus_volume(AudioServer.get_bus_index("Music"), get_music_volume_db())


func _set_bus_volume(bus_index: int, volume_db: float) -> void:
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


# --- Accessibility --------------------------------------------------------

func get_reduce_flashes() -> bool:
	return bool(_config.get_value("accessibility", "reduce_flashes", false))


func set_reduce_flashes(enabled: bool) -> void:
	_config.set_value("accessibility", "reduce_flashes", enabled)
	save_settings()
	settings_changed.emit(&"accessibility", &"reduce_flashes")


func get_reduce_motion() -> bool:
	return bool(_config.get_value("accessibility", "reduce_motion", false))


func set_reduce_motion(enabled: bool) -> void:
	_config.set_value("accessibility", "reduce_motion", enabled)
	save_settings()
	settings_changed.emit(&"accessibility", &"reduce_motion")


func get_large_text() -> bool:
	return bool(_config.get_value("accessibility", "large_text", false))


func set_large_text(enabled: bool) -> void:
	_config.set_value("accessibility", "large_text", enabled)
	save_settings()
	settings_changed.emit(&"accessibility", &"large_text")


## UI font sizes ask the store so the "large text" option scales them uniformly.
func ui_font_size(base_size: int) -> int:
	if get_large_text():
		return base_size + LARGE_TEXT_DELTA
	return base_size
