class_name TDMapLayout
extends Resource

## Data definition for one map's walkable layout (scripts/gameplay/td_run.gd
## reads this and builds the world). Geometry only - enemy/tower balance
## numbers stay in their own .tres files, never here.

@export var map_id: int = 1
## Localization key for the map's display name (HUD / docs wiring).
@export var display_key: String = "MAP_NAME_1"
## Ground plane size (metres, x/z). Camera framing must cover this plane.
@export var ground_size: Vector2 = Vector2(64.0, 48.0)

## Walk-in polyline for the road: first point is the spawn gate, the last
## point feeds the shelter compound (compound_center = end + (4, 0, 0)).
@export var path_points: PackedVector3Array = PackedVector3Array([
	Vector3(-11.0, 0.0, 7.0),
	Vector3(-11.0, 0.0, -6.0),
	Vector3(-7.0, 0.0, -6.0),
	Vector3(-7.0, 0.0, 2.0),
	Vector3(0.0, 0.0, 2.0),
	Vector3(0.0, 0.0, -7.0),
	Vector3(8.0, 0.0, -7.0),
])

## Tower placement slots, one per index (slot disks build in this order).
## Every slot must clear the road by ~3+ units: placement validity reads it.
@export var tower_slots: Array[Vector3] = [
	Vector3(-13.6, 0.0, 4.6),
	Vector3(-8.4, 0.0, 5.0),
	Vector3(-13.6, 0.0, -2.0),
	Vector3(-1.8, 0.0, 4.6),
	Vector3(-9.2, 0.0, -9.2),
	Vector3(-4.8, 0.0, -8.6),
	Vector3(-4.4, 0.0, -2.2),
	Vector3(-9.4, 0.0, -0.4),
	Vector3(2.3, 0.0, -1.2),
	Vector3(-2.4, 0.0, -4.0),
	Vector3(2.4, 0.0, -9.6),
	Vector3(5.8, 0.0, -4.4),
]

## Far-border hill dressing (deterministic scatter of the silhouette ring).
@export var hill_positions: Array[Vector3] = [
	Vector3(-26.0, 0.0, -24.0),
	Vector3(-10.0, 0.0, -25.0),
	Vector3(6.0, 0.0, -25.0),
	Vector3(20.0, 0.0, -23.0),
	Vector3(27.0, 0.0, -14.0),
	Vector3(30.0, 0.0, 2.0),
	Vector3(26.0, 0.0, 13.0),
	Vector3(-27.0, 0.0, -12.0),
	Vector3(-29.0, 0.0, 2.0),
	Vector3(-26.0, 0.0, 12.0),
]
@export var hill_scales: Array[float] = [2.0, 1.8, 1.9, 1.7, 1.6, 1.5, 1.5, 1.6, 1.55, 1.5]

## Optional per-map wave set (ordered .tres paths). When non-empty the run
## maps these over the global wave list: map-specific pacing/economy data
## lives here, not in gameplay scripts. Metrics mark the first leak beyond
## the teaching waves, so shared bloat that fits one map loses the other.
@export var wave_paths: Array[String] = []

## Fixed tactical camera: the run locks this, so the whole map must frame.
@export var camera_position: Vector3 = Vector3(4.0, 17.0, 15.0)
@export var camera_focus: Vector3 = Vector3(0.0, 0.0, -2.0)
@export var camera_fov: float = 42.0


## Total walk length of the road polyline (used by tests to compare maps).
func path_length() -> float:
	var total: float = 0.0
	for index: int in range(path_points.size() - 1):
		total += path_points[index].distance_to(path_points[index + 1])
	return total
