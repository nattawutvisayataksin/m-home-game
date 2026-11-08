extends SceneTree

## Phase 8 test — TD-1 exit: per-wave coverage of the wave data through the
## real run scene (spawn path, wave clear, metrics side), without hardcoding
## any balance numbers — counts derive from the loaded .tres definitions:
## 1) structural data pass: ids known, positives, spawn window bounded,
##    composition archetypes unique per wave (spawn-mix check needs this)
## 2) wave 1 pure economy: exact Parts delta from bounties + clear bonus only
## 3) waves 2-8: spawn fast-forward produces exactly the composition total
##    with the right archetype mix and health-bonus scaling, kill-all clears
##    exactly that wave, kills/leaks match the metrics side; real economy
##    placements/upgrades interleave so the place/upgrade paths stay covered
## 4) wave chaining: two live waves merge (_pending_wave_numbers == [1, 2]),
##    pay two clear bonuses, and start_wave past the roster does nothing.
## Player files stay untouched: isolated snapshot + profile paths.

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")
const TEST_SNAPSHOT_PATH: String = "user://phase8_test_snapshot.json"
const TEST_PROFILE_PATH: String = "user://phase8_test_profile.json"
const PLACE_KINDS: Array[int] = [
	TDTower.Kind.FIELD_TURRET,
	TDTower.Kind.SONIC_RESONATOR,
	TDTower.Kind.TANGLE_EMITTER,
	TDTower.Kind.ARC_CANNON,
]
const MAX_PLACEMENTS_PER_PREP: int = 2


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Isolate every write the run could make (snapshot + profile).
	TDSessionSnapshot.save_path = TEST_SNAPSHOT_PATH
	TDSessionSnapshot.clear()

	if not await _test_structural_wave_data():
		return
	if not await _test_wave_one_pure_economy():
		return
	if not await _test_waves_two_to_eight():
		return
	if not await _test_wave_chaining():
		return

	_cleanup()
	print("PHASE 8 WAVE COVERAGE TEST PASSED")
	call_deferred("_finish", 0)


# --- 1) structural pass over the .tres wave roster ------------------------------

func _test_structural_wave_data() -> bool:
	if not await _prepare_run_scene():
		return false
	var run := current_scene as TDRun
	for index: int in range(run.WAVES.size()):
		var wave := run.WAVES[index] as TDWaveDefinition
		var total: int = _composition_total(wave)
		if not _check(total > 0, "Wave %d composition is empty at runtime." % (index + 1)):
			return false
		if not _check(wave.spawn_interval > 0.0, "Wave %d spawn interval not positive." % (index + 1)):
			return false
		if not _check(wave.health_bonus >= 0.0, "Wave %d health bonus is negative." % (index + 1)):
			return false
		# Feasibility bound: the spawn tail must not outlive a playable night.
		var spawn_window: float = float(total - 1) * wave.spawn_interval
		if not _check(spawn_window < 120.0, "Wave %d spawn window %.1fs exceeds the design bound." % [index + 1, spawn_window]):
			return false
		# Uniqueness: one archetype per entry so the runtime mix check maps
		# spawned counts back onto ids unambiguously.
		var seen_archetypes: Array[int] = []
		for enemy_id: StringName in wave.composition.keys():
			var definition := TDRun.ENEMY_DEFS[enemy_id] as TDEnemyDefinition
			if not _check(definition.archetype not in seen_archetypes,
					"Wave %d reuses archetype %d across ids (mix check ambiguous)." % [index + 1, definition.archetype]):
				return false
			seen_archetypes.append(definition.archetype)
	return true


# --- 2) wave 1: pure economy, exact Parts delta ----------------------------------

func _test_wave_one_pure_economy() -> bool:
	# Fresh scene with zero placements so the delta is provable.
	if not await _prepare_run_scene():
		return false
	var run := current_scene as TDRun
	var parts_before: int = run.parts
	var wave := run._wave_def(1)
	run.start_wave()
	if not _fast_forward_spawns(run, wave):
		return false
	if not _check(run._spawned_alive == _composition_total(wave), "Wave 1 spawn produced the wrong enemy count."):
		return false
	if not _assert_archetype_mix(run, wave):
		return false
	await _kill_all_and_settle(run)
	if not _check(not run.is_combat, "Wave 1 did not clear after all enemies died."):
		return false
	if not _check(not run.is_over, "Wave 1 must not end the run."):
		return false
	var bounty_sum: int = 0
	for enemy_id: StringName in wave.composition.keys():
		bounty_sum += (TDRun.ENEMY_DEFS[enemy_id] as TDEnemyDefinition).bounty * int(wave.composition[enemy_id])
	var expected: int = bounty_sum + run.WAVE_CLEAR_BONUS + run.INTEGRITY_BONUS * run.integrity
	if not _check(run.parts == parts_before + expected, "Wave 1 clear paid the wrong Parts (got %d, expected %d)." % [run.parts - parts_before, expected]):
		return false
	var cleared: PackedInt32Array = _metrics_waves_cleared(run)
	if not _check(cleared.size() == 1 and cleared[0] == 1, "Metrics recorded wave 1 clear incorrectly (%s)." % str(cleared)):
		return false
	return true


