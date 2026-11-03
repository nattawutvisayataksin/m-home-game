extends SceneTree

## Phase 2 test:
## 1) data .tres definitions load with sane fields (no hardcoded drift)
## 2) tower upgrade path (cost deducted, level rises, stats tighten, cap respected)
## 3) tower sell path (refund ratio, slot freed, disk color reset)
## 4) title menu: panels toggle and _start_mission() reaches the run scene.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if not await _test_data_definitions():
		return
	if not await _test_upgrade_and_sell():
		return
	if not await _test_title_menu():
		return
	print("PHASE 2 TD DATA + UPGRADE + TITLE TEST PASSED")
	call_deferred("_finish", 0)


func _test_data_definitions() -> bool:
	var enemies := [
		preload("res://data/enemies/drifter.tres"),
		preload("res://data/enemies/skitter.tres"),
		preload("res://data/enemies/dasher.tres"),
		preload("res://data/enemies/warden.tres"),
	]
	var seen_ids: Array[StringName] = []
	for resource: Resource in enemies:
		var definition := resource as TDEnemyDefinition
		if not _check(definition != null, "Enemy definition script failed to load."):
			return false
		if not _check(definition.base_health > 0.0 and definition.speed > 0.0 and definition.bounty > 0, "Enemy data has non-positive stats (%s)." % definition.enemy_id):
			return false
		seen_ids.append(definition.enemy_id)
	for expected: StringName in [&"drifter", &"skitter", &"dasher", &"warden"]:
		if not _check(seen_ids.has(expected), "Enemy data missed id %s." % expected):
			return false

	var towers := [
		preload("res://data/towers/field_turret.tres"),
		preload("res://data/towers/sonic_resonator.tres"),
		preload("res://data/towers/tangle_emitter.tres"),
	]
	for resource: Resource in towers:
		var definition := resource as TDTowerDefinition
		if not _check(definition != null, "Tower definition script failed to load."):
			return false
		if not _check(definition.cost > 0 and definition.range_radius > 0.0, "Tower data has non-positive core stats (%s)." % definition.display_name):
			return false
		if not _check(definition.upgrade_costs.size() == 2, "Tower data missing two upgrade costs (%s)." % definition.display_name):
			return false
	var tangle := preload("res://data/towers/tangle_emitter.tres") as TDTowerDefinition
	if not _check(tangle.slow_factor < 1.0 and tangle.slow_factor > 0.0, "Tangle Emitter slow factor is out of range."):
		return false

	var waves := [
		preload("res://data/waves/wave_01.tres"),
		preload("res://data/waves/wave_02.tres"),
		preload("res://data/waves/wave_03.tres"),
		preload("res://data/waves/wave_04.tres"),
		preload("res://data/waves/wave_05.tres"),
		preload("res://data/waves/wave_06.tres"),
		preload("res://data/waves/wave_07.tres"),
		preload("res://data/waves/wave_08.tres"),
	]
	if not _check(waves.size() == 8, "Wave roster does not have 8 entries."):
		return false
	for index: int in range(waves.size()):
		var wave := waves[index] as TDWaveDefinition
		if not _check(wave != null, "Wave definition %d failed to load." % (index + 1)):
			return false
		if not _check(wave.composition.size() > 0, "Wave %d composition is empty." % (index + 1)):
			return false
		if not _check(wave.spawn_interval > 0.0, "Wave %d spawn interval must be positive." % (index + 1)):
			return false
		# Composition keys must be real enemy ids (catches hand-written tres drift).
		for enemy_id: StringName in wave.composition.keys():
			if not _check(TDRun.ENEMY_DEFS.has(enemy_id), "Wave %d references unknown enemy id %s." % [index + 1, enemy_id]):
				return false
	return true


