extends SceneTree

## Renders the world run scene in a real window and saves ONLY the game's own
## viewport image (in-engine capture, no desktop pixels) for visual review.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	# Let the world builder, lights and glb models all draw at least once.
	await _settle_frames(18)

	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/_world_selfshot.png"))

	print("WORLD SELF-SHOT SAVED")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