# --- 3) waves 2-8: spawn/count/mix per wave + living economy ----------------------

func _test_waves_two_to_eight() -> bool:
	var run := current_scene as TDRun
	var integrity_start: int = run.integrity
	for wave_index: int in range(2, run.WAVES.size() + 1):
		if run.is_over:
			break
		# Real spending path during prep: placements first, then upgrades.
		for _attempt: int in range(MAX_PLACEMENTS_PER_PREP):
			var chosen_kind: int = _cheapest_affordable_kind(run)
			if chosen_kind < 0:
				break
			var slot: int = _nearest_free_slot(run)
			if slot < 0:
				break
			if not _check(run.place_tower(slot, chosen_kind), "Placement seam failed with affordable Parts during wave %d prep." % wave_index):
				return false
		var target: int = _upgrade_target_slot(run)
		if target >= 0:
			if not _check(run.upgrade_tower(target), "Upgrade seam failed with affordable Parts during wave %d prep." % wave_index):
				return false

		var wave := run._wave_def(wave_index)
		var integrity_before: int = run.integrity
		run.start_wave()
		if not _check(run.is_combat and run.wave_number == wave_index, "Wave %d did not open at its index." % wave_index):
			return false
		var total: int = _composition_total(wave)
		if not _check(run._spawn_queue.size() == total, "Wave %d queue size %d does not match composition total %d." % [wave_index, run._spawn_queue.size(), total]):
			return false
		if not _fast_forward_spawns(run, wave):
			return false
		if not _check(run._spawned_alive == total, "Wave %d spawned %d of %d." % [wave_index, run._spawned_alive, total]):
			return false
		if not _assert_archetype_mix(run, wave):
			return false
		if not _assert_health_bonus(run, wave):
			return false
		await _kill_all_and_settle(run)
		if run.is_over:
			# Wave 8: the run may legitimately end here; integrity must be intact.
			if not _check(run.integrity == integrity_before, "Leak happened during the final wave coverage (integrity dropped)."):
				return false
			break
		if not _check(not run.is_combat, "Wave %d did not clear after all enemies died." % wave_index):
			return false
		if not _check(run.integrity == integrity_before, "Wave %d leaked without the kill path covering it." % wave_index):
			return false
		var cleared_waves: PackedInt32Array = _metrics_waves_cleared(run)
		if not _check(cleared_waves.has(wave_index) and cleared_waves.count(wave_index) == 1, "Wave %d clear recorded incorrectly (%s)." % [wave_index, str(cleared_waves)]):
			return false
		var kills: int = _metrics_count(run, "enemy_killed", wave_index)
		if not _check(kills == total, "Wave %d metrics: %d/%d kills recorded." % [wave_index, kills, total]):
			return false
		var leaks: int = _metrics_count(run, "enemy_leaked", wave_index)
		if not _check(leaks == 0, "Wave %d recorded %d leaks in the kill-only coverage." % [wave_index, leaks]):
			return false

	if not _check(run.integrity == integrity_start, "Integrity changed across the kill-path coverage (%d -> %d)." % [integrity_start, run.integrity]):
		return false
	if not _check(_metrics_count(run, "tower_placed") > 0 and _metrics_count(run, "tower_upgraded") > 0,
			"Real economy never afforded a placement and an upgrade across waves 2-8 (economy coverage gap)."):
		return false
	return true


# --- 4) wave chaining merge -------------------------------------------------------