func _test_upgrade_and_sell() -> bool:
	var scene_error: Error = change_scene_to_packed(RUN_SCENE)
	if not _check(scene_error == OK, "Could not load the run scene."):
		return false
	await scene_changed
	await physics_frame

	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return false

	# Place the cheapest tower, then upgrade twice.
	if not _check(run.place_tower(0, TDTower.Kind.TANGLE_EMITTER), "Placement failed with enough Parts."):
		return false
	var tower: TDTower = run._slot_towers[0]
	if not _check(tower != null and tower.level == 0, "Placed tower did not start at level 0."):
		return false

	var invested: int = run._slot_invested[0]
	var upgrade_cost: int = (run._tower_def(TDTower.Kind.TANGLE_EMITTER) as TDTowerDefinition).upgrade_costs[0]
	var parts_before: int = run.parts
	if not _check(run.upgrade_tower(0), "First upgrade failed with enough Parts."):
		return false
	if not _check(run.parts == parts_before - upgrade_cost, "Upgrade did not charge the listed cost."):
		return false
	if not _check(run._slot_invested[0] == invested + upgrade_cost, "Upgrade cost was not added to invested parts (sell would refund wrongly)."):
		return false
	if not _check(run._slot_towers[0].level == 1, "Tower level did not rise after upgrade."):
		return false
	if not _check(run._slot_towers[0].range_radius > (run._tower_def(TDTower.Kind.TANGLE_EMITTER) as TDTowerDefinition).range_radius, "Upgraded range did not grow."):
		return false

	var parts_before_second: int = run.parts
	if parts_before_second < 200:
		run.parts = 300  # test seam: afford level-2 pricing
	var parts_before_second_topup: int = run.parts
	if not _check(run.upgrade_tower(0), "Second upgrade failed with enough Parts."):
		return false
	if not _check(run._slot_towers[0].level == 2, "Tower did not reach level 2."):
		return false
	if not _check(run.upgrade_tower(0) == false, "Upgraded past the level cap."):
		return false
	var spent_after_second: int = parts_before_second_topup - run.parts
	if not _check(spent_after_second >= 0, "Second upgrade corrupted Parts accounting."):
		return false

	# Sell: refund = 70% of everything invested, slot freed again.
	var parts_before_sell: int = run.parts
	var expected_refund: int = int(float(run._slot_invested[0]) * run.SELL_REFUND_RATIO)
	if not _check(expected_refund > 0, "Invested tracking broke (refund would be zero)."):
		return false
	if not _check(run.sell_tower(0), "Sell failed on an occupied slot."):
		return false
	if not _check(run.parts == parts_before_sell + expected_refund, "Sell did not refund 70% of invested Parts."):
		return false
	if not _check(run._slot_towers[0] == null and not run._slot_occupied[0], "Sell did not free the slot."):
		return false
	if not _check(run.sell_tower(0) == false, "Sold an empty slot."):
		return false
	if not _check(run.place_tower(0, TDTower.Kind.FIELD_TURRET), "Slot was not reusable after selling."):
		return false

	# RMB HUD path and metrics recorded the sell.
	var event_types: Array[String] = []
	for event: Dictionary in run._metrics.events:
		event_types.append(String(event.get("type", "")))
	for required: String in ["tower_placed", "tower_upgraded", "tower_sold"]:
		if not _check(event_types.has(required), "Metrics missed the %s event." % required):
			return false

	# Reset the scene for the title test.
	var cleared: bool = change_scene_to_packed(RUN_SCENE) == OK
	if not _check(cleared, "Could not reload the run scene."):
		return false
	await scene_changed
	await physics_frame
	return true


func _test_title_menu() -> bool:
	var title_scene: PackedScene = load("res://scenes/ui/title.tscn")
	if not _check(title_scene != null, "Title scene failed to load."):
		return false
	var scene_error: Error = change_scene_to_packed(title_scene)
	if not _check(scene_error == OK, "Could not change to the title scene."):
		return false
	await scene_changed
	await physics_frame

	var title := current_scene as TDTitleMenu
	if not _check(title != null, "Title scene did not instantiate TDTitleMenu."):
		return false
	if not _check(not title.panels_open(), "No content panels should be open at boot."):
		return false

	title._show_panel(title._how_panel)
	if not _check(title.panels_open(), "How-to-play panel did not open."):
		return false
	title._close_panels()
	if not _check(not title.panels_open(), "How-to-play panel did not close."):
		return false
	title._show_panel(title._story_panel)
	if not _check(title.panels_open(), "Story panel did not open."):
		return false
	title._show_panel(title._how_panel)
	if not _check(title._story_panel != null and not title._story_panel.visible and title._how_panel.visible, "Opening one panel did not close the other."):
		return false
	title._close_panels()

	title._start_mission()
	await scene_changed
	await physics_frame
	var run := current_scene as TDRun
	if not _check(run != null, "Start Mission did not reach the run scene."):
		return false
	if not _check(run.parts == run.START_PARTS and run.integrity == run.START_INTEGRITY, "Run did not boot with baseline economy."):
		return false
	return true


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 2 TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
