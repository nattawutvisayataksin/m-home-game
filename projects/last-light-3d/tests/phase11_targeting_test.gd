extends SceneTree

## Per-tower targeting mode test (GDD §5 post-vertical-slice): the default
## stays FIRST, cycling walks LAST -> STRONGEST -> WEAKEST -> FIRST, the mode
## chip builds lazily and hides on FIRST, each mode picks the right enemy from
## a mixed pair (advanced-weak vs trailing-strong), the tower under the mouse
## cursor is the cycle target through the real helper, the HUD toast fires and
## the run records a targeting_changed metrics line. No real-time waits.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")

const TEST_SNAPSHOT_PATH: String = "user://tests/phase11_snapshot.json"
const TEST_PROFILE_PATH: String = "user://tests/phase11_profile.json"

## Test-only open wallet for placing the feature tower; the real balance
## numbers stay in the .tres data untouched.
const START_PARTS_HUGE: int = 999999

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("TARGETING TEST FAILED: " + message)
		_failures += 1
	return condition


func _run_tests() -> void:
	TDSessionSnapshot.save_path = TEST_SNAPSHOT_PATH
	TDSessionSnapshot.clear()
	var passed: bool = await _test_all()
	_remove_test_files()
	if passed and _failures == 0:
		print("PHASE 11 TARGETING TEST PASSED")
		quit(0)
	else:
		quit(1)


func _test_all() -> bool:
	# --- Unit level: cycle order and the lazy mode chip -----------------------
	var tower := TDTower.new()
	root.add_child(tower)
	if not _check(tower.targeting_mode == TDTower.TargetingMode.FIRST, "Towers must default to FIRST targeting."):
		return false
	if not _check(tower._mode_label == null, "No mode chip may exist before the feature is used."):
		return false
	var chip: Label3D = tower._mode_label
	# set_mode_label_text builds the chip lazily and hides it while FIRST.
	tower.set_mode_label_text("FIRST")
	chip = tower._mode_label
	if not _check(chip != null, "set_mode_label_text did not create the mode chip."):
		return false
	if not _check(not chip.visible and chip.text == "FIRST", "FIRST chip must exist but stay hidden."):
		return false
	# Cycling order: LAST, STRONGEST, WEAKEST, back to FIRST.
	if not _check(tower.cycle_targeting() == TDTower.TargetingMode.LAST, "Cycle 1 must land on LAST."):
		return false
	if not _check(tower.cycle_targeting() == TDTower.TargetingMode.STRONGEST, "Cycle 2 must land on STRONGEST."):
		return false
	if not _check(tower.cycle_targeting() == TDTower.TargetingMode.WEAKEST, "Cycle 3 must land on WEAKEST."):
		return false
	if not _check(tower.cycle_targeting() == TDTower.TargetingMode.FIRST, "Cycle 4 must wrap back to FIRST."):
		return false
	# Non-FIRST: chip shows its text; back at FIRST: chip hides again.
	tower.cycle_targeting()
	tower.set_mode_label_text("LAST")
	if not _check(chip.visible and chip.text == "LAST", "Non-FIRST chip must show its localized text."):
		return false
	for _wrap: int in range(3):
		tower.cycle_targeting()
	if not _check(tower.targeting_mode == TDTower.TargetingMode.FIRST, "Three more cycles must wrap LAST back to FIRST."):
		return false
	tower.set_mode_label_text("FIRST")
	if not _check(not chip.visible, "Chip must hide again when the mode wraps to FIRST."):
		return false
	tower.queue_free()

	# --- Run level: mouse pick, toast, metrics --------------------------------
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await physics_frame
	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return false
	run._profile_repo.save_path = TEST_PROFILE_PATH

	# Placement is allowed to spend freely here; no balance numbers involved.
	run.parts = START_PARTS_HUGE
	if not _check(run.place_tower(0, TDTower.Kind.FIELD_TURRET), "Test tower refused placement in slot 0 despite open salvage."):
		return false
	var slot_tower: TDTower = run._slot_towers[0]
	if not _check(slot_tower != null and is_instance_valid(slot_tower), "Slot 0 did not hold the placed tower."):
		return false
	var slot: Vector3 = run.SLOTS[0]
	var mouse_position: Vector2 = run._camera.unproject_position(Vector3(slot.x, 0.0, slot.z))
	if not _check(run._tower_under_mouse(mouse_position) == slot_tower, "Mouse pick did not resolve the slot tower under the cursor."):
		return false

	run._cycle_tower_targeting(mouse_position)
	if not _check(slot_tower.targeting_mode == TDTower.TargetingMode.LAST, "Run-level cycle did not move the slot tower to LAST."):
		return false
	var toast: Label = run._hud._toast_label
	if not _check(toast != null and toast.visible and toast.text.length() > 0, "HUD targeting toast missing or empty after a cycle."):
		return false
	if not _check(_has_event(run._metrics.events, "targeting_changed"), "targeting_changed metrics event missing after a cycle."):
		return false
	# A second press on the same tower walks to STRONGEST.
	run._cycle_tower_targeting(mouse_position)
	if not _check(slot_tower.targeting_mode == TDTower.TargetingMode.STRONGEST, "Second cycle did not reach STRONGEST."):
		return false

	# --- Acquisition: each mode must pick the orthogonal enemy ----------------
	# Anchor enemy A: furthest along the path but fragile. Enemy B: trailing
	# but tanky. FIRST/WEAKEST prefer A, LAST/STRONGEST prefer B - two enemies
	# prove all four modes pick differently.
	var turret: TDTower = slot_tower
	turret.range_radius = 12.0
	var a := run._instantiate_enemy(run._enemy_def(&"drifter"), 0.0, 1, turret.global_position + Vector3(2.0, 0.0, 0.0), run._enemy_def(&"drifter")) as TDEnemy
	var b := run._instantiate_enemy(run._enemy_def(&"skitter"), 0.0, 1, turret.global_position + Vector3(-2.0, 0.0, 0.0), run._enemy_def(&"skitter")) as TDEnemy
	if not _check(a != null and b != null, "Test enemies did not instantiate."):
		return false
	# Same frame discipline: set the discriminating values and acquire at once
	# so no physics tick can move the enemies in between.
	a.progress = 20.0
	a.health = 5.0
	b.progress = 5.0
	b.health = 40.0
	turret.targeting_mode = TDTower.TargetingMode.FIRST
	if not _check(turret._acquire_target() == a, "FIRST must target the furthest-progress enemy."):
		return false
	turret.targeting_mode = TDTower.TargetingMode.LAST
	if not _check(turret._acquire_target() == b, "LAST must target the trailing enemy."):
		return false
	turret.targeting_mode = TDTower.TargetingMode.STRONGEST
	if not _check(turret._acquire_target() == b, "STRONGEST must target the highest-health enemy."):
		return false
	turret.targeting_mode = TDTower.TargetingMode.WEAKEST
	if not _check(turret._acquire_target() == a, "WEAKEST must target the lowest-health enemy."):
		return false
	a.queue_free()
	b.queue_free()

	# --- HUD seam: the toast helper is directly callable ---------------------
	run._hud.show_targeting_toast("toast")
	if not _check(run._hud._toast_label.visible, "show_targeting_toast did not show the toast label."):
		return false
	return true


func _has_event(events: Array, name: String) -> bool:
	for event: Variant in events:
		if typeof(event) == TYPE_DICTIONARY and String(event.get("type", "")) == name:
			return true
	return false


func _remove_test_files() -> void:
	for path: String in [TEST_SNAPSHOT_PATH, TEST_PROFILE_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
