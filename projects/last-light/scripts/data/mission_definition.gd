extends Resource
class_name MissionDefinition

@export var mission_id: StringName = &"beacon_09"
@export_range(60, 900, 1) var duration_seconds: int = 300
@export_range(30, 840, 1) var boss_start_seconds: int = 240
@export_range(15, 180, 1) var wave_duration_seconds: int = 60
@export_range(1, 10, 1) var starting_integrity: int = 5
@export_range(0.5, 5.0, 0.1) var starting_spawn_interval: float = 1.35
@export_range(0.5, 5.0, 0.1) var minimum_spawn_interval: float = 0.98
@export_range(0.0, 1.0, 0.05) var spawn_interval_reduction_per_wave: float = 0.08
@export var enemy_roster: Array[EnemyDefinition] = []
@export var wave_definitions: Array[WaveDefinition] = []
@export var boss_definition: EnemyDefinition


func get_spawn_interval(wave: int) -> float:
	var wave_definition: WaveDefinition = get_wave_definition(wave)
	if wave_definition != null:
		return wave_definition.spawn_interval
	return maxf(
		minimum_spawn_interval,
		starting_spawn_interval - float(maxi(wave - 1, 0)) * spawn_interval_reduction_per_wave
	)


func get_wave_definition(wave: int) -> WaveDefinition:
	for definition: WaveDefinition in wave_definitions:
		if definition.wave_number == wave:
			return definition
	return null