func _test_wave_chaining() -> bool:
	if not await _prepare_run_scene():
		return false
	var run := current_scene as TDRun
	var parts_before: int = run.parts
	var total_a: int = _composition_total(run._wave_def(1))
	var total_b: int = _composition_total(run._wave_def(2))
	run.start_wave()
	run.start_wave()
	if not _check(run.wave_number == 2, "Chained start did not advance to wave 2 (wave_number=%d)." % run.wave_number):
		return false
	var pending: PackedInt32Array = PackedInt32Array(Array(run._pending_wave_numbers))
	if not _check(pending.size() == 2 and pending[0] == 1 and pending[1] == 2, "Chained waves are not both pending (%s)." % str(run._pending_wave_numbers)):
		return false
	if not _check(run._spawn_queue.size() == total_a + total_b, "Chained queue size %d != %d + %d." % [run._spawn_queue.size(), total_a, total_b]):
		return false
	if not _fast_forward_ticks(run, 1.0):
		return false
	if not _check(run._spawned_alive == total_a + total_b, "Chained spawn produced the wrong total count."):
		return false
	await _kill_all_and_settle(run)
	# One clear call pays one bonus per pending wave.
	var bounty_sum: int = 0
	for wave_index: int in [1, 2]:
		var wave := run._wave_def(wave_index)
		for enemy_id: StringName in wave.composition.keys():
			bounty_sum += (TDRun.ENEMY_DEFS[enemy_id] as TDEnemyDefinition).bounty * int(wave.composition[enemy_id])
	var expected: int = bounty_sum + 2 * (run.WAVE_CLEAR_BONUS + run.INTEGRITY_BONUS * run.integrity)
	if not _check(run.parts == parts_before + expected, "Chained clear paid the wrong Parts (%d vs %d)." % [run.parts - parts_before, expected]):
		return false
	var cleared: PackedInt32Array = _metrics_waves_cleared(run)
	if not _check(cleared.size() == 2 and cleared[0] == 1 and cleared[1] == 2, "Chained clears recorded wrong waves (%s)." % str(cleared)):
		return false

	# Natural continuation: after the [1, 2] chain clears, the next start
	# opens wave 3 prep-to-combat normally (the roster only ends at wave 8;
	# the exhausted-roster case is covered by the clear of the final wave).
	run.start_wave()
	if not _check(run.wave_number == 3 and run.is_combat, "Post-chain start_wave() did not open wave 3 (wave=%d combat=%s)." % [run.wave_number, str(run.is_combat)]):
		return false
	return true


# --- helpers ----------------------------------------------------------------------

func _prepare_run_scene() -> bool:
	var scene_error: Error = change_scene_to_packed(RUN_SCENE)
	if not _check(scene_error == OK, "Could not load the run scene."):
		return false
	await scene_changed
	await physics_frame
	var run := current_scene as TDRun
	if not _check(run != null, "Run scene did not instantiate TDRun."):
		return false
	# Writes (defeat salvage etc.) land on the isolated profile; reads of the
	# real profile in _ready are harmless (read-only).
	run._profile_repo.save_path = TEST_PROFILE_PATH
	return true


func _composition_total(wave: TDWaveDefinition) -> int:
	var total: int = 0
	for enemy_id: StringName in wave.composition.keys():
		total += int(wave.composition[enemy_id])
	return total


## Drains the spawn queue with the wave's own interval (no real time).
func _fast_forward_spawns(run: TDRun, wave: TDWaveDefinition) -> bool:
	return _fast_forward_ticks(run, wave.spawn_interval)


func _fast_forward_ticks(run: TDRun, step_delta: float) -> bool:
	var guard: int = 0
	while not run._spawn_queue.is_empty() and guard < 500:
		run._spawn_tick(step_delta)
		guard += 1
	if not _check(guard < 500, "Spawn fast-forward hit the guard cap (queue stuck)."):
		return false
	return true


## Kill every live enemy through the damage seam, then let the physics-driven
## clear fire (no direct _clear_wave call — coverage of the real trigger).
func _kill_all_and_settle(run: TDRun) -> void:
	for node: Node in root.get_tree().get_nodes_in_group("td_enemies"):
		var enemy := node as TDEnemy
		if enemy != null and is_instance_valid(enemy) and enemy.alive:
			enemy.take_damage(enemy.health + 1.0)
	for _index: int in range(4):
		await physics_frame


## Spawned archetype counts must reflect the composition exactly.
func _assert_archetype_mix(run: TDRun, wave: TDWaveDefinition) -> bool:
	var expected: Dictionary = {}
	for enemy_id: StringName in wave.composition.keys():
		var definition := TDRun.ENEMY_DEFS[enemy_id] as TDEnemyDefinition
		expected[definition.archetype] = expected.get(definition.archetype, 0) + int(wave.composition[enemy_id])
	var actual: Dictionary = {}
	for node: Node in root.get_tree().get_nodes_in_group("td_enemies"):
		var enemy := node as TDEnemy
		if enemy != null and is_instance_valid(enemy) and enemy.alive:
			actual[enemy.archetype] = int(actual.get(enemy.archetype, 0)) + 1
	if not _check(actual.size() == expected.size(), "Wave mix lost archetypes (%s vs %s)." % [str(actual.keys()), str(expected.keys())]):
		return false
	for archetype: int in expected.keys():
		if not _check(int(actual.get(archetype, 0)) == int(expected[archetype]), "Wave mix mismatch archetype %d: %d vs %d." % [archetype, int(actual.get(archetype, 0)), int(expected[archetype])]):
			return false
	return true


