class_name RunMetrics
extends RefCounted

## Playtest metric recorder (schema 1). Collects objective run events as plain
## dictionaries and writes one JSON file per run under user://metrics/.
## Fields follow the playtest metrics list in docs/ROADMAP.md:
## breach timeline, Parts choices, kills/integrity at result and end times.
## No telemetry leaves the machine.

const METRICS_SCHEMA_VERSION := 1

var run_id: String = ""
var started_at_unix: float = 0.0
var events: Array[Dictionary] = []
var result: Dictionary = {}


func begin() -> void:
	started_at_unix = Time.get_unix_time_from_system()
	var timestamp: String = Time.get_datetime_string_from_system(true, true).replace("-", "").replace(":", "").replace(" ", "")
	run_id = "%s_%06d" % [timestamp, int(started_at_unix) % 1000000]


func record(event_type: StringName, data: Dictionary = {}) -> void:
	var entry: Dictionary = {"type": String(event_type), "elapsed": _current_elapsed()}
	for key: String in data.keys():
		entry[key] = data[key]
	events.append(entry)


func _current_elapsed() -> float:
	if started_at_unix <= 0.0:
		return 0.0
	return maxf(Time.get_unix_time_from_system() - started_at_unix, 0.0)


func finalize_run(payload: Dictionary) -> void:
	result = payload.duplicate()
	result["schema_version"] = METRICS_SCHEMA_VERSION
	result["run_id"] = run_id
	result["started_at_unix"] = started_at_unix
	result["duration_seconds"] = _current_elapsed()
	result["events"] = events


func save_file() -> String:
	if result.is_empty():
		push_warning("RunMetrics: cannot save before finalize_run is called.")
		return ""
	var directory := DirAccess.open("user://")
	if directory == null:
		push_warning("RunMetrics: user:// directory is unavailable.")
		return ""
	var make_error: Error = directory.make_dir_recursive("metrics")
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		push_warning("RunMetrics: could not create metrics folder (%s)." % error_string(make_error))
		return ""
	var file := FileAccess.open("user://metrics/%s.json" % run_id, FileAccess.WRITE)
	if file == null:
		push_warning("RunMetrics: could not open save file for run %s." % run_id)
		return ""
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	return "user://metrics/%s.json" % run_id
