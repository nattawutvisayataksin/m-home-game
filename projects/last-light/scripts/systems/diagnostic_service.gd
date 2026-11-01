extends Node

const LOG_PATH: String = "user://logs/runtime.log"
const SESSION_PATH: String = "user://session.active"
const MAX_LOG_BYTES: int = 262144

var _shutdown_recorded: bool = false


func _ready() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		log_error("Previous session ended without a clean shutdown.")
		var stale_marker_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
		if stale_marker_error != OK:
			push_warning("Could not clear previous session marker: %s" % error_string(stale_marker_error))
	log_event("INFO", "Session started; Godot %s; %s" % [Engine.get_version_info().string, OS.get_name()])
	var marker := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if marker == null:
		push_warning("Could not create session marker: %s" % error_string(FileAccess.get_open_error()))
	else:
		marker.store_string(Time.get_datetime_string_from_system(true))
		marker.flush()
		var marker_error: Error = marker.get_error()
		marker.close()
		if marker_error != OK:
			push_warning("Could not write session marker: %s" % error_string(marker_error))
	get_tree().root.tree_exiting.connect(_mark_clean_shutdown)


func log_error(message: String) -> void:
	log_event("ERROR", message)


func log_event(level: String, message: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(LOG_PATH)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_warning("Could not create diagnostics directory: %s" % error_string(directory_error))
		return
	if FileAccess.file_exists(absolute_path) and FileAccess.get_size(absolute_path) >= MAX_LOG_BYTES:
		var previous_path: String = absolute_path + ".previous"
		if FileAccess.file_exists(previous_path):
			var remove_error: Error = DirAccess.remove_absolute(previous_path)
			if remove_error != OK:
				push_warning("Could not rotate diagnostics log: %s" % error_string(remove_error))
				return
		var rotate_error: Error = DirAccess.rename_absolute(absolute_path, previous_path)
		if rotate_error != OK:
			push_warning("Could not rotate diagnostics log: %s" % error_string(rotate_error))
			return
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open diagnostics log: %s" % error_string(FileAccess.get_open_error()))
		return
	file.seek_end()
	file.store_line("%s [%s] %s" % [Time.get_datetime_string_from_system(true), level, message.replace("\n", " ")])
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_warning("Could not write diagnostics log: %s" % error_string(write_error))


func _mark_clean_shutdown() -> void:
	if _shutdown_recorded:
		return
	_shutdown_recorded = true
	log_event("INFO", "Session ended cleanly.")
	var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	if error != OK and error != ERR_DOES_NOT_EXIST:
		push_warning("Could not clear session marker: %s" % error_string(error))
