extends SceneTree

## Director-order visual check: renders the new rift portal, a splitter, a
## boss aura Warden and a death-burst frame in one in-engine capture.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await _settle_frames(10)
	var run := current_scene as TDRun

	var splitter_def: TDEnemyDefinition = run._enemy_def(&"splitter")
	run._instantiate_enemy(splitter_def, 0.3, splitter_def.bounty, Vector3(-7.5, 0.0, -1.5), splitter_def)
	var warden_def: TDEnemyDefinition = run._enemy_def(&"warden")
	run._instantiate_enemy(warden_def, 1.0, warden_def.bounty, Vector3(3.0, 0.0, -4.0), warden_def)
	run._instantiate_enemy(splitter_def, 0.3, splitter_def.bounty, Vector3(5.5, 0.0, -2.0), splitter_def)
	await _settle_frames(8)

	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/_enemy_fx_selfshot.png"))
	print("ENEMY FX SELF-SHOT SAVED")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
