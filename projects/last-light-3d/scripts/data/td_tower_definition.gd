class_name TDTowerDefinition
extends Resource

## Data definition for one TD tower. Two upgrade levels beyond the base build;
## multipliers/slow profiles are linear per level as listed below.
## When model_scene is set, the tower instantiates a .glb model instead of
## building greybox primitives (TD-2 asset swap).

@export var tower_kind: TDTower.Kind = TDTower.Kind.FIELD_TURRET
@export var display_name: String = "Field Turret"
@export var cost: int = 80
@export var range_radius: float = 5.5
@export var damage: float = 6.0
@export var fire_interval: float = 0.45
@export var splash_radius: float = 0.0
@export var slow_factor: float = 1.0
@export var upgrade_costs: Array[int] = [60, 110]
@export var upgrade_damage_factor: float = 1.5
@export var upgrade_rate_factor: float = 0.8
@export var upgrade_range_bonus: float = 0.6
@export var upgrade_slow_factor: float = 0.85

## Optional: low-poly .glb model loaded as PackedScene. When null the tower
## falls back to greybox primitives so the game runs without Blender assets.
@export var model_scene: PackedScene
