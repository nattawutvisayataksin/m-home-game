class_name TDProjectile
extends Node3D

## Greybox projectile: homes on the target; applies splash damage to nearby
## enemies on impact. Frees itself when the target is gone or impact occurs.
## Emits impacted() once per impact; the run owns the visual response.

signal impacted(position: Vector3, splash: bool)

var damage: float = 0.0
var splash_radius: float = 0.0
var speed: float = 22.0
var impact_radius: float = 0.7

var _target: TDEnemy


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4) if splash_radius > 0.0 else Vector3(0.22, 0.22, 0.22)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.85, 0.4) if splash_radius > 0.0 else Color(0.9, 0.9, 0.75)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.6
	mesh.material_override = material
	add_child(mesh)


func configure_target(new_target: TDEnemy) -> void:
	_target = new_target


func _physics_process(delta: float) -> void:
	if _target == null or not _target.alive:
		queue_free()
		return
	var to_target: Vector3 = _target.global_position + Vector3(0.0, 0.6, 0.0) - global_position
	var remaining: float = to_target.length()
	var step: float = speed * delta
	if step >= remaining:
		_impact()
		return
	global_position += to_target.normalized() * step


func _impact() -> void:
	var impact_position: Vector3 = global_position
	if is_instance_valid(_target):
		impact_position = _target.global_position + Vector3(0.0, 0.6, 0.0)
		_target.take_damage(damage)
	if splash_radius > 0.0:
		var origin: Vector3 = global_position
		for node: Node in get_tree().get_nodes_in_group("td_enemies"):
			var enemy := node as TDEnemy
			if enemy != null and is_instance_valid(enemy) and enemy.alive and enemy.global_position.distance_to(origin) <= splash_radius:
				enemy.take_damage(damage)
	impacted.emit(impact_position, splash_radius > 0.0)
	queue_free()
