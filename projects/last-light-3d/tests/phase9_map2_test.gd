extends SceneTree

## Map 2 test (TD-lld): the shipped map layouts are loadable and the run scene
## honors the TDMapSession handoff. No real-time waits: scene loads, physics
## frames and direct seams only.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")

const TEST_SNAPSHOT_PATH: String = "user://tests/phase9_snapshot.json"
const TEST_PROFILE_PATH: String = "user://tests/phase9_profile.json"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


## Fresh isolated files every run.
func _remove_test_files() -> void:
	for path: String in [TEST_SNAPSHOT_PATH, TEST_PROFILE_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("MAP 2 TEST FAILED: " + message)
		_failures += 1
	return condition


func _run_tests() -> void:
	# Player files stay untouched: isolated snapshot + profile paths.
	TDSessionSnapshot.save_path = TEST_SNAPSHOT_PATH
	_remove_test_files()
	_test_layout_shapes()
	_test_map_geometry_growth()
	_test_slot_road_clearance()
	await _test_session_handoff_into_run()
	await _test_victory_next_map_flow()

	if _failures == 0:
		print("PHASE 9 MAP2 TEST PASSED")
		quit(0)
	else:
		quit(1)


## Both .tres files load as TDMapLayout with a sane shape.
func _test_layout_shapes() -> void:
	var map_1 := (load("res://data/maps/map_01.tres") as TDMapLayout) if ResourceLoader.exists("res://data/maps/map_01.tres") else null
	if not _check(map_1 != null, "map_01.tres does not load as TDMapLayout."):
		return
	if not _check(map_1.map_id == 1, "map_01.tres carries the wrong id."):
		return
	var map_2 := load("res://data/maps/map_02.tres") as TDMapLayout
	if not _check(map_2 != null, "map_02.tres does not load as TDMapLayout."):
		return
	if not _check(map_2.map_id == 2, "map_02.tres carries the wrong id."):
		return
	for layout: TDMapLayout in [map_1, map_2]:
		if not _check(layout.path_points.size() >= 4, "Layout %d needs at least 4 road points." % layout.map_id):
			return
		if not _check(layout.tower_slots.size() == 12, "Layout %d must carry 12 tower slots (got %d)." % [layout.map_id, layout.tower_slots.size()]):
			return
		if not _check(layout.hill_positions.size() == layout.hill_scales.size(), "Layout %d hill dressing arrays disagree." % layout.map_id):
			return
		if not _check(layout.ground_size.x > 0.0 and layout.ground_size.y > 0.0, "Layout %d ground size invalid." % layout.map_id):
			return


## Director order: map 2 walk area and road length both grew by >= 50%.
func _test_map_geometry_growth() -> void:
	var map_1: TDMapLayout = load("res://data/maps/map_01.tres")
	var map_2: TDMapLayout = load("res://data/maps/map_02.tres")
	var area_1: float = map_1.ground_size.x * map_1.ground_size.y
	var area_2: float = map_2.ground_size.x * map_2.ground_size.y
	if not _check(area_2 >= area_1 * 1.5, "Map 2 ground area did not grow by 50%% (%f vs %f)." % [area_1, area_2]):
		return
	if not _check(map_2.path_length() >= map_1.path_length() * 1.5, "Map 2 road did not grow 50%% longer (%f vs %f)." % [map_1.path_length(), map_2.path_length()]):
		return


## Every slot stays clear of the road by placement-like bounds (~2.4+).
func _test_slot_road_clearance() -> void:
	var map_2: TDMapLayout = load("res://data/maps/map_02.tres")
	var points: PackedVector3Array = map_2.path_points
	for slot: Vector3 in map_2.tower_slots:
		var min_distance: float = INF
		for index: int in range(points.size() - 1):
			var start: Vector3 = points[index]
			var end: Vector3 = points[index + 1]
			var local: Vector3 = slot - start
			var span: Vector3 = end - start
			var t: float = clampf(local.dot(span) / span.length_squared(), 0.0, 1.0)
			min_distance = minf(min_distance, local.distance_to(span * t))
		if not _check(min_distance >= 2.4, "Map 2 slot %s sits only %.2f from the road." % [str(slot), min_distance]):
			return


## TDMapSession.selected_map=2 -> the run scene builds map 2's world.
func _test_session_handoff_into_run() -> void:
	TDMapSession.select_map(2)
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await physics_frame
	await physics_frame
	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return
	run._profile_repo.save_path = TEST_PROFILE_PATH
	if not _check(run.map_id == 2, "Run did not honor the session map handoff (map_id=%d)." % run.map_id):
		return
	var map_2: TDMapLayout = load("res://data/maps/map_02.tres")
	if not _check(run.PATH_POINTS == map_2.path_points, "Run road differs from map 2's layout resource."):
		return
	if not _check(run.SLOTS.size() == 12 and run._slot_disks.size() == 12, "Run did not materialize 12 map-2 slots (%d disks)." % run._slot_disks.size()):
		return
	if not _check(is_equal_approx(run.map_layout.ground_size.y, 58.0), "Run ground did not grow to map 2's plane."):
		return


## Victory on map 1 shows the next-map entry; map 2's own victory does not.
func _test_victory_next_map_flow() -> void:
	TDMapSession.select_map(1)
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await physics_frame
	var run := current_scene as TDRun
	if run == null:
		return
	run._profile_repo.save_path = TEST_PROFILE_PATH
	run._end_run(true)
	var hud := run._hud as TDHud
	if not _check(hud != null and hud._overlay_next_map != null and hud._overlay_next_map.visible, "Victory on map 1 did not surface the next-map button."):
		return
	if not _check(TDMapSession.selected_map == 1, "Victory alone must not move the session token (that is the button's job)."):
		return
	hud.next_map_pressed.emit()
	# The run was freed by the scene switch; the session token is the handoff.
	await process_frame
	await process_frame
	if not _check(TDMapSession.selected_map == 2, "Next-map action did not advance the session token to 2 (got %d)." % TDMapSession.selected_map):
		return
	# map 2's own victory: no advance button (nothing beyond the last shipped map)
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await physics_frame
	run = current_scene as TDRun
	if run == null:
		return
	run._profile_repo.save_path = TEST_PROFILE_PATH
	if not _check(run.map_id == 2, "Reloading after the advance must land on map 2 (got %d)." % run.map_id):
		return
	run._end_run(true)
	hud = run._hud as TDHud
	if not _check(hud != null and hud._overlay_next_map != null and not hud._overlay_next_map.visible, "Last map's victory must not offer a next-map button."):
		return
	TDSessionSnapshot.clear()
	TDMapSession.reset()
