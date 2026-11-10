extends SceneTree

## Layout probe (dev only): prints the global rects of the footer children of
## the title menu so vertical overflow at 720p can be measured, not guessed.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(TITLE_SCENE)
	await scene_changed
	for _index: int in range(10):
		await process_frame
	var title := current_scene as TDTitleMenu
	print("VIEWPORT=", root.size)
	var profile: Label = title._profile_label
	var effect: Label = title._barricade_line
	var button: Button = title._barricade_button
	if profile != null:
		print("PROFILE_ROW rect=", profile.get_global_rect())
	if effect != null:
		print("EFFECT_LINE rect=", effect.get_global_rect())
	if button != null:
		print("BUY_BUTTON rect=", button.get_global_rect())
	quit(0)
