class_name TDCombatEffect
extends Node3D

## Procedural combat feedback for the 3D build - the 3D sibling of the 2D
## build's CombatEffect: an owner builds this node at an event position and
## it animates itself to rest and frees itself. Reads TDSettings so
## reduce_flashes dims every glow and reduce_motion keeps sparks in place.

const KIND_HIT: int = 0
const KIND_DEATH: int = 1
const KIND_PLACED: int = 2
const KIND_UPGRADE: int = 3
const KIND_SOLD: int = 4
const KIND_LEAK: int = 5
const KIND_WAVE: int = 6
const KIND_MUZZLE: int = 7
const KIND_ELECTRIC: int = 8
const KIND_SPLIT: int = 9
const KIND_HERO_BURST: int = 10

var effect_kind: int = 0
## Optional beam anchor (hero burst): when set, a tracer beam runs from this
## world position to the effect position.
var effect_from: Vector3 = Vector3.INF

var _age: float = 0.0
var _lifetime: float = 0.25
var _alpha_scale: float = 1.0
var _motion_scale: float = 1.0
var _ring_nodes: Array[MeshInstance3D] = []

var _sparks: Array[MeshInstance3D] = []

var _tracer_node: MeshInstance3D = null
var _tracer_material: StandardMaterial3D = null


func _ready() -> void:
	_read_settings()
	match effect_kind:
		KIND_HIT:
			_lifetime = 0.22
			_build_ring(0.35, 1.15, 0.04, Color(0.95, 0.88, 0.45))
		KIND_DEATH:
			_lifetime = 0.4
			_build_ring(0.5, 1.9, 0.05, Color(1.0, 0.6, 0.3))
			_build_sparks(6, 2.2, Color(1.0, 0.75, 0.4))
		KIND_PLACED:
			_lifetime = 0.35
			_build_ring(0.85, 2.3, 0.05, Color(0.35, 0.8, 0.4))
		KIND_UPGRADE:
			_lifetime = 0.38
			_build_ring(0.9, 2.6, 0.05, Color(0.95, 0.85, 0.3))
		KIND_SOLD:
			_lifetime = 0.3
			_build_ring(0.85, 1.4, 0.05, Color(0.7, 0.7, 0.7))
		KIND_LEAK:
			_lifetime = 0.5
			_build_ring(1.0, 3.4, 0.06, Color(0.9, 0.25, 0.2))
		KIND_WAVE:
			_lifetime = 0.55
			_build_ring(1.4, 4.6, 0.06, Color(0.87, 0.8, 0.55))
		KIND_MUZZLE:
			_lifetime = 0.09
			_build_ring(0.2, 0.7, 0.03, Color(1.0, 0.95, 0.7))
		KIND_ELECTRIC:
			_lifetime = 0.28
			_build_ring(0.35, 0.9, 0.06, Color(0.1, 0.65, 1.0))
			_build_sparks(12, 1.35, Color(0.2, 0.9, 1.0))
		KIND_SPLIT:
			_lifetime = 0.42
			_build_ring(0.4, 2.3, 0.05, Color(0.72, 0.38, 1.0))
			_build_sparks(8, 2.5, Color(0.72, 0.45, 1.0))
		KIND_HERO_BURST:
			# the hero's rifle burst: cyan tracer + hot impact sparks
			_lifetime = 0.2
			_build_ring(0.25, 1.0, 0.035, Color(0.3, 0.9, 1.0))
			_build_sparks(7, 1.5, Color(0.55, 0.95, 1.0))
			if effect_from != Vector3.INF:
				_build_tracer(effect_from)
		_:
			_lifetime = 0.25


func _read_settings() -> void:
	var store := get_node_or_null("/root/TDSettings") as TDSettingsStore
	if store == null:
		return
	if store.get_reduce_flashes():
		_alpha_scale = 0.4
	if store.get_reduce_motion():
		_motion_scale = 0.0


func _build_ring(start_radius: float, end_radius: float, thickness: float,
		color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = start_radius
	ring_mesh.bottom_radius = start_radius
	ring_mesh.height = thickness
	ring_mesh.set_meta(&"start_radius", start_radius)
	ring_mesh.set_meta(&"end_radius", end_radius)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	mesh_instance.mesh = ring_mesh
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(0.0, 0.2, 0.0)
	add_child(mesh_instance)
	_ring_nodes.append(mesh_instance)


## Slim emissive beam from a source world point to the effect origin: the
## hero's rifle tracer. A cylinder is turned into a line by pivoting at its
## center and aiming its Y axis along the span.
func _build_tracer(from_position: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	var span: float = global_position.distance_to(from_position)
	if span < 0.05:
		return
	beam_mesh.top_radius = 0.035
	beam_mesh.bottom_radius = 0.035
	beam_mesh.height = span
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.45, 0.92, 1.0)
	material.emission_energy_multiplier = 1.4
	beam.mesh = beam_mesh
	beam.material_override = material
	add_child(beam)
	beam.look_at_from_position(global_position.lerp(from_position, 0.5), from_position, Vector3.UP)
	beam.rotation.x += PI * 0.5
	_tracer_node = beam
	_tracer_material = material


func _build_sparks(count: int, max_distance: float, color: Color) -> void:
	for index: int in range(count):
		var spark := MeshInstance3D.new()
		var shard := BoxMesh.new()
		shard.size = Vector3(0.16, 0.16, 0.16)
		spark.mesh = shard
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = color
		spark.material_override = material
		spark.set_meta(&"angle", TAU * float(index) / float(count))
		spark.set_meta(&"max_distance", max_distance)
		spark.set_meta(&"material", material)
		add_child(spark)
		_sparks.append(spark)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	var progress: float = clampf(_age / _lifetime, 0.0, 1.0)
	var fade: float = 1.0 - progress

	for ring_index: int in range(_ring_nodes.size()):
		var node: MeshInstance3D = _ring_nodes[ring_index]
		var mesh: CylinderMesh = node.mesh as CylinderMesh
		var start: float = float(mesh.get_meta(&"start_radius"))
		var end: float = float(mesh.get_meta(&"end_radius"))
		var radius: float = lerpf(start, end, progress)
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		var material := node.material_override as StandardMaterial3D
		var color: Color = material.emission
		material.albedo_color = Color(color.r, color.g, color.b, fade * _alpha_scale)
		material.emission_energy_multiplier = fade * _alpha_scale

	for spark in _sparks:
		var angle: float = float(spark.get_meta(&"angle"))
		var max_distance: float = float(spark.get_meta(&"max_distance")) * _motion_scale
		var distance: float = max_distance * progress
		spark.position = Vector3(cos(angle) * distance, 0.2 - progress * 0.25, sin(angle) * distance)
		var material := spark.get_meta(&"material") as StandardMaterial3D
		material.albedo_color = Color(material.emission.r, material.emission.g, material.emission.b, fade)
	if _tracer_material != null:
		_tracer_material.albedo_color = Color(_tracer_material.emission.r, _tracer_material.emission.g, _tracer_material.emission.b, fade * _alpha_scale)
		_tracer_material.emission_energy_multiplier = fade * 1.4 * _alpha_scale
		if _tracer_node != null:
			_tracer_node.scale = Vector3(1.0, maxf(1.0 - progress * 1.6, 0.01), 1.0)