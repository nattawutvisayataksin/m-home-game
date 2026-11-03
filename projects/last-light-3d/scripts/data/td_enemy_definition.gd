class_name TDEnemyDefinition
extends Resource

## Data definition for one TD enemy archetype. Numbers live in .tres files
## under data/enemies; logic must read these, never hardcode.
## When model_scene is set, the enemy instantiates a .glb model instead of
## building greybox primitives (TD-2 asset swap).

@export var enemy_id: StringName = &"drifter"
@export var archetype: TDEnemy.Archetype = TDEnemy.Archetype.DRIFTER
@export var base_health: float = 40.0
@export var speed: float = 1.6
@export var bounty: int = 12
@export var integrity_damage: int = 1

## Optional: low-poly .glb model loaded as PackedScene. When null the enemy
## falls back to greybox primitives so the game runs without Blender assets.
@export var model_scene: PackedScene
