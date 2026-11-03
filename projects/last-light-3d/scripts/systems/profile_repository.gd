extends RefCounted
class_name ProfileRepository

const CURRENT_VERSION: int = 3
const MAX_BARRICADE_LEVEL: int = 2
const CODEX_THRESHOLDS: Dictionary = {
	"lore_signal": 20,
	"lore_warden": 75,
	"lore_last_light": 150,
}

var save_path: String
var _write_blocked: bool = false


func _init(path: String = "user://profile.json") -> void:
	save_path = path


func default_profile() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"salvage": 0,
		"lifetime_salvage": 0,
		"total_runs": 0,
		"victories": 0,
		"best_integrity": 0,
		"best_wave": 1,
		"fastest_victory_seconds": 0,
		"codex_unlocked": [],
		"barricade_level": 0,
	}


func load_profile() -> Dictionary:
	_write_blocked = false
	for candidate: String in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			push_warning("Could not read profile %s: %s" % [candidate, error_string(FileAccess.get_open_error())])
			continue
		var parser := JSON.new()
		var text: String = file.get_as_text()
		file.close()
		var parse_error: Error = parser.parse(text)
		if parse_error != OK or not parser.data is Dictionary:
			push_warning("Profile %s is invalid JSON; trying the backup." % candidate)
			continue
		var parsed: Dictionary = parser.data
		if int(parsed.get("version", 1)) > CURRENT_VERSION:
			_write_blocked = true
			push_warning("Profile %s was created by a newer game version; it will not be overwritten." % candidate)
			continue
		var migrated: Dictionary = _migrate(parsed)
		if migrated.is_empty():
			continue
		if not _validate(migrated):
			push_warning("Profile %s failed validation; trying the backup." % candidate)
			continue
		return _normalize(migrated)
	return default_profile()


func save_profile(profile: Dictionary) -> Error:
	if _write_blocked:
		return ERR_UNAUTHORIZED
	var normalized: Dictionary = _normalize(profile)
	if not _validate(normalized):
		return ERR_INVALID_DATA
	normalized["version"] = CURRENT_VERSION

	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var temporary_path: String = absolute_path + ".tmp"
	var backup_path: String = absolute_path + ".bak"
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("Could not create profile directory: %s" % error_string(directory_error))
		return directory_error

	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("Could not open temporary profile: %s" % error_string(open_error))
		return open_error
	file.store_string(JSON.stringify(normalized, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_error("Could not write temporary profile: %s" % error_string(write_error))
		_remove_temporary_file(temporary_path)
		return write_error

	if FileAccess.file_exists(absolute_path):
		if FileAccess.file_exists(backup_path):
			var remove_error: Error = DirAccess.remove_absolute(backup_path)
			if remove_error != OK:
				push_error("Could not rotate profile backup: %s" % error_string(remove_error))
				return remove_error
		var backup_error: Error = DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			push_error("Could not preserve the previous profile: %s" % error_string(backup_error))
			_remove_temporary_file(temporary_path)
			return backup_error

	var replace_error: Error = DirAccess.rename_absolute(temporary_path, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(absolute_path):
			var restore_error: Error = DirAccess.rename_absolute(backup_path, absolute_path)
			if restore_error != OK:
				push_error("Could not restore the previous profile backup: %s" % error_string(restore_error))
		push_error("Could not replace profile with the new save: %s" % error_string(replace_error))
		_remove_temporary_file(temporary_path)
		return replace_error
	return OK


func _remove_temporary_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var remove_error: Error = DirAccess.remove_absolute(path)
	if remove_error != OK:
		push_warning("Could not remove temporary profile %s: %s" % [path, error_string(remove_error)])


func record_run(profile: Dictionary, won: bool, kills: int, breaches: int, integrity: int, wave: int, duration_seconds: int) -> Dictionary:
	var updated: Dictionary = _normalize(profile)
	var salvage_earned: int = maxi(kills + (5 if won else 0) - breaches, 0)
	updated["salvage"] = int(updated["salvage"]) + salvage_earned
	updated["lifetime_salvage"] = int(updated["lifetime_salvage"]) + salvage_earned
	updated["total_runs"] = int(updated["total_runs"]) + 1
	updated["victories"] = int(updated["victories"]) + (1 if won else 0)
	updated["best_integrity"] = maxi(int(updated["best_integrity"]), integrity)
	updated["best_wave"] = maxi(int(updated["best_wave"]), wave)
	if won:
		var previous_time: int = int(updated["fastest_victory_seconds"])
		if previous_time == 0 or duration_seconds < previous_time:
			updated["fastest_victory_seconds"] = duration_seconds

	var unlocked: Array = updated["codex_unlocked"]
	for entry: String in CODEX_THRESHOLDS:
		if int(updated["lifetime_salvage"]) >= int(CODEX_THRESHOLDS[entry]) and not unlocked.has(entry):
			unlocked.append(entry)
	updated["codex_unlocked"] = unlocked
	return updated


func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 1))
	if version > CURRENT_VERSION or version < 1:
		push_warning("Unsupported profile version %d; the profile was not loaded." % version)
		return {}
	var migrated: Dictionary = data.duplicate(true)
	while version < CURRENT_VERSION:
		match version:
			1:
				migrated["lifetime_salvage"] = int(migrated.get("salvage", 0))
				migrated["codex_unlocked"] = []
				migrated["best_wave"] = int(migrated.get("best_wave", 1))
				migrated["fastest_victory_seconds"] = 0
				version = 2
				migrated["version"] = version
			2:
				migrated["barricade_level"] = 0
				version = 3
				migrated["version"] = version
			_:
				return {}
	return migrated


func _normalize(profile: Dictionary) -> Dictionary:
	var normalized: Dictionary = default_profile()
	for key: String in normalized:
		if profile.has(key):
			normalized[key] = profile[key]
	if normalized["codex_unlocked"] is not Array:
		normalized["codex_unlocked"] = []
	return normalized


func _validate(profile: Dictionary) -> bool:
	for key: String in ["version", "salvage", "lifetime_salvage", "total_runs", "victories", "best_integrity", "best_wave", "fastest_victory_seconds", "barricade_level"]:
		if not profile.has(key) or not (profile[key] is int or profile[key] is float):
			return false
		if int(profile[key]) < 0 or float(profile[key]) != float(int(profile[key])):
			return false
	if int(profile["version"]) != CURRENT_VERSION:
		return false
	if int(profile["barricade_level"]) > MAX_BARRICADE_LEVEL:
		return false
	if not profile.get("codex_unlocked", null) is Array:
		return false
	for entry: Variant in profile["codex_unlocked"]:
		if not entry is String or not CODEX_THRESHOLDS.has(entry):
			return false
	return true
