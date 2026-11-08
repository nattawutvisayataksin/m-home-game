extends SceneTree

## Headless autoplay sim — a bot plays the real run scene through the real
## engine tick (Engine.time_scale-compressed wall clock, but every system —
## spawning, walking, shooting, leaking — runs its own physics): towers fire,
## enemies walk toward the Shelter, and RunMetrics records the run onto
## user://metrics/<run_id>.json for the wave pacing and economy iteration loop.
## Player files stay untouched: isolated snapshot + profile paths.
## Usage: godot --headless --path . --script res://tests/sim_autoplay.gd \
##        -- [run_count 1..10] [time_scale 1..32]

const RUN_SCENE: PackedScene = preload("res://scenes/gameplay/run.tscn")
const SIM_SNAPSHOT_PATH: String = "user://sim_autoplay_snapshot.json"
const SIM_PROFILE_PATH: String = "user://sim_autoplay_profile.json"
const DEFAULT_RUNS: int = 3
const DEFAULT_TIME_SCALE: float = 8.0
const MAX_PREP_PLACEMENTS: int = 1
## Bot reasoning knobs (mirror a mid-skill human, not a perfect player):
## - buys by priority, not by price: damage towers first, slows second
## - keeps a small mid-game stash so upgrades stay reachable
## - starts upgrading from wave 2 onward (a human strengthens before expanding)
const BUILD_PRIORITY: Array[int] = [
	TDTower.Kind.FIELD_TURRET,
	TDTower.Kind.TANGLE_EMITTER,
	TDTower.Kind.SONIC_RESONATOR,
	TDTower.Kind.ARC_CANNON,
]
const PREP_RESERVE: int = 40
const UPGRADE_FROM_WAVE: int = 4
## Realtime waits are never used; this frame guard only bounds a stall.
const MAX_FRAMES_PER_RUN: int = 200000


var _sim_runs: int = DEFAULT_RUNS
var _time_scale: float = DEFAULT_TIME_SCALE


func _initialize() -> void:
	_sim_runs = _int_arg(0, 1, 10, DEFAULT_RUNS)
	_time_scale = _float_arg(1, 1.0, 32.0, DEFAULT_TIME_SCALE)
	call_deferred("_run_all")


func _run_all() -> void:
	print("SIM AUTOPLAY: runs=%d time_scale=%.1f" % [_sim_runs, _time_scale])
	TDSessionSnapshot.save_path = SIM_SNAPSHOT_PATH
	for run_index: int in range(1, _sim_runs + 1):
		if not await _play_one_run(run_index):
			_finish(1)
			return
	print("SIM AUTOPLAY DONE")
	_finish(0)


## Plays one full run end-to-end (or until a guard trips) and prints a compact
## ASCII summary of what the run's metrics recorded.
func _play_one_run(run_index: int) -> bool:
	TDSessionSnapshot.clear()
	var scene_error: Error = change_scene_to_packed(RUN_SCENE)
	if not _check_ok(scene_error == OK, "Run %d: could not load the run scene." % run_index):
		return false
	await scene_changed
	await physics_frame
	var run := current_scene as TDRun
	if not _check_ok(run != null, "Run %d: run scene did not instantiate TDRun." % run_index):
		return false
	run._profile_repo.save_path = SIM_PROFILE_PATH
	Engine.time_scale = _time_scale
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 40

	var placements: int = 0
	var upgrades: int = 0
	var frame: int = 0
	while frame < MAX_FRAMES_PER_RUN:
		if run.is_over:
			break
		var actions: Array[int] = _bot_prep(run)
		placements += actions[0]
		upgrades += actions[1]
		if not run.is_combat:
			run.start_wave()
			if not _check_ok(run.is_combat and run.wave_number > 0,
					"Run %d: start_wave produced an odd state (wave %d, combat %s)." % [run_index, run.wave_number, str(run.is_combat)]):
				return false
		await physics_frame
		frame += 1
	if not _check_ok(frame < MAX_FRAMES_PER_RUN,
			"Run %d hit the frame guard while still live (stall?)." % run_index):
		return false

	var summary: String = _summarize(run, "RUN %d" % run_index, placements, upgrades)
	var result: Dictionary = run._metrics.result
	if not _check_ok(result.has("won"), "Run %d: the metrics result never recorded an outcome." % run_index):
		return false
	print(summary)
	return true


