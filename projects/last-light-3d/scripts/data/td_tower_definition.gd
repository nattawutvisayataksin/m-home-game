class_name TDTowerDefinition
extends Resource

## Data definition for one TD tower. Two upgrade levels beyond the base build.
## Stats are per level (index == tower level, 0..2) so every level's power and
## price is readable in one place. The base fields below mirror level 0 for
## backward compatibility (tests compare against them); per-level arrays are
## the authoritative source for any level >= 0.
## When model_scene is set, the tower instantiates a .glb model instead of
## building greybox primitives (TD-2 asset swap).

@export var tower_kind: TDTower.Kind = TDTower.Kind.FIELD_TURRET
@export var display_name: String = "Field Turret"

# level 0 mirrors: damage/fire_interval/range_radius/splash_radius/slow_factor
@export var cost: int = 80
@export var damage: float = 6.0
@export var fire_interval: float = 0.45
@export var range_radius: float = 5.5
@export var splash_radius: float = 0.0
@export var slow_factor: float = 1.0

# per level (index 0..2): what the player buys
@export var level_damage: Array[float] = [6.0, 9.0, 14.0]
@export var level_fire_interval: Array[float] = [0.45, 0.36, 0.29]
@export var level_range: Array[float] = [5.5, 6.1, 6.7]
@export var level_splash: Array[float] = [0.0, 0.0, 0.0]
@export var level_slow: Array[float] = [1.0, 1.0, 1.0]

# prices: purchase (cost) and each upgrade step, per tower
@export var upgrade_costs: Array[int] = [60, 110]

## Optional: low-poly .glb model loaded as PackedScene. When null the tower
## falls back to greybox primitives so the game runs without Blender assets.
@export var model_scene: PackedScene
