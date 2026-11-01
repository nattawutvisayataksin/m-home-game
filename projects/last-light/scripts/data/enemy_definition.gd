extends Resource
class_name EnemyDefinition

@export var enemy_id: StringName = &"drifter"
@export var scene: PackedScene
@export var archetype: DrifterEnemy.Archetype = DrifterEnemy.Archetype.DRIFTER
@export_range(1, 5, 1) var minimum_wave: int = 1
@export_range(1, 20, 1) var health: int = 1
@export_range(0.0, 200.0, 1.0) var descent_speed: float = 30.0
@export_range(0, 100, 1) var resonance_reward: int = 25
