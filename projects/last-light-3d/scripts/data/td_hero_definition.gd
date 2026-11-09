class_name TDHeroDefinition
extends Resource

## Data definition for the dev-gated hero prototype (director-ordered prep
## work, GDD_3TDTD appendix). Balance numbers live in data/heroes/*.tres;
## the hero script only wires them - never hardcodes.

@export var hero_id: StringName = &"rin_prototype"
## Localization key for the hero's display name.
@export var display_key: String = "HERO_RIN"

@export var move_speed: float = 6.0
## Smoothing rate of the velocity approach (1/s): higher = snappier stops.
@export var move_accel: float = 16.0
## Forward lean of the torso at full speed (degrees).
@export var body_lean_deg: float = 10.0

@export var attack_range: float = 3.6
@export var attack_cooldown: float = 0.4
@export var attack_damage: float = 16.0
## Full attack cone width in front of the hero (degrees).
@export var attack_arc_deg: float = 70.0
