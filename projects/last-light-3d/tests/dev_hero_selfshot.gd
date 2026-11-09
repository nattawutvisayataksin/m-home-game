extends SceneTree

## Hero prototype visual check: toggles the dev hero, walks it a few frames,
## lands one strike on a nearby enemy and saves ONLY the game's own viewport
## image (in-engine capture, no desktop pixels).

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await _settle_frames(10)
	var run := current_scene as TDRun

	run._toggle_hero()
	var hero := run._hero as TDHero
	hero.use_seam_input = true
	# a short walk so the gait reads, then stand and fight
	hero.move_input = Vector2(0.0, 1.0)
	await _settle_frames(14)
	hero.move_input = Vector2.ZERO
	var drifter: TDEnemyDefinition = run._enemy_def(&"drifter")
	# uproot the enemy far left-front: inside the frame but well OFF the
	# camera->hero sight line so the target never wall-hides the hero
	var enemy := run._instantiate_enemy(drifter, 0.3, drifter.bounty, hero.global_position + Vector3(-1.8, 0.0, 2.2), drifter)
	await _settle_frames(2)
	var before: float = (enemy as TDEnemy).health
	hero.strike_at((enemy as TDEnemy).global_position)
	await _settle_frames(2)
	print("STRIKE LANDED=", before != (enemy as TDEnemy).health)

	# dev framing: from the hero's front-right, nothing but open ground in between.
	var camera: Camera3D = run._camera
	camera.look_at_from_position(hero.global_position + Vector3(2.8, 2.4, 2.6), hero.global_position + Vector3(0.0, 0.6, 0.2), Vector3.UP)
	camera.fov = 42.0
	await _settle_frames(3)

	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/_hero_selfshot.png"))
	print("HERO SELF-SHOT SAVED")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
