extends Resource
class_name WaveDefinition

@export_range(1, 5, 1) var wave_number: int = 1
@export_range(0.5, 5.0, 0.1) var spawn_interval: float = 1.35
@export_range(0, 10, 1) var enemy_health_bonus: int = 0
@export_range(0.0, 50.0, 1.0) var enemy_speed_bonus: float = 0.0
@export var available_enemy_ids: Array[StringName] = [&"drifter"]