## The buyer (runs during prep and combat like a distracted human): priority
## build order (damage before slows), nearest-road slot, then one upgrade of
## the most advanced affordable tower. Returns [placements, upgrades] executed.
func _bot_prep(run: TDRun) -> Array[int]:
	var placements_made: int = 0
	for _attempt: int in range(MAX_PREP_PLACEMENTS):
		var kind: int = _priority_pick(run)
		if kind < 0:
			break
		var slot: int = _nearest_free_slot(run)
		if slot < 0:
			break
		if not run.place_tower(slot, kind):
			break
		placements_made += 1
	var upgrades_made: int = 0
	if maxi(run.wave_number, 1) >= UPGRADE_FROM_WAVE:
		var target: int = _upgrade_target(run, run.parts - PREP_RESERVE)
		if target >= 0 and run.upgrade_tower(target):
			upgrades_made += 1
	return [placements_made, upgrades_made]


func _summarize(run: TDRun, label: String, placements: int, upgrades: int) -> String:
	var result: Dictionary = run._metrics.result
	var won: bool = bool(result.get("won", false))
	var events: Array = run._metrics.events
	var kills: int = 0
	var leaks: int = 0
	var placed_events: int = 0
	var upgraded_events: int = 0
	var per_wave_leaks: Dictionary = {}
	var per_wave_activity: Dictionary = {}
	for event: Dictionary in events:
		var event_type: String = str(event.get("type", ""))
		match event_type:
			"enemy_killed":
				kills += 1
				_bump(per_wave_activity, int(event.get("wave", -1)))
			"enemy_leaked":
				leaks += 1
				_bump(per_wave_leaks, int(event.get("wave", -1)))
			"tower_placed":
				placed_events += 1
			"tower_upgraded":
				upgraded_events += 1
			"wave_cleared":
				_bump(per_wave_activity, int(event.get("wave", -1)))
	var game_time: float = float(result.get("duration_seconds", 0.0))
	var lines: Array[String] = [
		"%s: won=%s integrity=%d wave=%d parts_end=%d" % [label, str(won), run.integrity, run.wave_number, run.parts],
		"  game_time=%.1fs kills=%d leaks=%d" % [game_time, kills, leaks],
		"  bot_actions: placements=%d upgrades=%d (metrics: %d/%d)" % [placements, upgrades, placed_events, upgraded_events],
		"  leaks_per_wave=%s" % _dictionary_text(per_wave_leaks),
		"  activity_per_wave=%s" % _dictionary_text(per_wave_activity),
	]
	return "\n".join(lines)


func _dictionary_text(dictionary: Dictionary) -> String:
	if dictionary.is_empty():
		return "<none>"
	var keys: Array = dictionary.keys()
	keys.sort()
	var pieces: Array[String] = []
	for key: int in keys:
		pieces.append("%d:%d" % [key, int(dictionary[key])])
	return " ".join(pieces)


func _bump(dictionary: Dictionary, key: int) -> void:
	dictionary[key] = int(dictionary.get(key, 0)) + 1


func _check_ok(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("SIM FAILED: " + message)
	return false


# --- shared helpers (the same distance metric the placement eye uses) -----------

func _priority_pick(run: TDRun) -> int:
	var budget: int = run.parts - PREP_RESERVE
	for kind: int in BUILD_PRIORITY:
		var stats := run._tower_def(kind) as TDTowerDefinition
		if stats.cost <= budget:
			return kind
	return -1


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


## Most advanced upgradable tower whose next level the budget can cover.
func _upgrade_target(run: TDRun, budget: int) -> int:
	var best: int = -1
	var best_level: int = -1
	for slot_index: int in range(run._slot_towers.size()):
		var tower: TDTower = run._slot_towers[slot_index]
		if tower == null or not tower.can_upgrade():
			continue
		var stats := run._tower_def(tower.kind) as TDTowerDefinition
		if stats.upgrade_costs[tower.level] > budget:
			continue
		if tower.level > best_level:
			best = slot_index
			best_level = tower.level
	return best


# --- cli + lifecycle -------------------------------------------------------------

func _int_arg(index: int, minimum: int, maximum: int, fallback: int) -> int:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if index >= arguments.size():
		return fallback
	var candidate: int = arguments[index].to_int()
	if candidate < minimum or candidate > maximum:
		return fallback
	return candidate


func _float_arg(index: int, minimum: float, maximum: float, fallback: float) -> float:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if index >= arguments.size():
		return fallback
	var candidate: float = arguments[index].to_float()
	if candidate < minimum or candidate > maximum:
		return fallback
	return candidate


func _finish(exit_code: int) -> void:
	Engine.time_scale = 1.0
	TDSessionSnapshot.clear()
	var directory := DirAccess.open("user://")
	if directory != null:
		directory.remove("sim_autoplay_snapshot.json")
		directory.remove("sim_autoplay_profile.json")
	if current_scene != null:
		current_scene.free()
		current_scene = null
	await process_frame
	quit(exit_code)
