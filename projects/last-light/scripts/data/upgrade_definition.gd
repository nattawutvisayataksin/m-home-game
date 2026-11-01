extends Resource
class_name UpgradeDefinition

@export var upgrade_id: StringName = &"overclock"
@export var damage_by_stack: PackedInt32Array = PackedInt32Array([2, 3])
@export var fire_interval_by_stack: PackedFloat32Array = PackedFloat32Array([0.34, 0.26])


func get_max_stacks() -> int:
	return mini(damage_by_stack.size(), fire_interval_by_stack.size())


func get_damage_for_level(level: int, base_damage: int) -> int:
	if level <= 1 or damage_by_stack.is_empty():
		return base_damage
	var index: int = clampi(level - 2, 0, damage_by_stack.size() - 1)
	return damage_by_stack[index]


func get_fire_interval_for_level(level: int, base_interval: float) -> float:
	if level <= 1 or fire_interval_by_stack.is_empty():
		return base_interval
	var index: int = clampi(level - 2, 0, fire_interval_by_stack.size() - 1)
	return fire_interval_by_stack[index]
