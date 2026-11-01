extends Resource
class_name WeaponDefinition

@export var weapon_id: StringName = &"beacon_cannon"
@export_range(1, 10, 1) var base_damage: int = 1
@export_range(0.1, 2.0, 0.01) var base_fire_interval: float = 0.42
@export var overclock: UpgradeDefinition


func get_max_level() -> int:
	return 1 + (overclock.get_max_stacks() if overclock != null else 0)


func get_damage(level: int) -> int:
	return overclock.get_damage_for_level(level, base_damage) if overclock != null else base_damage


func get_fire_interval(level: int) -> float:
	return overclock.get_fire_interval_for_level(level, base_fire_interval) if overclock != null else base_fire_interval