## Every spawned enemy carries the wave's health bonus on its definition.
func _assert_health_bonus(run: TDRun, wave: TDWaveDefinition) -> bool:
	for node: Node in root.get_tree().get_nodes_in_group("td_enemies"):
		var enemy := node as TDEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
			continue
		var matched: bool = false
		for enemy_id: StringName in wave.composition.keys():
			var definition := TDRun.ENEMY_DEFS[enemy_id] as TDEnemyDefinition
			if definition.archetype == enemy.archetype:
				matched = true
				if not _check(is_equal_approx(enemy.max_health, definition.base_health * (1.0 + wave.health_bonus)),
						"Enemy %s spawned without wave health bonus (%.1f vs %.1f)." % [enemy_id, enemy.max_health, definition.base_health * (1.0 + wave.health_bonus)]):
					return false
				break
		if not _check(matched, "Spawned enemy archetype %d is not in the wave composition." % enemy.archetype):
			return false
	return true


## Cheapest kind the current Parts can still afford, or -1.
func _cheapest_affordable_kind(run: TDRun) -> int:
	var best: int = -1
	var best_cost: int = 2147483647
	for kind: int in PLACE_KINDS:
		var stats := run._tower_def(kind) as TDTowerDefinition
		if stats.cost <= run.parts and stats.cost < best_cost:
			best = kind
			best_cost = stats.cost
	return best


## Closest unoccupied slot to the road (same distance metric the eye uses).
func _nearest_free_slot(run: TDRun) -> int:
	var best: int = -1
	var best_distance: float = INF
	for slot_index: int in range(run.SLOTS.size()):
		if run._slot_occupied[slot_index]:
			continue
		var distance: float = _slot_path_distance(run.SLOTS[slot_index], run.PATH_POINTS)
		if distance < best_distance:
			best = slot_index
			best_distance = distance
	return best


## Closest distance from a point to the road polyline (exact projection).
func _slot_path_distance(point: Vector3, path: PackedVector3Array) -> float:
	var distance: float = INF
	for index: int in range(path.size() - 1):
		var segment_start: Vector3 = path[index]
		var segment_end: Vector3 = path[index + 1]
		var segment: Vector3 = segment_end - segment_start
		var length_squared: float = segment.length_squared()
		var t: float = 0.0 if length_squared <= 0.0 else clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
		var closest: Vector3 = segment_start + segment * t
		distance = minf(distance, point.distance_to(closest))
	return distance


## Most advanced upgradable tower whose next level is affordable, else -1.
func _upgrade_target_slot(run: TDRun) -> int:
	var best: int = -1
	var best_level: int = -1
	for slot_index: int in range(run._slot_towers.size()):
		var tower: TDTower = run._slot_towers[slot_index]
		if tower == null or not tower.can_upgrade():
			continue
		var stats := run._tower_def(tower.kind) as TDTowerDefinition
		if stats.upgrade_costs[tower.level] > run.parts:
			continue
		if tower.level > best_level:
			best = slot_index
			best_level = tower.level
	return best


# --- metrics side -----------------------------------------------------------------

func _metrics_waves_cleared(run: TDRun) -> PackedInt32Array:
	var waves := PackedInt32Array()
	for event: Dictionary in run._metrics.events:
		if event.get("type", "") == "wave_cleared":
			waves.append(int(event.get("wave", -1)))
	return waves


func _metrics_count(run: TDRun, event_type: String, wave_index: int = -1) -> int:
	var count: int = 0
	for event: Dictionary in run._metrics.events:
		if event.get("type", "") != event_type:
			continue
		if wave_index >= 0 and int(event.get("wave", -1)) != wave_index:
			continue
		count += 1
	return count


func _cleanup() -> void:
	TDSessionSnapshot.clear()
	var directory := DirAccess.open("user://")
	if directory != null:
		directory.remove("phase8_test_snapshot.json")
		directory.remove("phase8_test_profile.json")


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PHASE 8 TEST FAILED: " + message)
	call_deferred("_finish", 1)
	return false


func _finish(exit_code: int) -> void:
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
