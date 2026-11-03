class_name TDEnemyDefinition
extends Resource

## Greybox-safe data definition for one TD enemy archetype. Numbers live in
## .tres files under data/enemies; logic must read these, never hardcode.

@export var enemy_id: StringName = &"drifter"
@export var archetype: TDEnemy.Archetype = TDEnemy.Archetype.DRIFTER
@export var base_health: float = 40.0
@export var speed: float = 1.6
@export var bounty: int = 12
@export var integrity_damage: int = 1
