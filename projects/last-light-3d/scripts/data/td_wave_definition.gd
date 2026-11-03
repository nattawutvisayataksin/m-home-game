class_name TDWaveDefinition
extends Resource

## Data definition for one wave: which enemies in what counts, spawn pacing
## and the wave-wide health bonus. Composition keys are enemy ids.

@export var wave_id: StringName = &"wave_01"
@export var composition: Dictionary = {&"drifter": 6}
@export var spawn_interval: float = 1.0
@export var health_bonus: float = 0.0
