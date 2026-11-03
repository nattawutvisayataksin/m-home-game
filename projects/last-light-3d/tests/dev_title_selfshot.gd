extends SceneTree

## Renders the title screen in a real window and saves ONLY the game's own
## viewport image (in-engine capture, no desktop pixels) for visual review.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(TITLE_SCENE)
	await scene_changed
	await _settle_frames(12)

	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/_title_selfshot.png"))

	# Also capture the how-to-play panel open state.
	var title := current_scene as TDTitleMenu
	title._show_panel(title._how_panel)
	await _settle_frames(6)
	var panel_image: Image = root.get_texture().get_image()
	panel_image.save_png(ProjectSettings.globalize_path("res://tests/_title_howto_selfshot.png"))

	print("TITLE SELF-SHOTS SAVED")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
