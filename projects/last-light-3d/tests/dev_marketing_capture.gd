extends SceneTree

## Marketing captures: re-captures docs/marketing/ art from the REAL current
## build (in-engine capture only, no desktop pixels) so the store images match
## the shipped title menu (base panel) and the battle scene (hero, HUD).

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title.tscn")
const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")

## Marketing budget for the shot: enough to place three real towers and still
## show a believable Parts readout on the HUD (not a dev-warped number).
const SHOWCASE_PARTS: int = 500


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(TITLE_SCENE)
	await scene_changed
	await _settle_frames(12)
	var title_image: Image = root.get_texture().get_image()
	title_image.save_png(ProjectSettings.globalize_path("res://../../docs/marketing/menu_title.png"))
	print("MENU TITLE CAPTURED")

	change_scene_to_packed(RUN_SCENE)
	await scene_changed
	await _settle_frames(8)
	var run := current_scene as TDRun
	run.parts = SHOWCASE_PARTS
	# A believable defensive line: three everyday kinds in early slots.
	run.place_tower(0, TDTower.Kind.FIELD_TURRET)
	run.place_tower(1, TDTower.Kind.TANGLE_EMITTER)
	run.place_tower(2, TDTower.Kind.SONIC_RESONATOR)
	# Open the teaching wave and fight for real: by ~7.2s the leading
	# drifters are inside the turret/aura range, so lasers, slow rings and
	# hit sparks read on the frame the way the game actually looks.
	run.start_wave()
	await _settle_frames(430)

	# Dev framing: elevated front view centered on the tower cluster against
	# the spawn road (slots 0-2 at x -13.6..-8.4, drifter marching on x=-11).
	var camera: Camera3D = run._camera
	camera.look_at_from_position(Vector3(4.0, 10.5, 14.5), Vector3(-7.0, 0.0, -1.0), Vector3.UP)
	camera.fov = 48.0
	await _settle_frames(3)
	var battle_image: Image = root.get_texture().get_image()
	battle_image.save_png(ProjectSettings.globalize_path("res://../../docs/marketing/showcase_battle.png"))
	print("SHOWCASE BATTLE CAPTURED")
	quit(0)


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
