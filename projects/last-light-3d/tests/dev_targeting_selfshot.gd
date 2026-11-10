extends SceneTree

## Targeting-mode visual check: places a slot tower, cycles it off FIRST and
## captures ONLY the game's own viewport image (in-engine capture, no desktop
## pixels) so the localized mode chip above the turret and the HUD toast on
## the screen can be verified by eye.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")

const START_PARTS_HUGE: int = 999999


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await _settle_frames(10)
	var run := current_scene as TDRun
	run.parts = START_PARTS_HUGE
	if not run.place_tower(0, TDTower.Kind.FIELD_TURRET):
		push_error("TARGETING SELF-SHOT FAILED: placement refused")
		quit(1)
		return
	var tower: TDTower = run._slot_towers[0]
	# Walk the mode off FIRST so the chip shows, then speak through the run
	# seam exactly like a real T press would.
	tower.cycle_targeting()
	var slot: Vector3 = run.SLOTS[0]
	run._cycle_tower_targeting(run._camera.unproject_position(Vector3(slot.x, 0.0, slot.z)))
	await _settle_frames(2)

	# Dev framing: close front view, chip above the turret inside the frame.
	var camera: Camera3D = run._camera
	camera.look_at_from_position(tower.global_position + Vector3(2.4, 3.2, 3.6), tower.global_position + Vector3(0.0, 1.7, 0.0), Vector3.UP)
	camera.fov = 40.0
	await _settle_frames(3)

	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/_targeting_selfshot.png"))
	print("TARGETING SELF-SHOT SAVED")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
