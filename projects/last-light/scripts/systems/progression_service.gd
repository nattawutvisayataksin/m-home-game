extends Node

signal profile_changed(profile: Dictionary)
signal save_failed(message: String)

const REPOSITORY_SCRIPT: Script = preload("res://scripts/systems/profile_repository.gd")

var _repository: ProfileRepository
var _profile: Dictionary
var _test_mode: bool = false


func _ready() -> void:
	_repository = REPOSITORY_SCRIPT.new()
	_profile = _repository.load_profile()


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func set_test_mode(enabled: bool) -> void:
	_test_mode = enabled
	if enabled:
		_profile = _repository.default_profile()


func set_test_profile(profile: Dictionary) -> void:
	if not _test_mode:
		push_error("A test profile can only be set while test mode is active.")
		return
	_profile = profile.duplicate(true)


func get_barricade_upgrade_cost() -> int:
	var level: int = int(_profile.get("barricade_level", 0))
	match level:
		0:
			return 30
		1:
			return 70
		_:
			return 0


func upgrade_barricade() -> bool:
	var cost: int = get_barricade_upgrade_cost()
	if cost == 0 or int(_profile.get("salvage", 0)) < cost:
		return false
	var updated: Dictionary = _profile.duplicate(true)
	updated["salvage"] = int(updated["salvage"]) - cost
	updated["barricade_level"] = int(updated["barricade_level"]) + 1
	if not _test_mode:
		var save_error: Error = _repository.save_profile(updated)
		if save_error != OK:
			var message: String = "Barricade upgrade could not be saved: %s" % error_string(save_error)
			save_failed.emit(message)
			if has_node("/root/DiagnosticService"):
				get_node("/root/DiagnosticService").log_error(message)
			return false
	_profile = updated
	profile_changed.emit(get_profile())
	return true


func record_run(won: bool, kills: int, breaches: int, integrity: int, wave: int, duration_seconds: int) -> int:
	var previous_salvage: int = int(_profile.get("salvage", 0))
	_profile = _repository.record_run(_profile, won, kills, breaches, integrity, wave, duration_seconds)
	if not _test_mode:
		var save_error: Error = _repository.save_profile(_profile)
		if save_error != OK:
			var message: String = "Progress could not be saved: %s" % error_string(save_error)
			save_failed.emit(message)
			if has_node("/root/DiagnosticService"):
				get_node("/root/DiagnosticService").log_error(message)
	profile_changed.emit(get_profile())
	return int(_profile["salvage"]) - previous_salvage


func spend_salvage(amount: int) -> bool:
	if amount <= 0 or int(_profile["salvage"]) < amount:
		return false
	_profile["salvage"] = int(_profile["salvage"]) - amount
	var save_error: Error = _repository.save_profile(_profile)
	if save_error != OK:
		_profile["salvage"] = int(_profile["salvage"]) + amount
		save_failed.emit("Progress could not be saved: %s" % error_string(save_error))
		return false
	profile_changed.emit(get_profile())
	return true


func is_lore_unlocked(entry_id: String) -> bool:
	return (_profile.get("codex_unlocked", []) as Array).has(entry_id)
