class_name TDSessionSnapshot
extends RefCounted

## Flash save for a 3D run: persisted mid-progress state at
## user://session_snapshot.json (plain JSON, schema-versioned like the other
## systems). The run writes a snapshot at every wave-clear prep boundary and on
## window close; the title menu exposes a Continue entry when a valid snapshot
## exists. Resuming always lands in the prep phase of the stored wave, so a
## mid-combat snapshot replays that wave — tower investments are never lost.

const SCHEMA_VERSION: int = 1

## Overridable only for tests, so automated runs never touch the player file.
static var save_path: String = "user://session_snapshot.json"

## Handoff flag between the title menu and the next run scene (survives
## change_scene; each run clears it after reading).
static var resume_requested: bool = false


## Serializes a well-formed snapshot atomically (temp file + rename).
## Required keys: wave, parts, integrity, towers (Array of tower objects with
## place/slot/position/kind/level/invested).
static func save_state(state: Dictionary) -> bool:
	var payload: Dictionary = {
		"schema_version" = SCHEMA_VERSION,
		"saved_at" = Time.get_unix_time_from_system(),
		"wave" = int(state.get("wave", 1)),
		"parts" = int(state.get("parts", 0)),
		"integrity" = int(state.get("integrity", 0)),
		"towers" = state.get("towers", []),
	}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write session snapshot temp file.")
		return false
	file.store_string(JSON.stringify(payload, "  ", false))
	file.close()
	var dir := DirAccess.open("user://")
	var rename_error: Error = dir.rename(save_path.trim_prefix("user://") + ".tmp", save_path.trim_prefix("user://")) if dir != null else FAILED
	if rename_error != OK:
		push_warning("Cannot finalize session snapshot file.")
		DirAccess.remove_absolute(save_path + ".tmp")
		return false
	return true


## Returns an empty Dictionary when nothing valid exists on disk.
static func load_state() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var text := FileAccess.get_file_as_string(save_path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var state: Dictionary = parsed
	if int(state.get("schema_version", 0)) != SCHEMA_VERSION:
		return {}
	return state


static func has_valid_snapshot() -> bool:
	return not load_state().is_empty()


static func get_resume_wave() -> int:
	var state := load_state()
	if state.is_empty():
		return 0
	return clampi(int(state.get("wave", 1)), 1, 99)


## Removes the snapshot (used when a run ends or a fresh one supersedes it).
static func clear() -> void:
	resume_requested = false
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
