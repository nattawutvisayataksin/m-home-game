extends SceneTree

const REPOSITORY_SCRIPT: Script = preload("res://scripts/systems/profile_repository.gd")
const TEST_SAVE_PATH: String = "user://phase3_profile_test.json"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_cleanup_test_files()
	var repository: ProfileRepository = REPOSITORY_SCRIPT.new(TEST_SAVE_PATH)
	var legacy_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if not _check(legacy_file != null, "Could not create the legacy profile fixture."):
		return
	legacy_file.store_string(JSON.stringify({
		"version": 1,
		"salvage": 12,
		"total_runs": 3,
		"victories": 1,
		"best_integrity": 4,
	}))
	legacy_file.close()

	var migrated: Dictionary = repository.load_profile()
	if not _check(migrated["version"] == 3 and migrated["lifetime_salvage"] == 12, "Version 1 profile did not migrate to version 3."):
		return
	if not _check(migrated["best_wave"] == 1 and migrated["codex_unlocked"].is_empty(), "Migration did not populate safe defaults."):
		return
	if not _check(migrated["barricade_level"] == 0, "Migration did not initialize the base upgrade level."):
		return

	var first_save_error: Error = repository.save_profile(migrated)
	if not _check(first_save_error == OK, "Could not write migrated profile."):
		return
	var changed: Dictionary = migrated.duplicate(true)
	changed["salvage"] = 80
	changed["lifetime_salvage"] = 80
	var second_save_error: Error = repository.save_profile(changed)
	if not _check(second_save_error == OK, "Could not rotate the previous profile to backup."):
		return

	var corrupt_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if not _check(corrupt_file != null, "Could not create the corrupt-primary fixture."):
		return
	corrupt_file.store_string("{not valid json")
	corrupt_file.close()
	var recovered: Dictionary = repository.load_profile()
	if not _check(recovered["salvage"] == 12, "Corrupt primary profile did not recover from the last known-good backup."):
		return

	var progression: Dictionary = repository.record_run(recovered, true, 70, 0, 5, 5, 280)
	if not _check(progression["salvage"] == 87 and progression["victories"] == 2, "Run results did not award salvage and update victory records."):
		return
	if not _check(progression["fastest_victory_seconds"] == 280, "Best victory time did not update."):
		return
	if not _check(progression["codex_unlocked"].has("lore_signal") and progression["codex_unlocked"].has("lore_warden"), "Salvage milestones did not unlock archive entries."):
		return

	var invalid: Dictionary = repository.default_profile()
	invalid["salvage"] = -1
	if not _check(repository.save_profile(invalid) == ERR_INVALID_DATA, "Invalid profile data was not rejected."):
		return
	invalid = repository.default_profile()
	invalid["barricade_level"] = 3
	if not _check(repository.save_profile(invalid) == ERR_INVALID_DATA, "Out-of-range base upgrades were not rejected."):
		return

	var future_profile: Dictionary = repository.default_profile()
	future_profile["version"] = 4
	var future_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if not _check(future_file != null, "Could not create the newer-version fixture."):
		return
	future_file.store_string(JSON.stringify(future_profile))
	future_file.close()
	var protected_profile: Dictionary = repository.load_profile()
	if not _check(protected_profile["salvage"] == 12, "Newer profile did not preserve the last compatible backup."):
		return
	if not _check(repository.save_profile(protected_profile) == ERR_UNAUTHORIZED, "A newer profile could be overwritten by this build."):
		return

	_cleanup_test_files()
	print("PHASE 3 SAVE TEST PASSED")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 3 SAVE TEST FAILED: " + message)
	_cleanup_test_files()
	quit(1)
	return false


func _cleanup_test_files() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_SAVE_PATH)
	for path: String in [absolute_path, absolute_path + ".bak", absolute_path + ".tmp"]:
		if FileAccess.file_exists(path):
			var error: Error = DirAccess.remove_absolute(path)
			if error != OK:
				push_warning("Could not clean test file %s: %s" % [path, error_string(error)])
