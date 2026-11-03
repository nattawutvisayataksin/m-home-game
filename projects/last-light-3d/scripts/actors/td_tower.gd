class_name TDTower
extends Node3D

## Greybox tower: auto-acquires the enemy with the highest path progress inside
## range ("first" targeting) and fires projectiles; Tangle applies a slow aura.

enum Kind { FIELD_TURRET, SONIC_RESONATOR, TANGLE_EMITTER }

var kind: Kind = Kind.FIELD_TURRET
var damage: float = 0.0
var fire_interval: float = 1.0
var range_radius: float = 5.0
var splash_radius: float = 0.0
var slow_factor: float = 1.0

var _cooldown: float = 0.0
var _projectile_parent: Node3D


func setup(tower_kind: Kind, new_range: float, new_damage: float,
		new_interval: float, splash: float, slow: float,
		projectile_parent: Node3D) -> void:
	kind = tower_kind
	range_radius = new_range
	damage = new_damage
	fire_interval = new_interval
	splash_radius = splash
	slow_factor = slow
	_projectile_parent = projectile_parent
	_build_body()


func _build_body() -> void:
	var base := MeshInstance3D.new()
	var base_cylinder := CylinderMesh.new()
	base_cylinder.top_radius = 0.6
	base_cylinder.bottom_radius = 0.8
	base_cylinder.height = 0.5
	base.mesh = base_cylinder
	base.position = Vector3(0.0, 0.25, 0.0)
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.36, 0.4, 0.36)
	base.material_override = base_material
	add_child(base)

	if kind == Kind.TANGLE_EMITTER:
		var aura := MeshInstance3D.new()
		var aura_cylinder := CylinderMesh.new()
		aura_cylinder.top_radius = range_radius
		aura_cylinder.bottom_radius = range_radius
		aura_cylinder.height = 0.02
		var aura_material := StandardMaterial3D.new()
		aura_material.albedo_color = Color(0.35, 0.65, 0.8, 0.25)
		aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		aura.mesh = aura_cylinder
		aura.material_override = aura_material
		aura.position = Vector3(0.0, 0.05, 0.0)
		add_child(aura)
	else:
		var barrel := MeshInstance3D.new()
		var barrel_box := BoxMesh.new()
		barrel_box.size = Vector3(0.3, 0.3, 1.2)
		barrel.mesh = barrel_box
		var barrel_material := StandardMaterial3D.new()
		if kind == Kind.SONIC_RESONATOR:
			barrel_material.albedo_color = Color(0.45, 0.5, 0.75)
		else:
			barrel_material.albedo_color = Color(0.7, 0.5, 0.3)
		barrel.material_override = barrel_material
		barrel.position = Vector3(0.0, 0.65, 0.4)
		add_child(barrel)


func _physics_process(delta: float) -> void:
	if kind == Kind.TANGLE_EMITTER:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	var target: TDEnemy = _acquire_target()
	if target == null:
		return
	_cooldown = fire_interval
	_fire(target)


func _acquire_target() -> TDEnemy:
	var best: TDEnemy = null
	for node: Node in _projectile_parent.get_tree().get_nodes_in_group("td_enemies"):
		var enemy := node as TDEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			continue
		if enemy.global_position.distance_to(global_position) > range_radius:
			continue
		if best == null or enemy.progress > best.progress:
			best = enemy
	return best


func _fire(target: TDEnemy) -> void:
	if _projectile_parent == null:
		return
	var projectile := TDProjectile.new()
	projectile.damage = damage
	projectile.splash_radius = splash_radius
	projectile.configure_target(target)
	_projectile_parent.add_child(projectile)
	projectile.global_position = global_position + Vector3(0.0, 1.0, 0.0)
