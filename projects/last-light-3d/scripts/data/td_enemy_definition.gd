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

## Dasher dash cycle (per docs/GDD_3DTD.md: telegraph สั้นแล้วพุ่งเป็นช่วงยาว).
## Values of 0/1.0 keep an archetype in its plain-walk behavior. The dash
## multiplies `speed` for a burst; telegraph time is a full stop for readability.
## Time-averaged displacement is defined by the values in the .tres file only.
@export var dash_walk_time: float = 0.0
@export var dash_telegraph_time: float = 0.0
@export var dash_time: float = 0.0
@export var dash_speed_multiplier: float = 1.0

## Optional: low-poly .glb model loaded as PackedScene. When null the enemy
## falls back to greybox primitives so the game runs without Blender assets.
@export var model_scene: PackedScene

## Splitter behavior: on death the parent spawns `split_count` children of
## `split_into` (another enemy_id). Children inherit the wave health bonus
## scaled by split_health_scale, and pay child bounty scaled by
## split_child_bounty_scale. Zero split_count keeps an enemy whole.
@export var split_into: StringName = &""
@export var split_count: int = 0
@export var split_health_scale: float = 0.5
@export var split_child_bounty_scale: float = 0.5
