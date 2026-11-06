extends SceneTree

## Renders the battlefield in a real window and saves ONLY the game's own
## viewport image (in-engine capture, no desktop pixels) for visual review.
## Used to inspect road bends and the scattered environment dressing.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await _settle_frames(16)

	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/_road_environment_selfshot.png"))

	# Mid-combat frame: makes sure the dressing never fights the HUD/enemies.
	var run := current_scene as TDRun
	if run != null:
		run.start_wave()
	await _settle_frames(70)
	var combat_image: Image = root.get_texture().get_image()
	combat_image.save_png(ProjectSettings.globalize_path("res://tests/_run_environment_selfshot.png"))

	print("RUN SELF-SHOTS SAVED")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
