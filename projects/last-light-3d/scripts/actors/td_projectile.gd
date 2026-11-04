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
var tower_kind: int = 0

var _target: TDEnemy


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	if tower_kind == 0:
		var beam := CylinderMesh.new()
		beam.top_radius = 0.055
		beam.bottom_radius = 0.09
		beam.height = 0.85
		mesh.mesh = beam
		mesh.rotation_degrees.x = 90.0
	elif tower_kind == 3:
		var arc := SphereMesh.new()
		arc.radius = 0.23
		arc.height = 0.46
		mesh.mesh = arc
	elif splash_radius > 0.0:
		var rocket := CapsuleMesh.new()
		rocket.radius = 0.16
		rocket.height = 0.62
		mesh.mesh = rocket
	else:
		var bolt := SphereMesh.new()
		bolt.radius = 0.12
		bolt.height = 0.24
		mesh.mesh = bolt
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.85, 1.0) if tower_kind == 0 else (Color(0.55, 0.18, 1.0) if tower_kind == 3 else (Color(1.0, 0.36, 0.12) if splash_radius > 0.0 else Color(0.55, 0.75, 1.0)))
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
